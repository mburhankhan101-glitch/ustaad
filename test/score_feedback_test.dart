// What Ustu says about a score, and for which quiz lengths.
//
// The thresholds used to be absolute counts — `_correct >= 7` to celebrate,
// `_correct <= 6` to commiserate, `>= 8` and `>= 5` for the ring colour.
// Every one of them silently assumed a quiz is ten questions long. A
// four-question weak-topic drill answered perfectly scored 4, fell under the
// "<= 6" branch, and was told off for it.
//
// None of that is visible in a crash report. A student just gets a sad owl
// after getting everything right and quietly concludes the app is broken.

import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/screens/quiz/result_screen.dart';

/// Accuracy the way ResultScreen computes it, so the tests exercise the same
/// rounding the app does.
int acc(int correct, int attempted) =>
    attempted > 0 ? ((correct / attempted) * 100).round() : 0;

void main() {
  group('the weak-topic drill that started this', () {
    test('4 out of 4 is celebrated, not commiserated with', () {
      final a = acc(4, 4);
      expect(a, 100);
      expect(celebratesScore(attempted: 4, accuracyPercent: a), isTrue);
      expect(commiseratesScore(attempted: 4, accuracyPercent: a), isFalse);
      expect(scoreTier(a), 2);
    });

    test('the old rule would have failed it', () {
      // Guards the premise: 4 correct is <= 6, which is what sent a perfect
      // score to the bad-score overlay. If this ever stops being true the
      // test above is no longer testing anything.
      const correct = 4;
      expect(correct <= 6, isTrue);
      expect(correct >= 8, isFalse);
    });
  });

  group('short quizzes are judged on their own length', () {
    test('5 out of 5 is a top tier', () {
      expect(scoreTier(acc(5, 5)), 2);
      expect(celebratesScore(attempted: 5, accuracyPercent: acc(5, 5)), isTrue);
    });

    test('3 out of 4 still celebrates', () {
      expect(acc(3, 4), 75);
      expect(celebratesScore(attempted: 4, accuracyPercent: acc(3, 4)), isTrue);
    });

    test('2 out of 4 does not', () {
      expect(acc(2, 4), 50);
      expect(
        commiseratesScore(attempted: 4, accuracyPercent: acc(2, 4)),
        isTrue,
      );
      expect(scoreTier(acc(2, 4)), 1);
    });

    test('1 out of 4 is the bottom tier', () {
      expect(scoreTier(acc(1, 4)), 0);
    });
  });

  group('the ten-question quiz keeps behaving as it did', () {
    test('7 of 10 still celebrates', () {
      expect(
        celebratesScore(attempted: 10, accuracyPercent: acc(7, 10)),
        isTrue,
      );
    });

    test('6 of 10 still commiserates', () {
      expect(
        commiseratesScore(attempted: 10, accuracyPercent: acc(6, 10)),
        isTrue,
      );
    });

    test('8 of 10 is the top ring, 5 of 10 the middle', () {
      expect(scoreTier(acc(8, 10)), 2);
      expect(scoreTier(acc(5, 10)), 1);
      expect(scoreTier(acc(4, 10)), 0);
    });
  });

  group('a resumed quiz with nothing new answered', () {
    test('Ustu says nothing either way', () {
      // Every question was carried over from an earlier sitting, so there is
      // no performance in this session to judge. Both overlays must stay shut
      // rather than one of them judging a session that did not happen.
      expect(celebratesScore(attempted: 0, accuracyPercent: 0), isFalse);
      expect(commiseratesScore(attempted: 0, accuracyPercent: 0), isFalse);
    });

    test('and not even when the stale accuracy looks good', () {
      expect(celebratesScore(attempted: 0, accuracyPercent: 100), isFalse);
      expect(commiseratesScore(attempted: 0, accuracyPercent: 100), isFalse);
    });
  });

  test('exactly one overlay fires for any real session', () {
    for (var attempted = 1; attempted <= 20; attempted++) {
      for (var correct = 0; correct <= attempted; correct++) {
        final a = acc(correct, attempted);
        final up = celebratesScore(attempted: attempted, accuracyPercent: a);
        final down = commiseratesScore(
          attempted: attempted,
          accuracyPercent: a,
        );
        expect(
          up != down,
          isTrue,
          reason: '$correct/$attempted gave celebrate=$up commiserate=$down',
        );
      }
    }
  });
}
