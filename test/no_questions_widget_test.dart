// What a student sees when a section has nothing behind it.
//
// The case that prompted this: an MBBS student taps English on MDCAT, where
// the bank is still empty, and used to get "No questions found. Check your
// Firestore data." These tests pin down that the two reasons a section can
// be empty read differently, because they call for different actions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/widgets/common/no_questions_widget.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(backgroundColor: Colors.black, body: child));

  testWidgets('an empty bank explains itself and offers another subject', (
    tester,
  ) async {
    var backs = 0;

    await tester.pumpWidget(
      host(
        NoQuestionsWidget(
          section: 'English',
          exam: 'MDCAT',
          onBack: () => backs++,
        ),
      ),
    );

    // Names the subject and the exam, so it reads as a gap we know about
    // rather than a failure the student caused.
    expect(find.textContaining('English'), findsWidgets);
    expect(find.textContaining('MDCAT'), findsOneWidget);

    // Nothing to retry — the questions genuinely are not written yet.
    expect(find.text('Try Again'), findsNothing);

    await tester.tap(find.text('Pick another subject'));
    expect(backs, 1);
  });

  testWidgets('a failed fetch offers a retry instead', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      host(
        NoQuestionsWidget(
          section: 'Physics',
          exam: 'NUST-NET',
          onBack: () {},
          onRetry: () => retries++,
        ),
      ),
    );

    await tester.tap(find.text('Try Again'));
    expect(retries, 1);

    // And it must not claim we are still writing Physics questions — we
    // have 1581 of them; this was a network problem.
    expect(find.textContaining('tayyar ho rahe hain'), findsNothing);
  });

  testWidgets('never shows the developer-facing Firestore message', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        NoQuestionsWidget(section: 'English', exam: 'MDCAT', onBack: () {}),
      ),
    );

    expect(find.textContaining('Firestore'), findsNothing);
  });
}
