import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/providers/progress_provider.dart';

/// Streak messaging, pinned at its date boundaries.
///
/// streakMessage() decides what a student is told about their streak, and it
/// branches entirely on comparing a stored date string against today and
/// yesterday. Off-by-one-day logic is the classic place for this to go wrong,
/// and the failure is invisible in testing because you have to be using the
/// app across a midnight boundary to see it.
///
/// The worst outcome is not a wrong emoji: it is roasting someone who did not
/// miss a day. These tests exist to stop that.
String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  final today = _date(DateTime.now());
  final yesterday = _date(DateTime.now().subtract(const Duration(days: 1)));
  final lastWeek = _date(DateTime.now().subtract(const Duration(days: 7)));

  group('a brand new student is invited, not roasted', () {
    test('never practised — no streak, no date', () {
      final msg = streakMessage(0, '');
      expect(msg.isRoast, isFalse,
          reason: 'someone who has never opened a quiz has nothing to be '
              'roasted for');
      expect(msg.text.trim(), isNotEmpty);
      expect(msg.emoji.trim(), isNotEmpty);
    });
  });

  group('a broken streak is roasted, an intact one never is', () {
    test('streak reset to 0 after a gap — roast', () {
      final msg = streakMessage(0, lastWeek);
      expect(msg.isRoast, isTrue,
          reason: 'a student with old activity and a zeroed streak did miss '
              'days, which is what the roast is for');
    });

    test('practised today — never a roast', () {
      for (final streak in [1, 2, 7, 30, 100]) {
        final msg = streakMessage(streak, today);
        expect(msg.isRoast, isFalse,
            reason: 'streak $streak practised today and must not be roasted');
      }
    });

    test('practised yesterday and streak intact — never a roast', () {
      for (final streak in [1, 3, 10, 50]) {
        final msg = streakMessage(streak, yesterday);
        expect(msg.isRoast, isFalse,
            reason: 'streak $streak is still alive; yesterday is not a miss');
      }
    });
  });

  group('every branch returns something displayable', () {
    test('no combination yields an empty message or emoji', () {
      final dates = [today, yesterday, lastWeek, ''];
      final streaks = [0, 1, 2, 3, 5, 7, 14, 30, 60, 100, 365];

      for (final d in dates) {
        for (final s in streaks) {
          final msg = streakMessage(s, d);
          expect(msg.text.trim(), isNotEmpty,
              reason: 'streak=$s date="$d" produced an empty message, which '
                  'renders as a blank line on the home screen');
          expect(msg.emoji.trim(), isNotEmpty,
              reason: 'streak=$s date="$d" produced no emoji');
        }
      }
    });
  });

  group('the roast is stable within a day', () {
    test('same inputs give the same message twice', () {
      // The roast is picked by weekday rather than at random, so the home
      // screen does not show a different insult on every rebuild — the same
      // class of bug that made the greeting reshuffle and the screen shake.
      final first = streakMessage(0, lastWeek);
      final second = streakMessage(0, lastWeek);
      expect(first.text, second.text);
      expect(first.emoji, second.emoji);
    });
  });
}
