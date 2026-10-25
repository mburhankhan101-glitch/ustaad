import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb, debugPrint
import 'package:google_sign_in/google_sign_in.dart';

/// Deletes a user's account and everything stored against it.
///
/// Google Play requires any app that offers account creation to also offer
/// account deletion, both in the app and through a web page. This covers the
/// in-app half.
///
/// Order matters. Firestore data goes first, while the user is still signed in
/// and security rules still resolve `request.auth.uid`. Deleting the auth user
/// first would lock us out of their own documents and strand them in the
/// database forever.
///
/// Re-authentication happens before anything is deleted, not after a failure.
/// Firebase only allows `delete()` on a recent credential, and discovering that
/// halfway through would leave the account alive with its data already gone.
class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const _passwordProvider = 'password';
  static const _googleProvider = 'google.com';

  /// Firebase treats a login as "recent" for roughly five minutes. Three keeps
  /// us clear of that edge and of any clock skew, without prompting someone who
  /// signed in moments ago.
  static const _recentLoginWindow = Duration(minutes: 3);

  User? get _user => _auth.currentUser;

  /// True only when Firebase would actually reject `delete()` for a stale
  /// credential.
  ///
  /// The first version of this asked every user to re-authenticate, which meant
  /// someone who had just signed in was still shown a Google account picker
  /// with no explanation of why. Now the picker only appears when it is
  /// genuinely required.
  bool get needsRecentLogin {
    final lastSignIn = _user?.metadata.lastSignInTime;
    if (lastSignIn == null) return true;
    return DateTime.now().difference(lastSignIn) > _recentLoginWindow;
  }

  /// Which sign-in method this account uses. Drives which re-auth prompt the
  /// UI shows: a password field, or the Google account picker.
  bool get usesPassword =>
      _user?.providerData.any((p) => p.providerId == _passwordProvider) ??
      false;

  bool get usesGoogle =>
      _user?.providerData.any((p) => p.providerId == _googleProvider) ?? false;

  // ── Re-authentication ─────────────────────────────────────────────────────

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _user;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'You are not signed in.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Returns false if the user backed out of the Google account picker.
  Future<bool> reauthenticateWithGoogle() async {
    final user = _user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'You are not signed in.',
      );
    }

    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      await user.reauthenticateWithPopup(provider);
      return true;
    }

    final googleSignIn = GoogleSignIn(scopes: ['email']);
    // Force the picker rather than reusing a cached session, so the person
    // deleting the account is the one who proves they own it.
    await googleSignIn.signOut();

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return false; // cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
    return true;
  }

  // ── Deletion ──────────────────────────────────────────────────────────────

  /// Deletes the user's Firestore documents. Does not touch the auth account.
  ///
  /// Split from [deleteAuthUser] so the caller can re-authenticate between the
  /// two if Firebase turns out to want a fresher credential — without that
  /// split, a stale-credential failure would land after the data was already
  /// gone, leaving a live account with nothing in it.
  Future<void> deleteUserData() async {
    final user = _user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'You are not signed in.',
      );
    }
    final uid = user.uid;

    await _deleteSeenQuestions(uid);
    await _deleteFeedback(uid);
    await _firestore.collection('users').doc(uid).delete();
  }

  /// Deletes the auth account. Run this after [deleteUserData]: once the
  /// credential is gone, no further Firestore write would be authorised.
  ///
  /// Throws [FirebaseAuthException] with code `requires-recent-login` if the
  /// credential has gone stale between the freshness check and here.
  Future<void> deleteAuthUser() async {
    final user = _user;
    if (user == null) return; // already gone
    await user.delete();
  }

  /// `users/{uid}/seenQuestions` holds one document per exam section, each with
  /// a `seenIds` array, so this is a handful of documents rather than one per
  /// question. A single batch is enough, but it pages anyway in case the shape
  /// changes later.
  Future<void> _deleteSeenQuestions(String uid) async {
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection('seenQuestions');

    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 400) return;
    }
  }

  /// Feedback documents carry the user's name and email, so they go with the
  /// account.
  ///
  /// Best effort on purpose: `feedback` is a top-level collection and the
  /// security rules for it live in the Firebase console, not this repo. If
  /// those rules do not let a user delete their own feedback, this throws
  /// permission-denied — and failing the whole deletion over it would leave
  /// the person with an account they asked to be rid of. The account still
  /// goes; the orphaned feedback is the smaller harm.
  Future<void> _deleteFeedback(String uid) async {
    try {
      while (true) {
        final snapshot = await _firestore
            .collection('feedback')
            .where('userId', isEqualTo: uid)
            .limit(400)
            .get();
        if (snapshot.docs.isEmpty) return;

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (snapshot.docs.length < 400) return;
      }
    } catch (e) {
      debugPrint('[Ustaad] Could not delete feedback for $uid: $e');
    }
  }
}
