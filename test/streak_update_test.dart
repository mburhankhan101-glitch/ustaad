import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/providers/progress_provider.dart';

/// What finishing a session does to the streak, and whether it celebrates.
///
/// updateStreak() used to do this arithmetic inline around two Firestore calls,
/// so the only way to check a midnight or month boundary was to be using the
/// app at that moment. It is pure now, and pinned here.
void main() {
  final evening = DateTime(2026, 9, 11, 21, 30);

  test('a second session on the same day changes nothing', () {
    expect(
      computeStreakUpdate(
        lastActiveDate: '2026-09-11',
        currentStreak: 4,
        longestStreak: 9,
        now: evening,
      ),
      isNull,
    );
  });

  test('practising yesterday extends the chain and celebrates', () {
    final u = computeStreakUpdate(
      lastActiveDate: '2026-09-10',
      currentStreak: 4,
      longestStreak: 9,
      now: evening,
    )!;
    expect(u.previous, 4);
    expect(u.streak, 5);
    expect(u.longest, 9);
    expect(u.increased, isTrue);
  });

  test('passing the old record raises the longest streak', () {
    final u = computeStreakUpdate(
      lastActiveDate: '2026-09-10',
      currentStreak: 9,
      longestStreak: 9,
      now: evening,
    )!;
    expect(u.streak, 10);
    expect(u.longest, 10);
  });

  test('a very first session starts at 1 and celebrates', () {
    final u = computeStreakUpdate(
      lastActiveDate: '',
      currentStreak: 0,
      longestStreak: 0,
      now: evening,
    )!;
    expect(u.streak, 1);
    expect(u.increased, isTrue);
  });

  test('coming back after a gap resets to 1 without a celebration', () {
    // That student is shown the broken streak overlay, not the progress map.
    final u = computeStreakUpdate(
      lastActiveDate: '2026-09-08',
      currentStreak: 6,
      longestStreak: 9,
      now: evening,
    )!;
    expect(u.streak, 1);
    expect(u.longest, 9);
    expect(u.increased, isFalse);
  });

  test('yesterday across a month boundary', () {
    final u = computeStreakUpdate(
      lastActiveDate: '2026-02-28',
      currentStreak: 3,
      longestStreak: 3,
      now: DateTime(2026, 3, 1, 8),
    )!;
    expect(u.streak, 4);
  });

  test('yesterday across a year boundary', () {
    final u = computeStreakUpdate(
      lastActiveDate: '2026-12-31',
      currentStreak: 12,
      longestStreak: 12,
      now: DateTime(2027, 1, 1, 0, 5),
    )!;
    expect(u.streak, 13);
  });

  test('a minute past midnight, the previous date counts as yesterday', () {
    final u = computeStreakUpdate(
      lastActiveDate: '2026-09-10',
      currentStreak: 2,
      longestStreak: 2,
      now: DateTime(2026, 9, 11, 0, 1),
    )!;
    expect(u.streak, 3);
  });
}
