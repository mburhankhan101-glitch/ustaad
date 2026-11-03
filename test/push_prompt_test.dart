// When Ustu may ask about reminders.
//
// The thing being protected is a one-shot: on Android 13+ the system dialog
// disappears for good after two refusals, and the only way back is Settings,
// which nobody visits. Every rule here exists so that dialog is only ever
// shown to a student who has already said yes to a softer question — so a bug
// in this file does not look like a bug, it looks like a student who can
// never be reminded again.

import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/core/notifications/push_prompt.dart';

PushPromptState _state({
  bool granted = false,
  int asks = 0,
  DateTime? last,
  int solved = 10,
  bool hardSpent = false,
}) =>
    PushPromptState(
      alreadyGranted: granted,
      softAsks: asks,
      lastSoftAsk: last,
      questionsSolved: solved,
      hardAskSpent: hardSpent,
    );

void main() {
  final now = DateTime(2026, 11, 3, 19, 0);

  group('when Ustu stays quiet', () {
    test('permission is already granted', () {
      expect(PushPrompt.shouldSoftAsk(_state(granted: true), now), isFalse);
    });

    test('the system dialog has already been spent', () {
      // Nothing left to offer: asking again cannot produce a prompt, so the
      // card would be a button that does nothing.
      expect(PushPrompt.shouldSoftAsk(_state(hardSpent: true), now), isFalse);
    });

    test('Ustu has not been useful yet', () {
      // Asking for permission before the student has seen what the app does
      // is how the old first-launch prompt lost everybody.
      expect(PushPrompt.shouldSoftAsk(_state(solved: 0), now), isFalse);
      expect(PushPrompt.shouldSoftAsk(_state(solved: 2), now), isFalse);
      expect(PushPrompt.shouldSoftAsk(_state(solved: 3), now), isTrue);
    });

    test('it has been asked three times already', () {
      expect(PushPrompt.shouldSoftAsk(_state(asks: 3), now), isFalse);
      expect(PushPrompt.shouldSoftAsk(_state(asks: 9), now), isFalse);
    });

    test('it was asked too recently', () {
      for (var days = 0; days < PushPrompt.daysBetweenAsks; days++) {
        expect(
          PushPrompt.shouldSoftAsk(
            _state(asks: 1, last: now.subtract(Duration(days: days))),
            now,
          ),
          isFalse,
          reason: 'only $days days since the last ask',
        );
      }
    });
  });

  group('when Ustu may ask', () {
    test('never asked, and has done some work', () {
      expect(PushPrompt.shouldSoftAsk(_state(), now), isTrue);
    });

    test('asked once, five days ago', () {
      final plan = _state(
        asks: 1,
        last: now.subtract(const Duration(days: PushPrompt.daysBetweenAsks)),
      );
      expect(PushPrompt.shouldSoftAsk(plan, now), isTrue);
    });

    test('the gap is counted in calendar days, not hours', () {
      // Asked late on day one, opening the app early on day six: five
      // calendar days have passed even though it is not yet 120 hours.
      final lastAsk = DateTime(2026, 10, 29, 23, 30);
      final opening = DateTime(2026, 11, 3, 8, 15);
      expect(
        PushPrompt.shouldSoftAsk(_state(asks: 1, last: lastAsk), opening),
        isTrue,
      );
    });
  });

  group('the copy', () {
    test('each attempt has a title, a body and a button label', () {
      for (var attempt = 0; attempt < 5; attempt++) {
        final copy = PushPrompt.copyFor(attempt);
        expect(copy.length, 3);
        for (final part in copy) {
          expect(part.trim(), isNotEmpty);
        }
        expect(copy[0].length, lessThan(65));
      }
    });

    test('the three asks are worded differently', () {
      final first = PushPrompt.copyFor(0);
      final second = PushPrompt.copyFor(1);
      final third = PushPrompt.copyFor(2);
      expect(first[0], isNot(second[0]));
      expect(second[0], isNot(third[0]));
    });

    test('the last ask promises it is the last, and keeps that promise', () {
      // The copy says Ustu will not bring it up again, and maxSoftAsks is
      // what makes that true rather than a line.
      expect(PushPrompt.copyFor(2)[1], contains('dobara nahi'));
      expect(PushPrompt.maxSoftAsks, 3);
      expect(PushPrompt.shouldSoftAsk(_state(asks: 3), now), isFalse);
    });
  });
}
