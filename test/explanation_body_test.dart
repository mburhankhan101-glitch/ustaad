import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/screens/explanation/explanation_body.dart';

// The explanation below is the shape every one of the 1,819 in the bank takes.
const _explanation =
    'Concept: Coulomb law and how force scales with charge and separation. '
    'Solution: 1. Coulomb force is F = kq1q2/r squared. '
    '2. Doubling both charges multiplies the numerator by 4. '
    '3. Doubling the distance multiplies the denominator by 4. '
    '4. The two cancel, so F is unchanged. '
    'Trick: Scale the numerator and the denominator separately. '
    'Mistake: Picking Four times the original force, which forgets the square.';

Question _question() => const Question(
      id: 'q1',
      text: 'If both charges and the distance are doubled, the force becomes:',
      options: [
        'Half the original force',
        'Equal to the original force',
        'Four times the original force',
        'One fourth of the original force',
      ],
      correctIndex: 1,
      section: 'Physics',
      exam: 'NUST-NET',
      exams: ['NUST-NET'],
      topic: 'Electrostatics',
      year: 2023,
      difficulty: 'medium',
      explanationEn: _explanation,
      explanationUr: '',
    );

Future<void> _pump(
  WidgetTester tester, {
  int? selectedIndex,
  String explanation = _explanation,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExplanationBody(
            question: _question(),
            explanation: explanation,
            selectedIndex: selectedIndex,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('structure', () {
    testWidgets('renders the parts as parts, not as one paragraph', (t) async {
      await _pump(t);

      // The labels become headings and must not survive as literal text.
      expect(find.text('THE IDEA'), findsOneWidget);
      expect(find.text('WORKING'), findsOneWidget);
      expect(find.textContaining('Concept:'), findsNothing);
      expect(find.textContaining('Solution:'), findsNothing);

      // The concept body renders without its label.
      expect(
        find.text('Coulomb law and how force scales with charge and separation.'),
        findsOneWidget,
      );
    });

    testWidgets('step numbers are chips, not characters in the prose', (t) async {
      await _pump(t);

      expect(find.text('1'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Coulomb force is F = kq1q2/r squared.'), findsOneWidget);
      expect(find.text('The two cancel, so F is unchanged.'), findsOneWidget);
      // No step should still carry its own number.
      expect(find.textContaining('1. Coulomb force'), findsNothing);
    });

    testWidgets('trick and mistake start collapsed', (t) async {
      await _pump(t);

      expect(find.text('Exam trick'), findsOneWidget);
      expect(find.text('Aam galti'), findsOneWidget);
      expect(
        find.text('Scale the numerator and the denominator separately.'),
        findsNothing,
      );
    });

    testWidgets('tapping the trick opens it', (t) async {
      await _pump(t);

      await t.tap(find.byKey(const Key('explanation-trick')));
      await t.pumpAndSettle();

      expect(
        find.text('Scale the numerator and the denominator separately.'),
        findsOneWidget,
      );
    });
  });

  group('what the student picked', () {
    testWidgets('a correct answer shows all the working at once', (t) async {
      await _pump(t, selectedIndex: 1);

      expect(find.byKey(const Key('explanation-your-answer')), findsNothing);
      expect(find.byKey(const Key('explanation-next-step')), findsNothing);
      expect(find.text('The two cancel, so F is unchanged.'), findsOneWidget);
    });

    testWidgets('a wrong answer opens on what they chose', (t) async {
      await _pump(t, selectedIndex: 2);

      expect(find.byKey(const Key('explanation-your-answer')), findsOneWidget);
      expect(find.text('Aap ne yeh chuna tha'), findsOneWidget);
      expect(find.text('Four times the original force'), findsOneWidget);
    });

    testWidgets('a wrong answer is walked through one step at a time', (t) async {
      await _pump(t, selectedIndex: 2);

      expect(find.text('Coulomb force is F = kq1q2/r squared.'), findsOneWidget);
      expect(find.text('The two cancel, so F is unchanged.'), findsNothing);
      expect(find.text('3 baaki'), findsOneWidget);

      await t.tap(find.byKey(const Key('explanation-next-step')));
      await t.pumpAndSettle();
      expect(find.text('2 baaki'), findsOneWidget);

      await t.tap(find.byKey(const Key('explanation-show-all')));
      await t.pumpAndSettle();
      expect(find.text('The two cancel, so F is unchanged.'), findsOneWidget);
      expect(find.byKey(const Key('explanation-next-step')), findsNothing);
    });

    testWidgets('the mistake is claimed only when it names their answer', (t) async {
      // The stored Mistake names "Four times the original force".
      await _pump(t, selectedIndex: 2);
      expect(find.text('Yehi galti aap ne ki'), findsOneWidget);

      // A different wrong answer must not be claimed as the one described.
      await _pump(t, selectedIndex: 0);
      expect(find.text('Yehi galti aap ne ki'), findsNothing);
      expect(find.text('Aam galti'), findsOneWidget);
    });
  });

  group('text direction', () {
    testWidgets('roman Urdu is laid out left to right', (t) async {
      await _pump(
        t,
        explanation: 'Concept: Coulomb law ka taalluq. '
            'Solution: 1. Formula likhen. 2. Values daalen. '
            'Trick: Numerator alag dekhen. Mistake: Square bhoolna.',
      );

      final concept = t.widget<Text>(
        find.byKey(const Key('explanation-concept')),
      );
      expect(concept.textDirection, TextDirection.ltr);
    });

    testWidgets('Arabic script is laid out right to left', (t) async {
      await _pump(
        t,
        explanation: 'Concept: یہ ایک یاد رکھنے والی قیمت ہے۔ '
            'Solution: 1. پہلے فارمولا لکھیں۔ 2. پھر ویلیو ڈالیں۔',
      );

      final concept = t.widget<Text>(
        find.byKey(const Key('explanation-concept')),
      );
      expect(concept.textDirection, TextDirection.rtl);
    });
  });

  group('degraded input', () {
    testWidgets('an empty explanation says so instead of rendering nothing',
        (t) async {
      await _pump(t, explanation: '');
      expect(find.byKey(const Key('explanation-empty')), findsOneWidget);
    });

    testWidgets('an unlabelled explanation still renders its prose', (t) async {
      await _pump(t, explanation: 'Just some prose with no labels at all.');
      expect(find.byKey(const Key('explanation-fallback')), findsOneWidget);
      expect(find.text('Just some prose with no labels at all.'), findsOneWidget);
    });
  });
}
