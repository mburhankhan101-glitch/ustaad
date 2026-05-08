import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // ── Sign Up ──────────────────────────────────────
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 1. Update the name
    await credential.user?.updateDisplayName(name);

    // 2. CRITICAL: Reload the user to sync the local object with the server
    await credential.user?.reload();

    await credential.user?.sendEmailVerification();
    return credential;
  }

  // ── Login ────────────────────────────────────────
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ── Google Sign In ───────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // ── Check email verified ─────────────────────────
  Future<bool> isEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ── Resend verification email ────────────────────
  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // ── Logout ───────────────────────────────────────
  Future<void> logout() async {
    try {
      // 1. Try to sign out from Google (if they were using it)
      // Use signOut() instead of disconnect() for a normal logout
      await _googleSignIn.signOut();
    } catch (e) {
      // If they weren't signed in with Google, this would throw an error.
      // We catch it so the code can continue to the Firebase signOut below.
      debugPrint("Google sign out error: $e");
    }

    // 2. The actual Firebase logout
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
