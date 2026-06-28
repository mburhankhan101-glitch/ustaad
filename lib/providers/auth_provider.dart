import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/screens/auth/login_screen.dart';
import 'package:ustaad/screens/auth/test_selection.dart';
import 'package:ustaad/screens/auth/verify_email_screen.dart';
import 'package:ustaad/screens/home/home_screen.dart';

import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH STATUS ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum AuthStatus {
  initial,
  loading,
  authenticated,
  emailUnverified,
  unauthenticated,
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH STATE
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

  // FIX: This flag is the key to preventing race conditions.
  //
  // The root cause of "stuck" states on both web and mobile:
  // During signIn() / signUp() / signOut(), we're manually managing state
  // (loading → authenticated / error). But the Firebase stream ALSO fires
  // during these exact moments, and the two state updates fight each other.
  //
  // Example race on mobile second-logout:
  //   1. signIn() sets state = loading
  //   2. Firebase signs in the user
  //   3. Stream fires → sets state = authenticated (step A)
  //   4. signIn() backfill logic runs → sets state = authenticated (step B)
  //   5. ref.listen fires TWICE — navigates twice — GoRouter gets confused
  //
  // Solution: _isBusy = true during auth operations → stream stays quiet.
  // _isBusy = false when the operation is done → stream resumes normally.
  bool _isBusy = false;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _init();
  }

  void _init() {
    state = state.copyWith(status: AuthStatus.loading);

    // FIX: Use authStateChanges() instead of userChanges().
    //
    // userChanges() fires for EVERY user property change, including when
    // reload() is called mid-polling. This means every 3-second poll in
    // VerifyEmailScreen triggered the stream, which could temporarily reset
    // the state to emailUnverified DURING the exact moment reloadUser() was
    // about to set it to authenticated.
    //
    // authStateChanges() only fires on actual sign-in and sign-out events.
    // This means reload() calls are SILENT to the stream — only reloadUser()
    // handles the email verification state update, with no race condition.
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      // Respect the busy flag: if an auth operation is in progress,
      // it will set the state itself when it completes.
      if (_isBusy) return;

      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else if (!user.emailVerified) {
        state = AuthState(status: AuthStatus.emailUnverified, user: user);
      } else {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    });
  }

  // ── Sign In ────────────────────────────────────────────────────────────
  Future<bool> signIn({required String email, required String password}) async {
    _isBusy = true;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final credential = await _authService.login(
        email: email,
        password: password,
      );
      final user = credential.user;

      if (user != null && !user.emailVerified) {
        state = AuthState(status: AuthStatus.emailUnverified, user: user);
        _isBusy = false;
        return false;
      }

      // ── BACKFILL displayName for existing email/password users ─────────
      if (user != null &&
          (user.displayName == null || user.displayName!.trim().isEmpty)) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final storedName = doc.data()?['name'] as String?;
          if (storedName != null && storedName.trim().isNotEmpty) {
            await user.updateDisplayName(storedName.trim());
            await user.reload();
            final refreshed = FirebaseAuth.instance.currentUser;
            state = AuthState(
              status: AuthStatus.authenticated,
              user: refreshed ?? user,
            );
            _isBusy = false;
            return true;
          }
        } catch (_) {
          // Backfill is non-critical — never block login if it fails
        }
      }

      state = AuthState(status: AuthStatus.authenticated, user: user);
      _isBusy = false;
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapFirebaseError(e.code),
      );
      _isBusy = false;
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Something went wrong. Please try again.',
      );
      _isBusy = false;
      return false;
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────────────
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _isBusy = true;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      await _authService.signUp(name: name, email: email, password: password);

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Sign up failed. Please try again.',
        );
        _isBusy = false;
        return false;
      }

      state = AuthState(
        status: AuthStatus.emailUnverified,
        user: refreshedUser,
      );
      _isBusy = false;
      return true;
    } on FirebaseAuthException catch (e) {
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
      _isBusy = false;
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Something went wrong.',
      );
      _isBusy = false;
      return false;
    }
  }

  // ── Google Sign In ─────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    _isBusy = true;
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final credential = await _authService.signInWithGoogle();

      if (credential == null) {
        // User cancelled the Google picker — go back to unauthenticated
        // without an error message (it's not an error, user just cancelled).
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearError: true,
        );
        _isBusy = false;
        return false;
      }

      final user = credential.user;

      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Google sign in failed. Please try again.',
        );
        _isBusy = false;
        return false;
      }

      state = AuthState(status: AuthStatus.authenticated, user: user);
      _isBusy = false;
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapFirebaseError(e.code),
      );
      _isBusy = false;
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Google sign in failed. Please try again.',
      );
      _isBusy = false;
      return false;
    }
  }

  // ── Resend Verification Email ──────────────────────────────────────────
  Future<void> resendVerificationEmail() async {
    try {
      // Always use FirebaseAuth.instance.currentUser, not state.user.
      // state.user is a snapshot that can be stale on web.
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
    } catch (_) {}
  }

  // ── Reload User (called by VerifyEmailScreen polling) ─────────────────
  Future<void> reloadUser() async {
    // FIX 1: Always use FirebaseAuth.instance.currentUser?.reload(), NOT
    // state.user?.reload().
    //
    // state.user is the user object at the time it was last stored in
    // Riverpod state. On Flutter Web, the Firebase JS SDK can let this
    // reference go stale between polling calls. Calling reload() on a
    // stale reference either silently does nothing or throws an error
    // that the old catch(_){} block was hiding.
    //
    // FirebaseAuth.instance.currentUser is ALWAYS the live singleton —
    // guaranteed fresh by the Firebase SDK on every access.
    //
    // FIX 2: No _isBusy flag here — reloadUser() is called from the
    // VerifyEmailScreen timer. We WANT the state to update when the user
    // verifies their email. But since we switched to authStateChanges()
    // in _init(), reload() no longer triggers the stream at all.
    // reloadUser() is now the SOLE mechanism for email verification
    // detection — clean, no race condition.
    try {
      await FirebaseAuth.instance.currentUser?.reload();

      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        state = AuthState(status: AuthStatus.authenticated, user: refreshed);
      }
    } catch (e) {
      // FIX 3: Log the error instead of swallowing it silently.
      // The old catch (_) {} hid reload() failures on web (e.g. token
      // expired mid-verification, network blip), making the screen appear
      // "stuck" with no indication of what went wrong.
      debugPrint('[AuthNotifier] reloadUser error: $e');
      // Don't rethrow — a failed reload is not fatal. The next poll
      // (3 seconds later) will try again.
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────
  Future<void> signOut() async {
    // Don't set _isBusy here — we WANT the stream to pick up the
    // sign-out event and set state to unauthenticated automatically.
    // We just call the service and let the authStateChanges() stream
    // handle the state update.
    try {
      await _authService.logout();
      // Belt-and-suspenders: set state immediately so the UI reacts
      // without waiting for the stream event (which is near-instant
      // but adds a tiny delay on web).
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      // Even if logout throws, force unauthenticated state so the user
      // can at least get back to the login screen.
      state = const AuthState(status: AuthStatus.unauthenticated);
      debugPrint('[AuthNotifier] signOut error: $e');
    }
  }

  // ── Clear Error ────────────────────────────────────────────────────────
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ── Firebase Error Mapping ─────────────────────────────────────────────
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
      case 'popup-blocked':
        return 'Google sign-in popup was blocked. Please allow popups for this site.';
      case 'popup-closed-by-user':
        return 'Sign-in cancelled. Please try again.';
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

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authProvider).status;
});

// ─────────────────────────────────────────────────────────────────────────────
// AUTH GATE — checks Firestore to decide HomeScreen vs TestSelectionScreen
// ─────────────────────────────────────────────────────────────────────────────

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) return const LoginScreen();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0E2E),
                    Color(0xFF1A1464),
                    Color(0xFF6C63FF),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) return const HomeScreen();

        final data = snapshot.data?.data() as Map<String, dynamic>?;

        // FIX: Align field check with what TestSelectionScreen actually writes.
        // LoginScreen was checking 'selectedTests' but AuthGateScreen was checking
        // 'testType'. Pick ONE field name and use it consistently everywhere.
        // Check both during the transition period so existing users are not
        // accidentally sent back to TestSelection.
        final hasTestType =
            data != null &&
            (data['testType'] != null || data['selectedTests'] != null);

        return hasTestType ? const HomeScreen() : const TestSelectionScreen();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH WRAPPER — top-level router in MaterialApp home:
// ─────────────────────────────────────────────────────────────────────────────

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.authenticated:
        return const AuthGateScreen();

      case AuthStatus.emailUnverified:
        return const VerifyEmailScreen();

      case AuthStatus.loading:
      case AuthStatus.initial:
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0E2E),
                  Color(0xFF1A1464),
                  Color(0xFF6C63FF),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        );

      case AuthStatus.unauthenticated:
      default:
        return const LoginScreen();
    }
  }
}
