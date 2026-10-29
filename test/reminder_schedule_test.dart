// When the streak reminder fires, and when it stays quiet.
//
// This is the whole retention mechanic, and almost all of it is one pure
// function. Getting it wrong is not a crash — it is a notification at 11pm,
// or a nag telling someone their streak is about to break two days after it
// already broke. Neither shows up in Crashlytics; both get the app muted.

import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/core/notifications/reminder_service.dart';

/// `yyyy-MM-dd`, the format the progress document stores.
String d(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

void main() {
  // A Tuesday afternoon, comfortably before the 8pm slot.
  final afternoon = DateTime(2026, 10, 27, 16, 30);
  final evening = DateTime(2026, 10, 27, 22, 15);

  final today = d(afternoon);
  final yesterday = d(afternoon.subtract(const Duration(days: 1)));
  final lastWeek = d(afternoon.subtract(const Duration(days: 6)));

  DateTime? fire({
    required int streak,
    required String lastActive,
    DateTime? now,
  }) => ReminderService.nextFireTime(
    streak: streak,
    lastActiveDate: lastActive,
    now: now ?? afternoon,
  );

  group('when it should fire', () {
    test('streak alive, nothing done today, still before 8pm → tonight', () {
      final at = fire(streak: 5, lastActive: yesterday);
      expect(at, isNotNull);
      expect(at!.day, afternoon.day);
      expect(at.hour, 20);
    });

    test('already practised today → tomorrow, not tonight', () {
      final at = fire(streak: 5, lastActive: today);
      expect(at, isNotNull);
      expect(at!.day, afternoon.day + 1);
      expect(at.hour, 20);
    });

    test('past 8pm with nothing done → tomorrow, never right now', () {
      // The streak survives until midnight, so a notification at 10:15pm
      // would be both useless and the most annoying possible timing.
      final at = fire(streak: 5, lastActive: yesterday, now: evening);
      expect(at, isNotNull);
      expect(at!.day, evening.day + 1);
      expect(at.hour, 20);
    });
  });

  group('when it should stay quiet', () {
    test('no streak worth protecting', () {
      expect(fire(streak: 0, lastActive: yesterday), isNull);
      expect(fire(streak: 1, lastActive: yesterday), isNull);
    });

    test('streak already broken — the warning would be a lie', () {
      // Last practice was six days ago. There is nothing left to save, and
      // "your 5 day streak ends tonight" is simply untrue.
      expect(fire(streak: 5, lastActive: lastWeek), isNull);
    });

    test('a user who has never practised is never nagged', () {
      expect(fire(streak: 0, lastActive: ''), isNull);
    });
  });

  group('copy', () {
    test('every line reads as a sentence with the streak filled in', () {
      for (var day = 1; day <= 31; day++) {
        final line = ReminderService.lineFor(streak: 7, day: day);
        expect(line, hasLength(2));
        for (final part in line) {
          expect(part, isNotEmpty);
          // An unfilled placeholder shipping to a student is the classic
          // version of this bug.
          expect(part, isNot(contains('{n}')));
        }
      }
    });

    test('consecutive misses do not repeat the same sentence', () {
      final a = ReminderService.lineFor(streak: 3, day: 10);
      final b = ReminderService.lineFor(streak: 3, day: 11);
      expect(a[0], isNot(b[0]));
    });

    test('the streak number actually appears somewhere', () {
      final line = ReminderService.lineFor(streak: 12, day: 1);
      expect('${line[0]} ${line[1]}', contains('12'));
    });
  });

  group('the cancelling behaviour the whole design rests on', () {
    test('practising flips tonight to tomorrow', () {
      // Before the quiz: armed for tonight.
      final before = fire(streak: 4, lastActive: yesterday);
      expect(before!.day, afternoon.day);

      // After the quiz, lastActiveDate becomes today — and the next fire
      // time moves to tomorrow, so refresh() cancels tonight's instead of
      // rescheduling it. This is what makes "only if they have not
      // practised" work without any background job.
      final after = fire(streak: 5, lastActive: today);
      expect(after!.day, afternoon.day + 1);
    });
  });
}
