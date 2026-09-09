import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Only used on mobile — not initialized on web
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // ── Guest sign in ────────────────────────────────────────────────────────
  /// Signs in anonymously so a student can answer questions before an account
  /// exists.
  ///
  /// The account creation and email verification screens between an install and
  /// the first question were the largest single drop in the funnel: a student
  /// on mobile data had to leave the app, find a verification mail that is
  /// often in spam, and come back. A guest gets a real Firebase uid, so every
  /// document they create lives at users/{uid} exactly like a signed-up user's,
  /// and [linkEmailPassword] later keeps that same uid.
  ///
  /// Requires the Anonymous provider to be enabled in the Firebase console.
  /// Without it this throws `operation-not-allowed`, which callers must treat
  /// as "fall back to the login screen" rather than a crash.
  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  // ── Sign Up ──────────────────────────────────────────────────────────────
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user?.updateDisplayName(name);
    await credential.user?.reload();
    await credential.user?.sendEmailVerification();

    return credential;
  }

  // ── Guest upgrade ────────────────────────────────────────────────────────
  /// Attaches an email and password to the guest account that is already
  /// signed in, instead of creating a second one.
  ///
  /// This is the whole point of the guest flow: linking keeps the same uid, so
  /// the streak, accuracy, weak topics and seen-question history built up as a
  /// guest survive. Calling [signUp] here instead would mint a fresh uid and
  /// silently abandon all of it.
  ///
  /// Throws `credential-already-in-use` when that email already has an
  /// account. There is no safe automatic answer to that — the guest's progress
  /// and the existing account's progress cannot be merged without deciding
  /// which one wins — so the caller has to surface it and let the student
  /// choose to sign in to the existing account instead.
  Future<UserCredential> linkEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw FirebaseAuthException(
        code: 'no-anonymous-user',
        message: 'linkEmailPassword called without a signed-in guest.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    final result = await user.linkWithCredential(credential);

    await result.user?.updateDisplayName(name);
    await result.user?.reload();
    await result.user?.sendEmailVerification();

    return result;
  }

  /// Google equivalent of [linkEmailPassword]. Same uid-preserving contract,
  /// same `credential-already-in-use` caveat.
  Future<UserCredential?> linkGoogle() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw FirebaseAuthException(
        code: 'no-anonymous-user',
        message: 'linkGoogle called without a signed-in guest.',
      );
    }

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return await user.linkWithPopup(provider);
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // cancelled the picker

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await user.linkWithCredential(credential);
  }

  // ── Login ────────────────────────────────────────────────────────────────
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ── Google Sign In ───────────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      } else {
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');

    // FIX: Force the Google account picker to appear every time.
    // Without this, the browser silently reuses the last Google session
    // after logout, making it impossible to switch accounts on web.
    provider.setCustomParameters({'prompt': 'select_account'});

    // signInWithPopup opens a Google login popup window in the browser.
    // If the popup is blocked by the browser, it throws an error.
    final result = await _auth.signInWithPopup(provider);
    return result;
  }

  Future<UserCredential?> _signInWithGoogleMobile() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // ── Check email verified ─────────────────────────────────────────────────
  Future<bool> isEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ── Resend verification email ────────────────────────────────────────────
  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  Future<void> logout() async {
    if (!kIsWeb) {
      // FIX: Use disconnect() instead of signOut() on mobile.
      //
      // signOut()     — clears the OAuth token but keeps the account
      //                 "authorized". Next time signIn() is called, it
      //                 silently returns the SAME account without showing
      //                 the picker. This is why switching accounts on mobile
      //                 gets stuck after the second logout.
      //
      // disconnect()  — fully revokes the OAuth grant. The next signIn()
      //                 MUST show the account picker, allowing the user to
      //                 choose a different account cleanly.
      try {
        await _googleSignIn.disconnect();
      } catch (e) {
        // disconnect() can throw if the account was never connected via
        // Google (e.g., email/password user). Fall back to signOut() so
        // we always clean up the local token cache at minimum.
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        debugPrint('Google disconnect error (mobile): $e');
      }
    }
    // Always sign out of Firebase last, after Google cleanup.
    await _auth.signOut();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
}
