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

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// One id, so a second schedule overwrites the first instead of stacking.
  static const _streakId = 1001;

  static const _channelId = 'ustaad_reminders';
  static const _channelName = 'Practice reminders';
  static const _channelDescription =
      'Reminds you before your streak breaks. One a day at most.';

  /// Evening, not morning. Students here practise after Maghrib and after
  /// dinner; a 9am reminder lands in a school corridor and gets swiped.
  static const _hour = 20;
  static const _minute = 0;

  /// Below this there is no streak worth protecting, and "your streak is
  /// about to break" reads as nonsense to someone on day one.
  static const _minStreakToWarn = 2;

  // Rotated so a student who misses four evenings running is not told the
  // same sentence four times. Same voice as the home screen: Ustu, Roman
  // Urdu, more friend than invigilator.
  static const _lines = <List<String>>[
    [
      'Streak tootne wali hai! 🔥',
      'Ustu keh raha hai: 5 minute nikalo, {n} din ka kaam bach jayega.',
    ],
    [
      '{n} din ki mehnat 😬',
      'Aaj kuch nahi kiya. Ek chhota quiz, aur streak safe.',
    ],
    [
      'Ustu intezaar kar raha hai 🦉',
      '{n} din se streak chal rahi hai. Aaj bhi chalni chahiye na?',
    ],
    [
      'Abhi waqt hai ⏰',
      'Soney se pehle 5 sawal. {n} din ki streak bachane ke liye bas itna.',
    ],
    [
      'Yaad dilane aaya hoon 📚',
      'Tumhari {n} din ki streak aaj khatam ho jayegi. Mujhe rokna hai?',
    ],
  ];

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
        onDidReceiveNotificationResponse: (_) {
          Analytics.instance.reminderOpened(kind: 'streak');
        },
      );

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
  Future<void> refresh({
    required int streak,
    required String lastActiveDate,
    DateTime? now,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;

    final at = now ?? DateTime.now();
    final target = nextFireTime(
      streak: streak,
      lastActiveDate: lastActiveDate,
      now: at,
    );

    // Always clear first: this is what makes practising at 4pm cancel the 8pm
    // reminder, and what keeps the one-a-day cap structural.
    try {
      await _plugin.cancel(id: _streakId);
    } catch (e) {
      debugPrint('[Reminder] cancel failed: $e');
    }

    if (target == null) return;

    final line = lineFor(streak: streak, day: target.day);

    try {
      await _plugin.zonedSchedule(
        id: _streakId,
        title: line[0],
        body: line[1],
        scheduledDate: tz.TZDateTime.from(target, tz.local),
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
      Analytics.instance.reminderScheduled(kind: 'streak', streak: streak);
    } catch (e) {
      debugPrint('[Reminder] schedule failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancel(id: _streakId);
    } catch (e) {
      debugPrint('[Reminder] cancelAll failed: $e');
    }
  }

  // ── Pure logic, kept separate so it can be tested without a device ────────

  /// When the next streak reminder should fire, or null for "do not nag".
  ///
  /// Null in three cases: the streak is too small to be worth protecting,
  /// the streak is already broken so the notification would be a lie, or
  /// there is simply nothing to say tonight.
  @visibleForTesting
  static DateTime? nextFireTime({
    required int streak,
    required String lastActiveDate,
    required DateTime now,
  }) {
    if (streak < _minStreakToWarn) return null;

    final today = _dateString(now);
    final yesterday = _dateString(now.subtract(const Duration(days: 1)));

    // Already broken: the last practice was before yesterday, so there is no
    // streak left to save and claiming otherwise would be a lie.
    if (lastActiveDate != today && lastActiveDate != yesterday) return null;

    final slotToday = DateTime(now.year, now.month, now.day, _hour, _minute);

    // Practised today: tonight needs no reminder, so aim at tomorrow.
    if (lastActiveDate == today) {
      return slotToday.add(const Duration(days: 1));
    }

    // Not practised today, and the evening slot is still ahead: tonight.
    if (now.isBefore(slotToday)) return slotToday;

    // Past 8pm with nothing done. Firing now would mean a notification at
    // 11pm; the streak survives until midnight anyway, so leave tonight alone
    // and arm tomorrow.
    return slotToday.add(const Duration(days: 1));
  }

  /// Picks a line, rotating by day so consecutive misses read differently.
  /// Returns `[title, body]`.
  @visibleForTesting
  static List<String> lineFor({required int streak, required int day}) {
    final line = _lines[day % _lines.length];
    return [
      line[0].replaceAll('{n}', '$streak'),
      line[1].replaceAll('{n}', '$streak'),
    ];
  }

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
