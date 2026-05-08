import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/screens/auth/login_screen.dart';
import 'package:ustaad/screens/auth/test_selection.dart';
import 'package:ustaad/screens/auth/verify_email_screen.dart';

import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH STATUS ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum AuthStatus {
  /// App just launched, we don't know yet
  initial,

  /// Firebase is checking — show a loader
  loading,

  /// Logged in AND email verified
  authenticated,

  /// Logged in but email NOT yet verified
  emailUnverified,

  /// Not logged in at all
  unauthenticated,
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH STATE  (immutable snapshot)
// ─────────────────────────────────────────────────────────────────────────────

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  /// Convenience getters
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get needsEmailVerification => status == AuthStatus.emailUnverified;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'AuthState(status: $status, user: ${user?.email}, error: $errorMessage)';
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _init();
  }

  // ── Listen to Firebase auth stream on startup ──────────────────────────
  // Inside AuthNotifier in auth_provider.dart
  void _init() {
    state = state.copyWith(status: AuthStatus.loading);

    // Switch from authStateChanges() to userChanges()
    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else if (!user.emailVerified) {
        state = AuthState(status: AuthStatus.emailUnverified, user: user);
      } else {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    });
  }

  // ── Sign In with Email ─────────────────────────────────────────────────
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final credential = await _authService.login(
        email: email,
        password: password,
      );
      final user = credential.user;

      if (user != null && !user.emailVerified) {
        // Logic for "Redirect to verify screen even after closing app"
        state = AuthState(status: AuthStatus.emailUnverified, user: user);
        return false; // Returns false to tell the UI to show a message or redirect
      }

      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapFirebaseError(e.code),
      );
      return false;
    }
  }

  // ── Sign Up with Email ─────────────────────────────────────────────────
  // Inside AuthNotifier class in auth_provider.dart
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final credential = await _authService.signUp(
        name: name,
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Sign up failed. Please try again.',
        );
        return false;
      }

      // REMOVED: await user.sendEmailVerification();
      // It is already handled inside _authService.signUp!

      state = AuthState(status: AuthStatus.emailUnverified, user: user);
      return true;
    } on FirebaseAuthException catch (e) {
      // SPECIAL CASE: If they try to sign up with an existing but unverified email
      if (e.code == 'email-already-in-use') {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'This account already exists. Please log in.',
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: _mapFirebaseError(e.code),
        );
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Something went wrong.',
      );
      return false;
    }
  }

  // ── Google Sign In ─────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final credential = await _authService.signInWithGoogle();

      if (credential == null) {
        // User cancelled the Google picker — not an error
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return false;
      }

      final user = credential.user;

      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Google sign in failed. Please try again.',
        );
        return false;
      }

      // Google accounts are pre-verified
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapFirebaseError(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Google sign in failed: ${e.toString()}',
      );
      return false;
    }
  }

  // ── Resend Verification Email ──────────────────────────────────────────
  Future<void> resendVerificationEmail() async {
    try {
      await state.user?.sendEmailVerification();
    } catch (_) {
      // Silently fail — the VerifyEmailScreen handles its own timer UI
    }
  }

  // ── Reload user to check if email was verified ─────────────────────────
  Future<void> reloadUser() async {
    try {
      await state.user?.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed != null && refreshed.emailVerified) {
        state = AuthState(status: AuthStatus.authenticated, user: refreshed);
      }
    } catch (_) {}
  }

  // ── Sign Out ───────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _authService.logout();
      // Force the state to unauthenticated immediately
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Clear any error manually (e.g. when user starts typing again) ──────
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ── Firebase error code → human readable ──────────────────────────────
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger one.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'Something went wrong (code: $code).';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// The AuthService instance — single shared instance across the app
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// The main auth provider — watch this anywhere you need auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

/// Convenience provider — just the current Firebase user (or null)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Convenience provider — just the auth status
final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authProvider).status;
});

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This watches the auth state in real-time
    final authState = ref.watch(authProvider);

    // Depending on the status, it returns a DIFFERENT screen
    switch (authState.status) {
      case AuthStatus.authenticated:
        return const TestSelectionScreen();
      case AuthStatus.emailUnverified:
        return const VerifyEmailScreen();
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.unauthenticated:
      case AuthStatus.initial:
      default:
        return const LoginScreen();
    }
  }
}
