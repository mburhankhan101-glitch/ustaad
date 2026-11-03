// lib/core/notifications/reminder_plan.dart
//
// Decides what Ustu says, and on which evenings.
//
// The old scheduler armed one notification, for tonight, and only for a
// student with a two-day streak. That had two problems. It reached five users
// out of seventy-four, because a two-day streak means they have already come
// back — the reminder could never cause the day-one-to-day-two return, which
// is exactly where retention falls off a cliff. And it scheduled nothing
// beyond tonight, so a student who stopped opening the app stopped hearing
// from Ustu at the precise moment that mattered.
//
// So this plans a ladder instead: the next ten evenings, each with copy
// chosen for what that evening will look like if the student does nothing
// between now and then. Because they are scheduled in advance, a student who
// never reopens the app still gets nudged for ten days. Any app open
// reschedules the whole ladder from scratch.
//
// All pure and static, so the escalation and the copy can be tested without
// a device.

import 'package:flutter/foundation.dart';

enum ReminderKind {
  /// There is a streak to protect tonight.
  streak,

  /// A paper is close enough that the countdown is the thing to say.
  exam,

  /// Practised once or twice and then stopped. Most of the base.
  comeback,

  /// Nothing to protect yet, nothing to count down to. The playful nudge.
  nudge,
}

@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.kind,
    required this.title,
    required this.body,
  });

  /// Distinct per evening, so scheduling replaces that evening rather than
  /// stacking, and the whole ladder can be cancelled by range.
  final int id;

  final DateTime at;
  final ReminderKind kind;
  final String title;
  final String body;

  @override
  String toString() => 'PlannedReminder(${at.toIso8601String()}, $kind)';
}

class ReminderPlan {
  ReminderPlan._();

  /// Evening, not morning. Students here practise after Maghrib and after
  /// dinner; a 9am reminder lands in a school corridor and gets swiped.
  static const int hour = 20;
  static const int minute = 0;

  /// How many evenings to arm in advance. Ten is enough to carry a student
  /// through a lapse without reopening the app, and comfortably inside iOS's
  /// cap of 64 pending notifications.
  static const int horizonDays = 10;

  /// Ids 1100..1109. The old single-reminder id was 1001 and is cancelled
  /// separately, so an upgrading device does not keep a stale one pending.
  static const int firstId = 1100;
  static const int legacyId = 1001;

  /// Past this many days of silence Ustu stops. Someone who has not opened
  /// the app in a fortnight is not going to be won back by a fifteenth
  /// notification, and still sending them is how an app gets uninstalled.
  static const int giveUpAfterDays = 14;

  /// Builds the ladder.
  ///
  /// [lastActiveDate] is the `yyyy-MM-dd` string the progress document already
  /// stores. [examDaysLeft] and [examId] come from the countdown, and are
  /// null when no date is set.
  static List<PlannedReminder> build({
    required int streak,
    required String lastActiveDate,
    required DateTime now,
    String? examId,
    int? examDaysLeft,
    int horizon = horizonDays,
  }) {
    final out = <PlannedReminder>[];
    final today = _dateOnly(now);
    final lastActive = _parseDate(lastActiveDate);

    for (var offset = 0; offset < horizon; offset++) {
      final day = today.add(Duration(days: offset));
      final slot = DateTime(day.year, day.month, day.day, hour, minute);

      // Tonight's slot has already gone by.
      if (!slot.isAfter(now)) continue;

      // Practised today, so tonight needs nothing. Later evenings still do,
      // because this plan assumes they do not come back.
      if (offset == 0 && lastActive != null && lastActive == today) continue;

      final daysIdle = lastActive == null
          ? offset + 1
          : day.difference(lastActive).inDays;

      if (daysIdle > giveUpAfterDays) break;

      // How many days until the exam, as it will be on that evening.
      final examDays = examDaysLeft == null ? null : examDaysLeft - offset;

      final line = _lineFor(
        streak: streak,
        daysIdle: daysIdle,
        examId: examId,
        examDays: examDays,
        rotation: offset,
      );

      out.add(
        PlannedReminder(
          id: firstId + offset,
          at: slot,
          kind: line.kind,
          title: line.title,
          body: line.body,
        ),
      );
    }

    return out;
  }

  /// Picks the voice for one evening.
  ///
  /// Order matters. An exam in three days outranks everything: a student
  /// being teased about reels the night before their paper would be the wrong
  /// thing to say. A live streak comes next, because it is concrete and
  /// theirs. Everything else is the nudge, getting cheekier as the silence
  /// gets longer.
  static _Line _lineFor({
    required int streak,
    required int daysIdle,
    required String? examId,
    required int? examDays,
    required int rotation,
  }) {
    if (examId != null && examDays != null && examDays >= 0 && examDays <= 14) {
      return _exam(examId, examDays, rotation);
    }
    if (streak >= 1 && daysIdle <= 1) {
      return _streak(streak, rotation);
    }
    if (daysIdle >= 2) {
      return _comeback(daysIdle, rotation);
    }
    return _pick(_nudges, rotation, ReminderKind.nudge);
  }

  // ── Copy ──────────────────────────────────────────────────────────────────
  //
  // Ustu's voice throughout: Roman Urdu, more friend than invigilator, and
  // teasing rather than scolding. These go to teenagers inside exam season,
  // so the line between cheeky and unkind is one worth holding. Each bank is
  // rotated by the day offset so a student who ignores Ustu for a week does
  // not get the same sentence twice.

  static final _streakLines = <List<String>>[
    ['Streak tootne wali hai! 🔥', 'Ustu keh raha hai: 5 minute nikalo, {n} din ka kaam bach jayega.'],
    ['{n} din ki mehnat 😬', 'Aaj kuch nahi kiya. Ek chhota quiz, aur streak safe.'],
    ['Ustu intezaar kar raha hai 🦉', '{n} din se streak chal rahi hai. Aaj bhi chalni chahiye na?'],
    ['Abhi waqt hai ⏰', 'Soney se pehle 5 sawal. {n} din ki streak bachane ke liye bas itna.'],
    ['Yaad dilane aaya hoon 📚', 'Tumhari {n} din ki streak aaj khatam ho jayegi. Mujhe rokna hai?'],
  ];

  /// A one-day streak has no number worth defending, so these never mention
  /// it. "Your 1 day streak" is a thin thing to ask someone to protect.
  static final _firstStreakLines = <List<String>>[
    ['Kal shuru kiya tha 🌱', 'Aaj bhi karlo, phir yeh aadat ban jayegi. Sirf 5 sawal.'],
    ['Ek din ho gaya 🦉', 'Kal wala quiz acha tha. Aaj dobara? Ustu ready hai.'],
    ['Do din lagatar? 🔥', 'Aaj kar lo toh streak shuru ho jayegi. Bas ek quiz ki baat hai.'],
  ];

  static final _comebackSoon = <List<String>>[
    ['Kahan ghayab ho? 👀', 'Do din se shakal nahi dikhai. Sawal yahin hain, intezaar mein.'],
    ['Ustu bore ho raha hai 🦉', 'Aao na, 5 sawal karte hain. Zyada waqt nahi lagega.'],
    ['Padhai ko bhool gaye? 😏', 'Koi baat nahi, main yaad dila deta hoon. Chalo shuru karte hain.'],
  ];

  static final _comebackCheeky = <List<String>>[
    ['Arey sunno 😤', 'Reels se fursat milgayi ho toh thori tyaari karlein?'],
    ['Phone toh chal raha hai 🙃', 'Ustaad bhi khul sakta hai. Paanch sawal, zyada nahi maangta.'],
    ['Teacher mode on 😤', 'Chaar din ho gaye. Ab bahana kya hai? Chalo, ek quiz.'],
    ['Scroll karna band 📵', 'Pehle ek quiz, phir jitna marzi scroll karna. Deal?'],
  ];

  static final _comebackMiss = <List<String>>[
    ['Ustu udaas hai 🥺', 'Hafta ho gaya. Test tumhara hai, tyaari bhi tumhe hi karni hai.'],
    ['Sab theek hai? 🦉', 'Kaafi din se nahi aaye. Aaj sirf 5 sawal, phir chhutti.'],
    ['Wapas aa jao 📚', 'Jitna chhoda hai, utna hi mushkil lagega. Aaj se dobara shuru?'],
  ];

  static final _nudges = <List<String>>[
    ['Thora sa padh lein? 🦉', 'Paanch sawal. Ustu wada karta hai, dukh nahi hoga.'],
    ['Khali baithe ho? 😏', 'Ek chhota quiz ho jaye? Das minute se bhi kam.'],
    ['Aaj ka hisab 📚', 'Abhi tak ek sawal nahi kiya. Shuru karein?'],
  ];

  static _Line _streak(int streak, int rotation) {
    final bank = streak <= 1 ? _firstStreakLines : _streakLines;
    final line = bank[rotation % bank.length];
    return _Line(
      ReminderKind.streak,
      line[0].replaceAll('{n}', '$streak'),
      line[1].replaceAll('{n}', '$streak'),
    );
  }

  static _Line _comeback(int daysIdle, int rotation) {
    final bank = daysIdle >= 7
        ? _comebackMiss
        : daysIdle >= 4
            ? _comebackCheeky
            : _comebackSoon;
    return _pick(bank, rotation, ReminderKind.comeback);
  }

  /// The exam lines are the one place Ustu stops joking. A student three days
  /// out does not need a reel joke, they need to be told plainly.
  static _Line _exam(String examId, int days, int rotation) {
    if (days == 0) {
      return _Line(
        ReminderKind.exam,
        '$examId aaj hai 💪',
        'Aaj ka din tumhara hai. Ustu ki dua tumhare saath hai.',
      );
    }
    if (days == 1) {
      return _Line(
        ReminderKind.exam,
        '$examId kal hai ⏰',
        'Aaj halka sa revision, phir aaram. Raat ko jag kar nahi padhna.',
      );
    }
    if (days <= 3) {
      return _Line(
        ReminderKind.exam,
        '$days din reh gaye 😤',
        '$examId bilkul sar pe hai. Aaj ek past paper ho jaye?',
      );
    }
    final bank = <List<String>>[
      ['$days din baaki hain ⏰', '$examId aa raha hai. Roz thora karoge toh aakhri hafte aaram rahega.'],
      ['Counting down 📅', '$examId mein $days din. Aaj ke 5 sawal kal ke kaam aayenge.'],
      ['$examId ki tyaari 📚', '$days din. Abhi shuru karo toh bohot waqt hai.'],
    ];
    final line = bank[rotation % bank.length];
    return _Line(ReminderKind.exam, line[0], line[1]);
  }

  static _Line _pick(List<List<String>> bank, int rotation, ReminderKind kind) {
    final line = bank[rotation % bank.length];
    return _Line(kind, line[0], line[1]);
  }

  // ── Dates ─────────────────────────────────────────────────────────────────

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Returns null for an empty or unparseable string, which is what a student
  /// who has never practised has on their document.
  static DateTime? _parseDate(String yyyyMmDd) {
    final parts = yyyyMmDd.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}

@immutable
class _Line {
  const _Line(this.kind, this.title, this.body);
  final ReminderKind kind;
  final String title;
  final String body;
}
