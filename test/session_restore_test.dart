// Whether a returning student has to log in again.
//
// This has broken twice. Both times it looked like a login bug and was
// really a timing one: Firebase restores the signed-in user from disk
// asynchronously, so for a moment after launch currentUser is null for
// someone who is perfectly signed in. The splash screen decided during that
// moment and sent them to the login screen.
//
// The second fix added a stored hint — "there was a session last time" — so
// the splash knows whether a null is worth waiting on. These tests cover the
// two decisions that hint drives, because the failure mode is invisible in
// development (a fast machine always restores in time) and infuriating in
// the field.

import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/screens/splash/splash_screen.dart';

void main() {
  group('whether to wait for the restore', () {
    test('a user already restored is not waited for', () {
      expect(
        SplashScreen.shouldWaitForRestore(
          hasCurrentUser: true,
          hadSession: true,
        ),
        isFalse,
      );
    });

    test('a signed-out student never waits', () {
      // The whole point of the hint: someone with no session should reach the
      // login screen immediately, not sit through a four-second pause for a
      // restore that is never coming.
      expect(
        SplashScreen.shouldWaitForRestore(
          hasCurrentUser: false,
          hadSession: false,
        ),
        isFalse,
      );
    });

    test('no user yet but a session last time is the case worth waiting on', () {
      expect(
        SplashScreen.shouldWaitForRestore(
          hasCurrentUser: false,
          hadSession: true,
        ),
        isTrue,
      );
    });
  });

  group('what the hint becomes afterwards', () {
    test('resolving a user records that there is a session', () {
      expect(
        SplashScreen.hintAfterResolve(hadSession: false, resolvedUser: true),
        isTrue,
      );
      expect(
        SplashScreen.hintAfterResolve(hadSession: true, resolvedUser: true),
        isTrue,
      );
    });

    test('no session expected and none found is recorded as none', () {
      expect(
        SplashScreen.hintAfterResolve(hadSession: false, resolvedUser: false),
        isFalse,
      );
    });

    test('a restore that was too slow must not erase the hint', () {
      // The subtle one. Expecting a session and not getting a user means the
      // restore ran long, not that the student is signed out. Writing false
      // here would remove the only reason the next launch would wait, so one
      // slow start would become a login screen every single time.
      expect(
        SplashScreen.hintAfterResolve(hadSession: true, resolvedUser: false),
        isNull,
      );
    });
  });

  test('a signed-in student is never sent to login by these two rules', () {
    // Walks every combination and asserts the pair never conspires to both
    // give up on a restore and forget that a session existed.
    for (final hasUser in [true, false]) {
      for (final hadSession in [true, false]) {
        final waits = SplashScreen.shouldWaitForRestore(
          hasCurrentUser: hasUser,
          hadSession: hadSession,
        );
        final hint = SplashScreen.hintAfterResolve(
          hadSession: hadSession,
          resolvedUser: hasUser,
        );
        if (hadSession && !hasUser) {
          expect(waits, isTrue, reason: 'must wait when a session is expected');
          expect(hint, isNull, reason: 'must not forget the session');
        }
        if (hasUser) {
          expect(hint, isTrue);
        }
      }
    }
  });
}
