import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/auth_provider.dart';
import 'package:ustaad/screens/auth/login_screen.dart';
import 'package:ustaad/screens/auth/signup_screen.dart';
import 'package:ustaad/screens/auth/test_selection.dart';
import 'package:ustaad/screens/auth/verify_email_screen.dart';
import 'package:ustaad/screens/home/home_screen.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ustaad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/verify_email': (context) => const VerifyEmailScreen(),
        '/test_selection': (context) => const TestSelectionScreen(),
        '/auth_wrapper': (context) => const AuthWrapper(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
