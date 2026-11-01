// lib/core/exam/exam_countdown.dart
//
// How many days a student has left before their test, and how to say it.
//
// All of this is pure and static so it can be tested without a device, the
// same way ReminderService keeps its scheduling logic testable.
//
// The one genuinely easy thing to get wrong here is counting days. A test on
// the 12th is "tomorrow" from the evening of the 11th and "today" from one
// minute past midnight on the 12th, so the count has to be in calendar days,
// not 24-hour blocks. Subtracting two local DateTimes and reading `inDays`
// gets that wrong twice: it floors toward zero (an exam 20 hours away reads
// as 0 days), and across a daylight-saving boundary a calendar day is 23 or
// 25 hours long, so the division slips. Both are avoided by throwing away
// the time of day and comparing UTC midnights, which are always exactly 24
// hours apart. Pakistan has no DST today, but a student travelling to sit a
// paper abroad is exactly the person who most wants this number right.

import 'package:flutter/foundation.dart';

/// What the countdown is pointing at: one exam, on one day.
@immutable
class ExamTarget {
  const ExamTarget({
    required this.examId,
    required this.date,
    required this.daysLeft,
  });

  /// The exam id as stored in `selectedTests`, e.g. 'NUST-NET'.
  final String examId;

  /// Local midnight on the day of the paper.
  final DateTime date;

  /// Calendar days from today. 0 is today, 1 tomorrow. Never negative: a
  /// past exam is not a target at all, so [ExamCountdown.nearest] drops it.
  final int daysLeft;

  @override
  bool operator ==(Object other) =>
      other is ExamTarget &&
      other.examId == examId &&
      other.date == date &&
      other.daysLeft == daysLeft;

  @override
  int get hashCode => Object.hash(examId, date, daysLeft);

  @override
  String toString() => 'ExamTarget($examId, $daysLeft days)';
}

/// How loudly to say it. The home card and (later) the reminder copy both
/// read this, so the thresholds live in one place.
enum ExamUrgency {
  /// No date set, or far enough away that a countdown is just information.
  calm,

  /// Inside a fortnight. This is the window where a student's behaviour
  /// actually changes.
  near,

  /// Inside three days, or today. Said plainly, without panic.
  imminent,
}

class ExamCountdown {
  ExamCountdown._();

  /// Inside this many days, the countdown is worth drawing attention to.
  static const int nearDays = 14;

  /// Inside this many days, it is the most important thing on the screen.
  static const int imminentDays = 3;

  /// Calendar days from [now] to [examDate], ignoring the time of day on
  /// both. Negative once the exam is in the past.
  static int daysUntil(DateTime examDate, DateTime now) {
    final e = DateTime.utc(examDate.year, examDate.month, examDate.day);
    final n = DateTime.utc(now.year, now.month, now.day);
    return e.difference(n).inDays;
  }

  /// The soonest exam still ahead of the student, or null.
  ///
  /// [dates] maps exam id to the day of that paper. Only ids the student has
  /// actually selected are considered, so a date left behind by a change of
  /// plan cannot drive the countdown. An exam earlier today still counts as
  /// today — the paper may be in the afternoon, and a student who has already
  /// sat it is not going to be hurt by one more day of "today".
  static ExamTarget? nearest({
    required Map<String, DateTime> dates,
    required List<String> selectedTests,
    required DateTime now,
  }) {
    ExamTarget? best;
    for (final entry in dates.entries) {
      if (!selectedTests.contains(entry.key)) continue;
      final days = daysUntil(entry.value, now);
      if (days < 0) continue;
      if (best == null || days < best.daysLeft) {
        best = ExamTarget(
          examId: entry.key,
          date: DateTime(
            entry.value.year,
            entry.value.month,
            entry.value.day,
          ),
          daysLeft: days,
        );
      }
    }
    return best;
  }

  static ExamUrgency urgencyFor(int? daysLeft) {
    if (daysLeft == null) return ExamUrgency.calm;
    if (daysLeft <= imminentDays) return ExamUrgency.imminent;
    if (daysLeft <= nearDays) return ExamUrgency.near;
    return ExamUrgency.calm;
  }

  /// The countdown as a student would read it: 'Today', 'Tomorrow',
  /// '12 days left'. Singular is handled because "1 days" undoes the care
  /// taken everywhere else.
  static String phrase(int daysLeft) {
    if (daysLeft <= 0) return 'Today';
    if (daysLeft == 1) return 'Tomorrow';
    return '$daysLeft days left';
  }

  /// The full line for the home card, e.g. 'NUST-NET is in 12 days'.
  static String sentence({required String examId, required int daysLeft}) {
    if (daysLeft <= 0) return '$examId is today';
    if (daysLeft == 1) return '$examId is tomorrow';
    return '$examId is in $daysLeft days';
  }

  /// A date far enough out to be a plausible test date, used to bound the
  /// picker. Nobody is setting a reminder for a paper four years away, and a
  /// mis-typed year is a worse outcome than a narrow range.
  static DateTime lastSensibleDate(DateTime now) =>
      DateTime(now.year + 2, now.month, now.day);
}
