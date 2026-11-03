// lib/core/notifications/push_prompt.dart
//
// Decides when to ask a student whether Ustu may remind them.
//
// Why there are two asks and not one. On Android 13+ the system dialog is a
// one-shot: deny it twice and the permission is blocked for good, with no
// dialog shown on any later attempt and no way back except Settings, which
// nobody visits. So the system dialog is the scarce resource, and it should
// only ever be spent on a student who has already said yes to a softer
// question Ustu asked in its own voice.
//
// Why it moved. The hard ask used to fire from the result screen, which is
// only reachable by finishing a quiz — and 57% of quizzes are abandoned. That
// gated the entire notification pipeline behind the one thing that was most
// broken: 23 of 74 users had ever been asked at all. The soft ask lives on
// home instead, which everybody reaches.
//
// Pure and static so the rules can be tested without a device.

import 'package:flutter/foundation.dart';

@immutable
class PushPromptState {
  const PushPromptState({
    required this.alreadyGranted,
    required this.softAsks,
    required this.lastSoftAsk,
    required this.questionsSolved,
    required this.hardAskSpent,
  });

  /// Read from the OS, not from our own records. A student may have granted
  /// it from Settings, or revoked it there.
  final bool alreadyGranted;

  /// How many times the soft ask has been shown and declined.
  final int softAsks;

  /// When it was last shown, or null if never.
  final DateTime? lastSoftAsk;

  /// Lifetime questions answered. Ustu has to have been useful before it
  /// asks for anything.
  final int questionsSolved;

  /// Whether the system dialog has already been shown once. After this the
  /// soft ask has nothing left to offer, so it stops.
  final bool hardAskSpent;
}

class PushPrompt {
  PushPrompt._();

  /// Ustu asks for nothing until it has been worth something. Three questions
  /// is roughly the point where a student has seen what the app does.
  static const int minQuestionsSolved = 3;

  /// A "not now" is an answer, not a pause. Leave it a good while.
  static const int daysBetweenAsks = 5;

  /// Three softly-worded asks across a student's life, then Ustu stops
  /// bringing it up. Past that it is nagging about nagging.
  static const int maxSoftAsks = 3;

  /// Whether to show the in-app card that offers to turn reminders on.
  static bool shouldSoftAsk(PushPromptState s, DateTime now) {
    if (s.alreadyGranted) return false;
    if (s.hardAskSpent) return false;
    if (s.questionsSolved < minQuestionsSolved) return false;
    if (s.softAsks >= maxSoftAsks) return false;

    final last = s.lastSoftAsk;
    if (last != null) {
      final since = DateTime(now.year, now.month, now.day)
          .difference(DateTime(last.year, last.month, last.day))
          .inDays;
      if (since < daysBetweenAsks) return false;
    }
    return true;
  }

  /// What the card says, softening each time rather than escalating. A
  /// student who has said "not now" twice is not persuaded by a louder third
  /// ask, and the only honest move left is to make it smaller.
  static List<String> copyFor(int previousAsks) {
    switch (previousAsks) {
      case 0:
        return const [
          '8 baje yaad dila doon? 🦉',
          'Roz shaam ko ek chhota sa reminder. Streak bachane ke liye kaafi hai, '
              'aur jab tum khud padh lo toh main chup rehta hoon.',
          'Haan, yaad dilana',
        ];
      case 1:
        return const [
          'Ek baar phir pooch raha hoon 😅',
          'Sirf shaam ko ek reminder, din mein ek se zyada kabhi nahi. '
              'Kabhi bhi band kar sakte ho.',
          'Theek hai, on kardo',
        ];
      default:
        return const [
          'Aakhri baar 🙏',
          'Reminder on karlo toh streak tootna band ho jayegi. Iske baad main '
              'yeh dobara nahi poochhunga.',
          'Chalo, on kardo',
        ];
    }
  }
}
