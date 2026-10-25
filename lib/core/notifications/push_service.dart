import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../analytics/analytics_service.dart';

/// Handles messages that arrive while the app is terminated or backgrounded.
///
/// Runs in its own isolate, so it can touch nothing from the running app. It
/// must be a top-level function and it must keep the entry-point pragma or
/// release builds tree-shake it away and background delivery silently stops.
@pragma('vm:entry-point')
Future<void> ustaadBackgroundMessageHandler(RemoteMessage message) async {
  // Notification payloads are drawn by the system without our help. This exists
  // so data-only messages have somewhere to land later.
  debugPrint('[Push] background message: ${message.messageId}');
}

/// Push notifications.
///
/// What this gives you today: broadcast sends from the Firebase console to
/// every install, or to one exam's students via a topic. That is enough to
/// announce "MDCAT content is live" or "new NET papers added".
///
/// What it does NOT give you: the per-student reminders in the growth plan
/// (streak about to break, weak-topic drill ready, days to exam). Those fire on
/// a schedule per user, which needs either Cloud Functions or an on-device
/// scheduler. See the note in [scheduleReminderPlaceholder].
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenSub;

  /// Emits when a notification is tapped and opens the app, so the UI can route
  /// somewhere useful instead of dumping the student on the home screen.
  final StreamController<RemoteMessage> onOpened =
      StreamController<RemoteMessage>.broadcast();

  /// Emits messages that arrive while the app is in the foreground. Android
  /// does not draw these itself, so nothing appears in the tray — a listener
  /// has to show something in-app.
  final StreamController<RemoteMessage> onForeground =
      StreamController<RemoteMessage>.broadcast();

  bool _wired = false;

  /// Wires listeners. Safe to call before sign in; the token is only persisted
  /// once there is a user to attach it to.
  Future<void> init() async {
    if (_wired) return;
    _wired = true;

    FirebaseMessaging.onBackgroundMessage(ustaadBackgroundMessageHandler);

    FirebaseMessaging.onMessage.listen(onForeground.add);
    FirebaseMessaging.onMessageOpenedApp.listen(onOpened.add);

    // A notification tap can cold-start the app, in which case the message is
    // not delivered through onMessageOpenedApp at all.
    final initial = await _fm.getInitialMessage();
    if (initial != null) onOpened.add(initial);

    // Tokens rotate on reinstall, restore and clear-data. Without this the
    // stored token goes stale and sends quietly stop landing.
    _tokenSub = _fm.onTokenRefresh.listen(_persistToken);
  }

  /// Asks for the notification permission.
  ///
  /// Deliberately not called at launch. On Android 13+ this is a one-shot
  /// system dialog: ask on first run, before the student knows what Ustaad is,
  /// and most of them decline permanently. Call it after a first completed
  /// quiz, when a streak reminder is obviously worth something.
  Future<bool> requestPermission() async {
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    await Analytics.instance.pushPermissionAnswered(granted: granted);

    if (granted) await syncToken();
    return granted;
  }

  /// Reads the current token and writes it to the signed-in user's document.
  Future<void> syncToken() async {
    try {
      final token = await _fm.getToken();
      if (token != null) {
        // Printed in debug only, so a test send can be addressed to this exact
        // device from the Firebase console without digging through Firestore.
        if (kDebugMode) {
          debugPrint('──────── FCM TOKEN ────────');
          debugPrint(token);
          debugPrint('───────────────────────────');
        }
        await _persistToken(token);
      }
    } catch (e) {
      debugPrint('[Push] getToken failed: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmPlatform': defaultTargetPlatform.name,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Push] token persist failed: $e');
    }
  }

  /// Topics are how a broadcast reaches only the students it applies to. An
  /// MDCAT announcement sent to every install is how people uninstall.
  Future<void> syncTopics(List<String> selectedExams) async {
    try {
      await _fm.subscribeToTopic('all');
      for (final exam in selectedExams) {
        await _fm.subscribeToTopic(_topicFor(exam));
      }
    } catch (e) {
      debugPrint('[Push] topic subscribe failed: $e');
    }
  }

  Future<void> clearTopics(List<String> selectedExams) async {
    try {
      await _fm.unsubscribeFromTopic('all');
      for (final exam in selectedExams) {
        await _fm.unsubscribeFromTopic(_topicFor(exam));
      }
    } catch (e) {
      debugPrint('[Push] topic unsubscribe failed: $e');
    }
  }

  /// Topic names allow `[a-zA-Z0-9-_.~%]` only, so anything else is stripped.
  String _topicFor(String exam) =>
      'exam_${exam.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}';

  /// Called on sign out and on account deletion so the next person on this
  /// device does not inherit the previous user's sends.
  Future<void> onSignOut(List<String> selectedExams) async {
    await clearTopics(selectedExams);
    try {
      await _fm.deleteToken();
    } catch (e) {
      debugPrint('[Push] deleteToken failed: $e');
    }
  }

  /// Not implemented, and deliberately so.
  ///
  /// The retention triggers that actually move day-7 numbers — "your streak
  /// ends in 3 hours", "your weak topic drill is ready", "NET is in 12 days" —
  /// are per-user and time-based. FCM only delivers; something has to decide
  /// when to send. Two ways to close that:
  ///
  ///   1. Cloud Functions on a schedule, reading each user's streak and exam
  ///      date and sending through the Admin SDK. Works when the app is not
  ///      running, costs a Blaze plan.
  ///   2. `flutter_local_notifications` scheduling on-device. Free, no backend,
  ///      no server round trip — but only fires while the app is installed and
  ///      the OS has not killed the alarm, and cannot react to server state.
  ///
  /// For streaks, option 2 is enough and much cheaper. Do not fake it here.
  void scheduleReminderPlaceholder() {}

  void dispose() {
    _tokenSub?.cancel();
    onOpened.close();
    onForeground.close();
  }
}
