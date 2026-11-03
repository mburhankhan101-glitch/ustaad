// lib/core/notifications/reminder_service.dart
//
// The streak reminder, scheduled on the device.
//
// This replaces PushService.scheduleReminderPlaceholder(), which was an empty
// method with a note describing the two ways to build it. The note's second
// option is the one taken here: flutter_local_notifications on a schedule,
// rather than Cloud Functions. Three reasons, in order:
//
//   1. Scheduled Cloud Functions need the Blaze plan. This project is on
//      Spark, so the server route is not free.
//   2. The device knows the student's local time. A server has to guess, or
//      store a timezone and keep it in sync.
//   3. It works with no network, which matters a great deal here.
//
// FCM keeps its job: broadcasts to everyone, or to one exam's topic. This
// handles the per-student, state-dependent reminder a topic cannot express.
//
// ── How "only if they have not practised" works without a background job ────
//
// A scheduled local notification cannot run code at fire time to check
// whether the student has practised since. So the check is inverted: the
// reminder for tonight is always armed, and practising cancels it. Every call
// to [refresh] re-decides what should be pending. Practise at 4pm and the 8pm
// reminder is cancelled before it can fire; do not, and it fires because
// nothing cancelled it.
//
// ── The one-a-day cap is structural, not a rule to remember ─────────────────
//
// There is exactly one notification id for this reminder. Scheduling always
// replaces whatever was pending rather than adding to it, so the app cannot
// queue two even if [refresh] is called twenty times in an afternoon.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../analytics/analytics_service.dart';
import 'reminder_plan.dart';

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'ustaad_reminders';
  static const _channelName = 'Practice reminders';
  static const _channelDescription =
      'Nudges you to practise, and counts down to your test. One a day at most.';

  Future<void> init() async {
    if (_ready) return;

    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (e) {
      // Falls back to the default location, which shifts the reminder by the
      // offset rather than losing it. Worth logging, never worth failing
      // startup over.
      debugPrint('[Reminder] timezone lookup failed, using default: $e');
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          Analytics.instance.reminderOpened(
            kind: response.payload ?? 'unknown',
          );
        },
      );

      // The handler above only fires when the app was already running. A
      // reminder lands at 8pm, when Ustaad is almost certainly killed, and
      // that tap cold-starts the app and is reported here instead. Without
      // this branch the tap is never counted, which is why reminder_opened
      // read zero for four days while reminders were demonstrably being
      // armed — the one number that says whether any of this works was
      // measuring only the rarest case.
      try {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          Analytics.instance.reminderOpened(
            kind: launch?.notificationResponse?.payload ?? 'unknown',
          );
        }
      } catch (e) {
        debugPrint('[Reminder] launch details unavailable: $e');
      }

      // Android 8+ drops a notification whose channel does not exist, with no
      // error anywhere. Create it before anything is scheduled.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.defaultImportance,
        ),
      );

      _ready = true;
    } catch (e) {
      debugPrint('[Reminder] init failed: $e');
    }
  }

  /// The single entry point. Call it after sign-in, when the app resumes, and
  /// whenever a quiz finishes — anywhere the streak or today's activity may
  /// have changed. It is cheap and idempotent.
  ///
  /// [lastActiveDate] is the `yyyy-MM-dd` string the progress document
  /// already stores.
  /// [examId] and [examDaysLeft] come from the countdown card's own data and
  /// are null when the student has set no date. When a paper is close, it
  /// takes over the copy.
  Future<void> refresh({
    required int streak,
    required String lastActiveDate,
    String? examId,
    int? examDaysLeft,
    DateTime? now,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;

    final at = now ?? DateTime.now();
    final plan = ReminderPlan.build(
      streak: streak,
      lastActiveDate: lastActiveDate,
      now: at,
      examId: examId,
      examDaysLeft: examDaysLeft,
    );

    // Always clear the whole ladder first. This is what makes practising at
    // 4pm cancel tonight's reminder, and what keeps one-a-day structural: a
    // rebuilt plan replaces every pending evening rather than adding to it.
    await _cancelLadder();

    for (final item in plan) {
      try {
        await _plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          // Read back when the tap launches the app, which is the only way to
          // tell which kind of reminder actually earns an open.
          payload: item.kind.name,
          scheduledDate: tz.TZDateTime.from(item.at, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // Inexact on purpose. Exact alarms need SCHEDULE_EXACT_ALARM on
          // Android 14+, which Play scrutinises and which a study reminder
          // cannot justify. A few minutes either side of 8pm is fine.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('[Reminder] schedule ${item.id} failed: $e');
      }
    }

    if (plan.isNotEmpty) {
      // One event per rebuild, not one per evening armed, so the count stays
      // readable. It still counts arming rather than delivery — a plan is
      // replaced far more often than it fires — so this is not a denominator
      // for the open rate.
      Analytics.instance.reminderScheduled(
        kind: plan.first.kind.name,
        streak: streak,
      );
    }
  }

  /// Clears every evening in the ladder, plus the single id used before the
  /// ladder existed so an upgrading device does not keep a stale reminder
  /// pending alongside the new ones.
  Future<void> _cancelLadder() async {
    for (var i = 0; i < ReminderPlan.horizonDays; i++) {
      try {
        await _plugin.cancel(id: ReminderPlan.firstId + i);
      } catch (e) {
        debugPrint('[Reminder] cancel ${ReminderPlan.firstId + i} failed: $e');
      }
    }
    try {
      await _plugin.cancel(id: ReminderPlan.legacyId);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _cancelLadder();
    } catch (e) {
      debugPrint('[Reminder] cancelAll failed: $e');
    }
  }

}
