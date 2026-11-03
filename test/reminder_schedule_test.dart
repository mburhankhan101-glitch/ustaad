// What Ustu says on which evening, and when it says nothing at all.
//
// This is the whole retention mechanic, and almost all of it is one pure
// function. Getting it wrong is not a crash — it is a notification at 11pm,
// or a nag telling someone their streak is about to break two days after it
// already broke. Neither shows up in Crashlytics; both get the app muted.
//
// These replace the tests for ReminderService.nextFireTime, which planned one
// reminder for one evening and only for a student with a two-day streak. That
// reached five users out of seventy-four, and could never cause the day-one
// to day-two return, because having a two-day streak means the return has
// already happened. Two assertions from the old file are deliberately
// inverted below and marked as such: a student with no streak, and a student
// who has never practised, are both spoken to now.

import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/core/notifications/reminder_plan.dart';

/// `yyyy-MM-dd`, the format the progress document stores.
String d(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

void main() {
  // A Tuesday afternoon, comfortably before the 8pm slot.
  final afternoon = DateTime(2026, 11, 3, 15, 0);
  final today = d(afternoon);
  final yesterday = d(afternoon.subtract(const Duration(days: 1)));

  group('which evenings get armed', () {
    test('every reminder lands at 8pm, one a day, in order', () {
      final plan = ReminderPlan.build(
        streak: 3,
        lastActiveDate: yesterday,
        now: afternoon,
      );
      expect(plan, isNotEmpty);
      for (final r in plan) {
        expect(r.at.hour, ReminderPlan.hour);
        expect(r.at.minute, ReminderPlan.minute);
      }
      final days = plan.map((r) => d(r.at)).toList();
      expect(days.toSet().length, days.length, reason: 'one a day at most');
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].at.isAfter(plan[i - 1].at), isTrue);
      }
    });

    test('ids are distinct, so a rebuild replaces rather than stacks', () {
      final plan = ReminderPlan.build(
        streak: 3,
        lastActiveDate: yesterday,
        now: afternoon,
      );
      final ids = plan.map((r) => r.id).toSet();
      expect(ids.length, plan.length);
      expect(ids.every((id) => id >= ReminderPlan.firstId), isTrue);
    });

    test('practised today, so tonight is skipped and later evenings are not', () {
      final plan = ReminderPlan.build(
        streak: 3,
        lastActiveDate: today,
        now: afternoon,
      );
      expect(d(plan.first.at), isNot(today));
      expect(plan.length, greaterThan(1),
          reason: 'the plan assumes they may not come back tomorrow');
    });

    test('past 8pm, tonight has gone and the plan starts tomorrow', () {
      final late = DateTime(2026, 11, 3, 23, 30);
      final plan = ReminderPlan.build(
        streak: 3,
        lastActiveDate: yesterday,
        now: late,
      );
      expect(plan.every((r) => r.at.isAfter(late)), isTrue);
      expect(d(plan.first.at), d(late.add(const Duration(days: 1))));
    });

    test('it gives up rather than nagging forever', () {
      // Three weeks of silence. Someone this far gone is not won back by a
      // fifteenth notification, and still sending them is how an app gets
      // uninstalled.
      final plan = ReminderPlan.build(
        streak: 0,
        lastActiveDate: d(afternoon.subtract(const Duration(days: 21))),
        now: afternoon,
      );
      expect(plan, isEmpty);
    });

    test('never arms more than the horizon', () {
      final plan = ReminderPlan.build(
        streak: 5,
        lastActiveDate: today,
        now: afternoon,
      );
      expect(plan.length, lessThanOrEqualTo(ReminderPlan.horizonDays));
    });
  });

  group('who gets spoken to — the change from the old policy', () {
    test('a one-day streak is reminded, where before it was silent', () {
      final plan = ReminderPlan.build(
        streak: 1,
        lastActiveDate: yesterday,
        now: afternoon,
      );
      expect(plan, isNotEmpty);
      expect(plan.first.kind, ReminderKind.streak);
    });

    test('a student who has never practised is nudged, not ignored', () {
      final plan = ReminderPlan.build(
        streak: 0,
        lastActiveDate: '',
        now: afternoon,
      );
      expect(plan, isNotEmpty);
    });

    test('a one-day streak is never asked to protect "1 day"', () {
      final plan = ReminderPlan.build(
        streak: 1,
        lastActiveDate: yesterday,
        now: afternoon,
      );
      expect(plan.first.body, isNot(contains('1 din ki streak')));
      expect(plan.first.title, isNot(contains('1 din')));
    });
  });

  group('what it says, and when', () {
    test('a broken streak is never claimed to be alive', () {
      // Four days since the last practice. Saying a streak is about to break
      // would be a lie, so this has to be comeback copy.
      final plan = ReminderPlan.build(
        streak: 6,
        lastActiveDate: d(afternoon.subtract(const Duration(days: 4))),
        now: afternoon,
      );
      expect(plan.first.kind, ReminderKind.comeback);
      expect(plan.every((r) => r.kind != ReminderKind.streak), isTrue);
    });

    test('the tone escalates the longer the silence runs', () {
      String bodyAfter(int daysIdle) => ReminderPlan.build(
            streak: 0,
            lastActiveDate: d(afternoon.subtract(Duration(days: daysIdle))),
            now: afternoon,
          ).first.body;

      // Teasing at four days, softer at a week — the cheek stops before it
      // would start to read as unkind.
      expect(bodyAfter(4), contains('Reels'));
      expect(bodyAfter(8), isNot(contains('Reels')));
    });

    test('an exam inside a fortnight takes over the copy', () {
      final plan = ReminderPlan.build(
        streak: 4,
        lastActiveDate: yesterday,
        now: afternoon,
        examId: 'NUST-NET',
        examDaysLeft: 9,
      );
      expect(plan.first.kind, ReminderKind.exam);
      expect(plan.first.title + plan.first.body, contains('NUST-NET'));
    });

    test('an exam far out does not hijack the copy', () {
      final plan = ReminderPlan.build(
        streak: 4,
        lastActiveDate: yesterday,
        now: afternoon,
        examId: 'MDCAT',
        examDaysLeft: 60,
      );
      expect(plan.first.kind, ReminderKind.streak);
    });

    test('the countdown ticks down across the ladder', () {
      final plan = ReminderPlan.build(
        streak: 0,
        lastActiveDate: yesterday,
        now: afternoon,
        examId: 'NUST-NET',
        examDaysLeft: 5,
      );
      expect(plan[0].title, contains('5 din'));
      expect(plan[4].title, contains('kal'));
      expect(plan[5].title, contains('aaj'));
    });

    test('Ustu stops joking as the paper gets close', () {
      final plan = ReminderPlan.build(
        streak: 0,
        lastActiveDate: yesterday,
        now: afternoon,
        examId: 'NUST-NET',
        examDaysLeft: 1,
      );
      // The night before a paper is not the night to tease someone about
      // reels, and telling them to sleep is better advice than telling them
      // to practise.
      expect(plan.first.kind, ReminderKind.exam);
      expect(plan.first.body, contains('aaram'));
    });

    test('once the exam has passed the copy moves on', () {
      final plan = ReminderPlan.build(
        streak: 0,
        lastActiveDate: yesterday,
        now: afternoon,
        examId: 'NUST-NET',
        examDaysLeft: -2,
      );
      expect(plan.every((r) => r.kind != ReminderKind.exam), isTrue);
    });
  });

  group('the copy itself', () {
    test('every line in every bank is a real sentence', () {
      // Walks the whole space: each kind, at several silences and countdowns,
      // so no bank is left unvisited and no placeholder survives.
      for (var idle = 0; idle <= 14; idle++) {
        for (final streak in [0, 1, 2, 7]) {
          for (final exam in [null, 0, 1, 3, 9]) {
            final plan = ReminderPlan.build(
              streak: streak,
              lastActiveDate: d(afternoon.subtract(Duration(days: idle))),
              now: afternoon,
              examId: exam == null ? null : 'NUST-NET',
              examDaysLeft: exam,
            );
            for (final r in plan) {
              expect(r.title.trim(), isNotEmpty);
              expect(r.body.trim(), isNotEmpty);
              expect(r.title, isNot(contains('{n}')),
                  reason: 'unsubstituted placeholder in ${r.kind}');
              expect(r.body, isNot(contains('{n}')),
                  reason: 'unsubstituted placeholder in ${r.kind}');
              expect(r.title.length, lessThan(65),
                  reason: 'Android truncates a long title');
            }
          }
        }
      }
    });

    test('consecutive evenings do not repeat the same sentence', () {
      final plan = ReminderPlan.build(
        streak: 0,
        lastActiveDate: d(afternoon.subtract(const Duration(days: 4))),
        now: afternoon,
      );
      for (var i = 1; i < plan.length; i++) {
        if (plan[i].kind == plan[i - 1].kind) {
          expect(plan[i].body, isNot(plan[i - 1].body),
              reason: 'the same kind on consecutive evenings must differ');
        }
      }
    });

    test('a multi-day streak still names the number it is defending', () {
      final plan = ReminderPlan.build(
        streak: 9,
        lastActiveDate: yesterday,
        now: afternoon,
      );
      expect(plan.first.title + plan.first.body, contains('9'));
    });
  });

  group('the cancelling behaviour the whole design rests on', () {
    test('practising flips tonight off without losing the rest', () {
      final before = ReminderPlan.build(
        streak: 3,
        lastActiveDate: yesterday,
        now: afternoon,
      );
      final after = ReminderPlan.build(
        streak: 4,
        lastActiveDate: today,
        now: afternoon,
      );
      expect(d(before.first.at), today);
      expect(d(after.first.at), isNot(today));
      expect(after, isNotEmpty);
    });
  });
}
