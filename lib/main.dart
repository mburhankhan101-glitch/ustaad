import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← for orientation lock
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
