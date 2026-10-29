import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← for orientation lock
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/core/analytics/analytics_service.dart';
import 'package:ustaad/core/notifications/push_service.dart';
import 'package:ustaad/core/notifications/reminder_service.dart';
import 'package:ustaad/core/router/app_router.dart';
import 'package:ustaad/core/theme/app_theme.dart';
import 'package:ustaad/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the entire app to portrait mode on mobile devices.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Must be set before any Firestore call. Offline persistence is on by default
  // on mobile but off on web, and the question pool now reads from this cache
  // first — without it every web session re-downloads whole sections from the
  // server and is billed for them.
  //
  // The bank is a few thousand small documents, so the default 100MB cap bites
  // long before disk does. Unlimited keeps sections resident between sessions
  // instead of evicting them and forcing a re-fetch.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ── Crashlytics ────────────────────────────────────────────────────────────
  // Debug crashes are ours, not students'. Reporting them buries the real ones.
  //
  // Overridable for the same reason Analytics is: with a plain `!kDebugMode`
  // the SDK logs "automatic data collection DISABLED by API" and silently drops
  // everything, so a test crash fires locally and never reaches the console —
  // which looks exactly like Crashlytics being broken.
  //
  // USTAAD_TEST_CRASH implies collection: deliberately crashing a build that
  // cannot report the crash is pointless.
  const forceTelemetry = bool.fromEnvironment('USTAAD_ANALYTICS_IN_DEBUG');
  const testCrash = bool.fromEnvironment('USTAAD_TEST_CRASH');
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode || forceTelemetry || testCrash,
  );

  // Framework errors: anything thrown inside build, layout or paint.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Everything the framework never sees: async gaps, platform channel failures,
  // errors in isolates. Without this the crashes that are hardest to reproduce
  // are also the only ones that stay invisible.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Verifies the Crashlytics pipeline on demand:
  //
  //   flutter run --dart-define=USTAAD_TEST_CRASH=true
  //
  // `bool.fromEnvironment` is a compile-time constant, so this whole branch is
  // stripped from any build that does not pass the flag — it cannot fire in a
  // release. The delay lets Crashlytics finish initialising first, and the
  // report only uploads on the NEXT launch, which is how Crashlytics works and
  // the usual reason people think it is broken.
  if (testCrash) {
    Future.delayed(const Duration(seconds: 6), () {
      FirebaseCrashlytics.instance.log('Deliberate test crash from main()');
      FirebaseCrashlytics.instance.crash();
    });
  }

  // ── Analytics and push ─────────────────────────────────────────────────────
  await Analytics.instance.init();
  await PushService.instance.init();
  // Channel and timezone only. Nothing is scheduled until HomeScreen knows
  // the streak, because a reminder without one has nothing to say.
  await ReminderService.instance.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Ustaad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white.withOpacity(0.6)),
          trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)),
          radius: const Radius.circular(8),
          thickness: WidgetStateProperty.all(8),
        ),
      ),
      routerConfig: router,
    );
  }
}
