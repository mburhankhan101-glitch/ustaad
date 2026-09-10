import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/models/explanation.dart';

// Every string below is either taken from the bank or shaped like what is in
// it. The two step-splitting cases in particular are real: both were rendering
// wrong before the sequence and sentence-boundary rules went in.
void main() {
  group('Explanation.parse', () {
    const real =
        'Concept: Complementary inverse trigonometric identities. '
        'Solution: 1. Use the identity Sec+Cosec = pi/2. 2. Isolate Sec. '
        '3. Sec = pi/2 - Cosec. '
        'Trick: Just like Sin/Cos, Sec/Cosec sum up to pi/2. '
        'Mistake: Choosing the identity involving Cos.';

    test('finds all four parts in order', () {
      final e = Explanation.parse(real);
      expect(
        e.parts.map((p) => p.label).toList(),
        ['Concept', 'Solution', 'Trick', 'Mistake'],
      );
    });

    test('strips the labels from the bodies', () {
      final e = Explanation.parse(real);
      expect(e.partFor('Concept')!.body,
          'Complementary inverse trigonometric identities.');
      expect(e.partFor('Mistake')!.body,
          'Choosing the identity involving Cos.');
    });

    test('core excludes Trick and Mistake', () {
      final e = Explanation.parse(real);
      expect(e.core.map((p) => p.label).toList(), ['Concept', 'Solution']);
    });

    test('empty input gives an empty explanation', () {
      expect(Explanation.parse(null).isEmpty, isTrue);
      expect(Explanation.parse('   ').isEmpty, isTrue);
    });

    test('unlabelled text survives as one part rather than vanishing', () {
      final e = Explanation.parse('Just some prose with no labels at all.');
      expect(e.parts, hasLength(1));
      expect(e.parts.first.label, isNull);
      expect(e.parts.first.body, 'Just some prose with no labels at all.');
    });

    test('a missing part does not shift the others', () {
      final e = Explanation.parse(
        'Concept: An idea. Mistake: A slip.',
      );
      expect(e.parts.map((p) => p.label).toList(), ['Concept', 'Mistake']);
      expect(e.partFor('Solution'), isNull);
    });
  });

  group('Explanation.splitSteps', () {
    test('splits a plain numbered run', () {
      expect(
        Explanation.splitSteps('1. Use identity. 2. Isolate. 3. Done.'),
        ['Use identity.', 'Isolate.', 'Done.'],
      );
    });

    test('does not break at a number inside a step', () {
      // Was splitting at the "0." and losing the end of step one.
      final steps = Explanation.splitSteps(
        "1. The additive inverse of a number a is -a, such that their sum is 0. "
        "2. Multiply (2 + root3) by -1. "
        "3. Result: -2 - root3.",
      );
      expect(steps, hasLength(3));
      expect(steps[0], endsWith('their sum is 0.'));
      expect(steps[1], 'Multiply (2 + root3) by -1.');
    });

    test('picks the right marker when a step ends in the next step number', () {
      // "…denominator by 4. 4. The two cancel…" — only the second 4 is a step.
      final steps = Explanation.splitSteps(
        '1. Coulomb force is F = kq1q2/r squared. '
        '2. Doubling both charges multiplies the numerator by 4. '
        '3. Doubling the distance multiplies the denominator by 4. '
        '4. The two cancel, so F is unchanged.',
      );
      expect(steps, hasLength(4));
      expect(steps[2], endsWith('the denominator by 4.'));
      expect(steps[3], 'The two cancel, so F is unchanged.');
    });

    test('keeps a trailing number that belongs to the last step', () {
      final steps = Explanation.splitSteps(
        '1. Start here. 2. Then this. 3. Result: -2 - root3.',
      );
      expect(steps.last, 'Result: -2 - root3.');
    });

    test('prose is not steps', () {
      expect(Explanation.splitSteps('An external modem sits outside.'), isEmpty);
      expect(Explanation.splitSteps('Take 2. Then do 5. things.'), isEmpty);
    });

    test('a single marker is not steps', () {
      expect(Explanation.splitSteps('1. Only one thing to do here.'), isEmpty);
    });

    test('the parsed Solution carries its steps', () {
      final e = Explanation.parse(
        'Concept: An idea. Solution: 1. First. 2. Second. Trick: A trick.',
      );
      final sol = e.partFor('Solution')!;
      expect(sol.hasSteps, isTrue);
      expect(sol.steps, ['First.', 'Second.']);
      expect(e.partFor('Concept')!.hasSteps, isFalse);
    });
  });

  group('isRtlText', () {
    test('roman Urdu is left to right', () {
      // 1,599 of the 1,819 Urdu explanations look like this, and all of them
      // were being right-aligned.
      expect(
        isRtlText('Identity istemal karen: Sec + Cosec = pi/2 hota hai.'),
        isFalse,
      );
    });

    test('Arabic script is right to left', () {
      expect(isRtlText('یہ ایک یاد رکھنے والی قیمت ہے۔'), isTrue);
    });

    test('English is left to right', () {
      expect(isRtlText('Concept: Scientific prefixes.'), isFalse);
    });

    test('empty is left to right', () {
      expect(isRtlText(null), isFalse);
      expect(isRtlText(''), isFalse);
    });

    test('Arabic script with a few English terms stays right to left', () {
      expect(isRtlText('واٹ ایس آئی (SI) یونٹ ہے۔'), isTrue);
    });
  });
}
