import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/providers/progress_provider.dart';

/// Whether a stored streak is still alive when Home reads it.
///
/// Nothing resets the stored streak when a day is missed; it is only rewritten
/// when the next session ends. So this is the one place that decides a chain
/// has lapsed, which both the streak bar and the broken streak moment rely on.
void main() {
  final evening = DateTime(2026, 9, 11, 21, 30);

  test('practised today: the stored streak stands', () {
    final s = streakStatus(
      storedStreak: 6,
      lastActiveDate: '2026-09-11',
      now: evening,
    );
    expect(s.streak, 6);
    expect(s.isBroken, isFalse);
    expect(s.lost, 0);
  });

  test('practised yesterday: still alive, today is not over yet', () {
    final s = streakStatus(
      storedStreak: 6,
      lastActiveDate: '2026-09-10',
      now: evening,
    );
    expect(s.streak, 6);
    expect(s.isBroken, isFalse);
  });

  test('missed a whole day: broken, shows 0, remembers what was lost', () {
    final s = streakStatus(
      storedStreak: 6,
      lastActiveDate: '2026-09-09',
      now: evening,
    );
    expect(s.streak, 0);
    expect(s.isBroken, isTrue);
    expect(s.lost, 6);
  });

  test('never practised: nothing to break', () {
    final s = streakStatus(storedStreak: 0, lastActiveDate: '', now: evening);
    expect(s.streak, 0);
    expect(s.isBroken, isFalse);
  });

  test('yesterday across a month boundary is still alive', () {
    final s = streakStatus(
      storedStreak: 3,
      lastActiveDate: '2026-08-31',
      now: DateTime(2026, 9, 1, 0, 5),
    );
    expect(s.isBroken, isFalse);
    expect(s.streak, 3);
  });
}
