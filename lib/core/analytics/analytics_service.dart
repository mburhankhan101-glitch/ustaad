import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Every analytics event name and log call lives here.
///
/// Scattering `logEvent('quiz_start')` through the screens is how a project
/// ends up with `quiz_start`, `quizStart` and `quiz_started` all counting the
/// same thing and none of them counting it correctly. Screens call a method;
/// the string literal exists once.
///
/// Names avoid the reserved set (`app_open`, `first_open`, `session_start`,
/// `user_engagement`, `in_app_purchase`, `ad_*`) so nothing collides with what
/// Firebase logs on its own.
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  /// Late, so constructing Analytics never touches Firebase. Read eagerly, it
  /// threw for any screen that logs from initState when Firebase is not
  /// initialised, which is every widget test; read here, the failure lands
  /// inside _log's try and is only printed.
  late final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  /// Attach to GoRouter so every route change logs a screen_view. One instance,
  /// not one per read — a fresh observer per navigation would leak listeners.
  late final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _fa);

  /// Set at build time to log events from a debug run:
  ///
  ///   flutter run --dart-define=USTAAD_ANALYTICS_IN_DEBUG=true
  ///
  /// Off by default so `flutter run` sessions do not sit in the same reports
  /// as real students and inflate every number you are trying to read. On when
  /// you need to confirm the wiring actually fires.
  static const _forceInDebug =
      bool.fromEnvironment('USTAAD_ANALYTICS_IN_DEBUG');

  /// Note that `first_open`, `session_start` and `screen_view` are logged by
  /// the SDK during `Firebase.initializeApp`, before this runs — so those three
  /// appear even when collection is subsequently disabled. Seeing only those
  /// three in the console means collection is off, not that logging is broken.
  Future<void> init() async {
    await _fa.setAnalyticsCollectionEnabled(!kDebugMode || _forceInDebug);
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa.logEvent(name: name, parameters: params);
    } catch (e) {
      // Analytics must never take the app down with it.
      debugPrint('[Analytics] $name failed: $e');
    }
  }

  // ── Identity ──────────────────────────────────────────────────────────────

  /// Ties events to a user so funnels can be followed across sessions. Cleared
  /// on sign out, and on account deletion, so the next signed-out session is
  /// not attributed to the person who just left.
  Future<void> setUser(String? uid) async {
    try {
      await _fa.setUserId(id: uid);
    } catch (e) {
      debugPrint('[Analytics] setUserId failed: $e');
    }
  }

  /// Lets every report be split by exam, which is the only segmentation that
  /// matters here: NET students and NTS students behave nothing alike.
  Future<void> setSelectedExams(List<String> exams) async {
    try {
      await _fa.setUserProperty(
        name: 'selected_exams',
        // User property values are capped at 36 characters.
        value: exams.join(',').substring(0, exams.join(',').length.clamp(0, 36)),
      );
    } catch (e) {
      debugPrint('[Analytics] setUserProperty failed: $e');
    }
  }

  // ── Activation funnel ─────────────────────────────────────────────────────
  // This is the sequence the plan cares about. Install to first question is the
  // number the email-verification gate is currently destroying, and none of it
  // is visible until these fire.

  Future<void> onboardingFinished() => _log('onboarding_finished');

  /// A guest session began. Against [quizStarted] this finally makes the
  /// install-to-first-question rate readable, and against [guestUpgraded] it
  /// shows how many guests ever convert to a real account.
  Future<void> guestStarted() => _log('guest_started');

  /// A guest attached an email or Google account, keeping their uid and all
  /// the progress they built up.
  Future<void> guestUpgraded({required String method}) =>
      _log('guest_upgraded', {'method': method});

  /// The Anonymous provider is off in the Firebase console, so the guest path
  /// is unavailable and the app fell back to the login screen. If this ever
  /// fires in production it means the funnel fix is silently not running.
  Future<void> guestUnavailable({required String reason}) =>
      _log('guest_unavailable', {'reason': reason});

  Future<void> signupStarted({required String method}) =>
      _log('signup_started', {'method': method});

  Future<void> signupSubmitted({required String method}) =>
      _log('signup_submitted', {'method': method});

  Future<void> verificationEmailSent() => _log('verification_email_sent');

  Future<void> emailVerified() => _log('email_verified');

  Future<void> loginSucceeded({required String method}) =>
      _log('login_succeeded', {'method': method});

  Future<void> examsSelected(List<String> exams) =>
      _log('exams_selected', {'exams': exams.join(',')});

  // ── Core usage ────────────────────────────────────────────────────────────

  Future<void> quizStarted({required String exam, required String section}) =>
      _log('quiz_started', {'exam': exam, 'section': section});

  Future<void> quizFinished({
    required String exam,
    required String section,
    required int correct,
    required int total,
  }) =>
      _log('quiz_finished', {
        'exam': exam,
        'section': section,
        'correct': correct,
        'total': total,
      });

  /// The single most important engagement signal in the app: it is the feature
  /// students stay for, and it costs nothing to serve.
  Future<void> explanationOpened({
    required String exam,
    required String language,
  }) =>
      _log('explanation_opened', {'exam': exam, 'language': language});

  Future<void> paperStarted({required String exam, required String paperId}) =>
      _log('paper_started', {'exam': exam, 'paper_id': paperId});

  Future<void> paperFinished({
    required String exam,
    required String paperId,
    required double score,
  }) =>
      _log('paper_finished', {
        'exam': exam,
        'paper_id': paperId,
        'score': score,
      });

  // ── Money and exits ───────────────────────────────────────────────────────

  Future<void> paywallViewed({required String source}) =>
      _log('paywall_viewed', {'source': source});

  Future<void> accountDeleted() => _log('account_deleted');

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> pushPermissionAnswered({required bool granted}) =>
      _log('push_permission', {'granted': granted ? 'yes' : 'no'});
}
