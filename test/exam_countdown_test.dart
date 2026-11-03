import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/core/exam/exam_countdown.dart';
import 'package:ustaad/providers/exam_date_provider.dart';

// The whole point of this feature is one number on the home screen, so the
// number is what gets tested: in particular the two ways a naive day count
// goes wrong — flooring toward zero, and daylight saving making a calendar
// day 23 or 25 hours long.

void main() {
  group('daysUntil counts calendar days, not 24-hour blocks', () {
    test('an exam later today is 0, not -1', () {
      final now = DateTime(2026, 11, 1, 23, 30);
      final exam = DateTime(2026, 11, 1, 9, 0);
      expect(ExamCountdown.daysUntil(exam, now), 0);
    });

    test('tomorrow morning from late tonight is 1, not 0', () {
      // Nine hours apart. A Duration-based count would floor this to 0 and
      // the card would say "Today" on the evening before the paper.
      final now = DateTime(2026, 11, 1, 23, 0);
      final exam = DateTime(2026, 11, 2, 8, 0);
      expect(ExamCountdown.daysUntil(exam, now), 1);
    });

    test('the time of day on either side never changes the count', () {
      final exam = DateTime(2026, 11, 13);
      for (final hour in [0, 1, 6, 12, 18, 23]) {
        expect(
          ExamCountdown.daysUntil(exam, DateTime(2026, 11, 1, hour, 59)),
          12,
          reason: 'at $hour:59 the answer should still be 12',
        );
      }
    });

    test('a date months out counts across month and year ends', () {
      expect(
        ExamCountdown.daysUntil(DateTime(2027, 1, 1), DateTime(2026, 12, 25)),
        7,
      );
      expect(
        ExamCountdown.daysUntil(DateTime(2026, 3, 1), DateTime(2026, 2, 27)),
        2,
      );
    });

    test('a leap day is counted', () {
      expect(
        ExamCountdown.daysUntil(DateTime(2028, 3, 1), DateTime(2028, 2, 28)),
        2, // 29 Feb exists in 2028
      );
    });

    test('a past exam is negative', () {
      expect(
        ExamCountdown.daysUntil(DateTime(2026, 10, 1), DateTime(2026, 11, 1)),
        -31,
      );
    });
  });

  group('nearest', () {
    final now = DateTime(2026, 11, 1, 14, 0);

    test('picks the soonest of several', () {
      final target = ExamCountdown.nearest(
        dates: {
          'MDCAT': DateTime(2026, 12, 20),
          'NUMS': DateTime(2026, 11, 13),
        },
        selectedTests: const ['MDCAT', 'NUMS'],
        now: now,
      );
      expect(target!.examId, 'NUMS');
      expect(target.daysLeft, 12);
    });

    test('ignores a date for an exam no longer selected', () {
      // A student who switched from engineering to medical should not keep
      // counting down to a NET paper they are not sitting.
      final target = ExamCountdown.nearest(
        dates: {
          'NUST-NET': DateTime(2026, 11, 5),
          'MDCAT': DateTime(2026, 12, 20),
        },
        selectedTests: const ['MDCAT'],
        now: now,
      );
      expect(target!.examId, 'MDCAT');
    });

    test('skips exams already past and takes the next one', () {
      final target = ExamCountdown.nearest(
        dates: {
          'NAT-NTS': DateTime(2026, 10, 10),
          'FAST-NU': DateTime(2026, 11, 20),
        },
        selectedTests: const ['NAT-NTS', 'FAST-NU'],
        now: now,
      );
      expect(target!.examId, 'FAST-NU');
      expect(target.daysLeft, 19);
    });

    test('an exam earlier today still counts as today', () {
      final target = ExamCountdown.nearest(
        dates: {'NUST-NET': DateTime(2026, 11, 1, 9, 0)},
        selectedTests: const ['NUST-NET'],
        now: now,
      );
      expect(target!.daysLeft, 0);
    });

    test('null when every date is in the past', () {
      expect(
        ExamCountdown.nearest(
          dates: {'MDCAT': DateTime(2026, 1, 1)},
          selectedTests: const ['MDCAT'],
          now: now,
        ),
        isNull,
      );
    });

    test('null when no dates are set, and when nothing is selected', () {
      expect(
        ExamCountdown.nearest(
          dates: const {},
          selectedTests: const ['MDCAT'],
          now: now,
        ),
        isNull,
      );
      expect(
        ExamCountdown.nearest(
          dates: {'MDCAT': DateTime(2026, 12, 1)},
          selectedTests: const [],
          now: now,
        ),
        isNull,
      );
    });

    test('the returned date is local midnight, whatever was stored', () {
      final target = ExamCountdown.nearest(
        dates: {'MDCAT': DateTime(2026, 12, 1, 17, 45)},
        selectedTests: const ['MDCAT'],
        now: now,
      );
      expect(target!.date, DateTime(2026, 12, 1));
    });
  });

  group('urgency thresholds', () {
    test('no date is calm, not urgent', () {
      expect(ExamCountdown.urgencyFor(null), ExamUrgency.calm);
    });

    test('the boundaries fall where the constants say', () {
      expect(ExamCountdown.urgencyFor(0), ExamUrgency.imminent);
      expect(ExamCountdown.urgencyFor(3), ExamUrgency.imminent);
      expect(ExamCountdown.urgencyFor(4), ExamUrgency.near);
      expect(ExamCountdown.urgencyFor(14), ExamUrgency.near);
      expect(ExamCountdown.urgencyFor(15), ExamUrgency.calm);
      expect(ExamCountdown.urgencyFor(120), ExamUrgency.calm);
    });

    test('every day from 0 to 30 lands in exactly one band', () {
      for (var d = 0; d <= 30; d++) {
        final u = ExamCountdown.urgencyFor(d);
        expect(u, isNotNull);
        if (d <= 3) {
          expect(u, ExamUrgency.imminent, reason: '$d days');
        } else if (d <= 14) {
          expect(u, ExamUrgency.near, reason: '$d days');
        } else {
          expect(u, ExamUrgency.calm, reason: '$d days');
        }
      }
    });
  });

  group('wording', () {
    test('never says "1 days"', () {
      expect(ExamCountdown.phrase(1), 'Tomorrow');
      expect(ExamCountdown.sentence(examId: 'MDCAT', daysLeft: 1),
          'MDCAT is tomorrow');
    });

    test('today reads as today, not "0 days"', () {
      expect(ExamCountdown.phrase(0), 'Today');
      expect(ExamCountdown.sentence(examId: 'NUST-NET', daysLeft: 0),
          'NUST-NET is today');
    });

    test('the plural case names the exam and the number', () {
      expect(ExamCountdown.phrase(12), '12 days left');
      expect(ExamCountdown.sentence(examId: 'NUST-NET', daysLeft: 12),
          'NUST-NET is in 12 days');
    });

    test('a negative count degrades to today rather than printing a minus', () {
      expect(ExamCountdown.phrase(-3), 'Today');
    });
  });

  group('pendingDebrief decides when to ask how it went', () {
    final now = DateTime(2026, 11, 10, 9, 0);

    test('asks the day after, not on the day itself', () {
      // The paper may be in the afternoon. Asking how it went while they are
      // still sitting it would be worse than not asking at all.
      expect(
        ExamCountdown.pendingDebrief(
          dates: {'MDCAT': DateTime(2026, 11, 10)},
          debriefed: const {},
          selectedTests: const ['MDCAT'],
          now: now,
        ),
        isNull,
      );

      final next = ExamCountdown.pendingDebrief(
        dates: {'MDCAT': DateTime(2026, 11, 9)},
        debriefed: const {},
        selectedTests: const ['MDCAT'],
        now: now,
      );
      expect(next!.examId, 'MDCAT');
      expect(next.daysAgo, 1);
    });

    test('does not ask about a paper still ahead', () {
      expect(
        ExamCountdown.pendingDebrief(
          dates: {'MDCAT': DateTime(2026, 11, 20)},
          debriefed: const {},
          selectedTests: const ['MDCAT'],
          now: now,
        ),
        isNull,
      );
    });

    test('stops asking once the window has passed', () {
      ExamDebriefPrompt? at(int daysAgo) => ExamCountdown.pendingDebrief(
            dates: {'MDCAT': now.subtract(Duration(days: daysAgo))},
            debriefed: const {},
            selectedTests: const ['MDCAT'],
            now: now,
          );
      expect(at(14), isNotNull, reason: 'last day of the window');
      expect(at(15), isNull, reason: 'one day past it');
      expect(at(40), isNull);
    });

    test('never asks twice about the same sitting', () {
      final date = DateTime(2026, 11, 8);
      final key = ExamCountdown.debriefKey('MDCAT', date);
      expect(
        ExamCountdown.pendingDebrief(
          dates: {'MDCAT': date},
          debriefed: {key},
          selectedTests: const ['MDCAT'],
          now: now,
        ),
        isNull,
      );
    });

    test('a resit on a different date is asked about again', () {
      // The key carries the date, so last year's sitting does not silence
      // this year's.
      final old = ExamCountdown.debriefKey('MDCAT', DateTime(2025, 11, 8));
      final prompt = ExamCountdown.pendingDebrief(
        dates: {'MDCAT': DateTime(2026, 11, 8)},
        debriefed: {old},
        selectedTests: const ['MDCAT'],
        now: now,
      );
      expect(prompt!.examId, 'MDCAT');
    });

    test('picks the most recent when two were sat close together', () {
      final prompt = ExamCountdown.pendingDebrief(
        dates: {
          'NUMS': DateTime(2026, 11, 2),
          'MDCAT': DateTime(2026, 11, 8),
        },
        debriefed: const {},
        selectedTests: const ['NUMS', 'MDCAT'],
        now: now,
      );
      expect(prompt!.examId, 'MDCAT', reason: 'the one on their mind');
      expect(prompt.daysAgo, 2);
    });

    test('falls through to the older one once the recent is answered', () {
      final answered =
          ExamCountdown.debriefKey('MDCAT', DateTime(2026, 11, 8));
      final prompt = ExamCountdown.pendingDebrief(
        dates: {
          'NUMS': DateTime(2026, 11, 2),
          'MDCAT': DateTime(2026, 11, 8),
        },
        debriefed: {answered},
        selectedTests: const ['NUMS', 'MDCAT'],
        now: now,
      );
      expect(prompt!.examId, 'NUMS');
    });

    test('ignores an exam the student no longer has selected', () {
      expect(
        ExamCountdown.pendingDebrief(
          dates: {'NUST-NET': DateTime(2026, 11, 8)},
          debriefed: const {},
          selectedTests: const ['MDCAT'],
          now: now,
        ),
        isNull,
      );
    });

    test('debriefKey is stable and ignores the time of day', () {
      expect(
        ExamCountdown.debriefKey('NUST-NET', DateTime(2026, 11, 8, 23, 59)),
        'NUST-NET_2026-11-08',
      );
      expect(
        ExamCountdown.debriefKey('NUST-NET', DateTime(2026, 1, 5)),
        'NUST-NET_2026-01-05',
        reason: 'single-digit months and days are padded',
      );
    });
  });

  group('every mood has something to say', () {
    test('no mood label is empty, and none of them reads as a failure', () {
      for (final mood in ExamMood.values) {
        expect(mood.label.trim(), isNotEmpty);
      }
      expect(ExamMood.values.length, 3);
    });
  });

  group('parseExamDates survives whatever is on the document', () {
    test('a missing or malformed field gives an empty map', () {
      expect(parseExamDates(null), isEmpty);
      expect(parseExamDates({}), isEmpty);
      expect(parseExamDates({'examDates': 'not a map'}), isEmpty);
      expect(parseExamDates({'examDates': 42}), isEmpty);
    });

    test('ISO strings and epoch millis are both accepted', () {
      final parsed = parseExamDates({
        'examDates': {
          'MDCAT': '2026-12-01T00:00:00.000',
          'NUMS': DateTime(2026, 11, 13, 8, 30).millisecondsSinceEpoch,
        },
      });
      expect(parsed['MDCAT'], DateTime(2026, 12, 1));
      expect(parsed['NUMS'], DateTime(2026, 11, 13));
    });

    test('unusable entries are dropped, usable ones kept', () {
      final parsed = parseExamDates({
        'examDates': {
          'MDCAT': '2026-12-01',
          'NUMS': 'sometime next year',
          '': '2026-12-01',
        },
      });
      expect(parsed.keys, ['MDCAT']);
    });

    test('the time of day is stripped so same-day dates compare equal', () {
      final parsed = parseExamDates({
        'examDates': {'MDCAT': DateTime(2026, 12, 1, 23, 59, 59)},
      });
      expect(parsed['MDCAT'], DateTime(2026, 12, 1));
    });
  });

  group('parseDebriefed', () {
    test('a missing or malformed field gives an empty set', () {
      expect(parseDebriefed(null), isEmpty);
      expect(parseDebriefed({}), isEmpty);
      expect(parseDebriefed({'examDebriefs': 'not a map'}), isEmpty);
    });

    test('keys come back whatever the values are', () {
      // Only the presence of the key matters. The value is a timestamp today,
      // but a document written by an older build may hold anything.
      final parsed = parseDebriefed({
        'examDebriefs': {
          'MDCAT_2026-11-08': DateTime(2026, 11, 9),
          'NUMS_2026-11-02': true,
        },
      });
      expect(parsed, {'MDCAT_2026-11-08', 'NUMS_2026-11-02'});
    });

    test('empty keys are dropped', () {
      expect(parseDebriefed({'examDebriefs': {'': 1}}), isEmpty);
    });
  });
}
