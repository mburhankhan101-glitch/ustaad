import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Only used on mobile — not initialized on web
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

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
