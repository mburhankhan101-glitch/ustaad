import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaad/models/paper_model.dart';
import 'package:ustaad/screens/auth/test_selection.dart';
import 'package:ustaad/screens/papers/program/program_selection_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/verify_email_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/quiz/quiz_screen.dart';
import '../../screens/profile/profile_screen.dart';

// ── Helper to bundle both enums as one object ─────────────────────────────────
class PapersRouteArgs {
  final ExamType examType;
  final UserProgram userProgram;

  const PapersRouteArgs({required this.examType, required this.userProgram});
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify_email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/test_selection',
        builder: (context, state) => const TestSelectionScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),

      // /quiz?exam=FAST-NU&section=Advanced+Maths
      GoRoute(
        path: '/quiz',
        builder: (context, state) {
          final exam = state.uri.queryParameters['exam'] ?? '';
          final section = state.uri.queryParameters['section'] ?? '';
          return QuizScreen(exam: exam, section: section);
        },
      ),

      // /papers — enums passed via context.go('/papers', extra: PapersRouteArgs(...))
      // Never linked from landing page (needs real user data)
      GoRoute(
        path: '/papers',
        builder: (context, state) {
          final args = state.extra as PapersRouteArgs?;

          // Fallback if somehow reached without args (e.g. browser refresh)
          if (args == null) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'Please go back and select your exam.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          return ProgramSelectionScreen(
            examType: args.examType,
            userProgram: args.userProgram,
          );
        },
      ),

      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
