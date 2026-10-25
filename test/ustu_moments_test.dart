import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/core/utils/ustu_overlays.dart';

/// The broken streak exchange and the weak topic nudge: how fast their text is
/// readable, and that the student can always act or leave.
Future<void> _push(
  WidgetTester t,
  Widget moment, {
  bool reduceMotion = false,
}) async {
  t.view.physicalSize = const Size(412, 915);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => moment),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pump();
}

/// What a typing line currently shows, cursor excluded.
String _shown(WidgetTester t, Key key) {
  final rich = t.widget<RichText>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(RichText))
        .last,
  );
  final text = rich.text.toPlainText();
  return text.endsWith('|') ? text.substring(0, text.length - 1) : text;
}

double _opacityAbove(WidgetTester t, Finder finder) => t
    .widget<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  group('broken streak', () {
    const excuse = Key('broken-excuse-2');

    testWidgets('names the streak that was lost', (t) async {
      await _push(t, const BrokenStreakContent(name: 'Ali', lostStreak: 5));
      // A pushed route spends its first frame offstage, out of the finders' view.
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('💀  Streak Broken  ·  5 → 0'), findsOneWidget);
      expect(
        find.text('Wah Ali wah! 5 din ki streak aise hi chhor di?'),
        findsOneWidget,
      );
    });

    testWidgets('roasts, asks, answers, then takes the student to practice', (
      t,
    ) async {
      var restarted = false;
      await _push(
        t,
        BrokenStreakContent(
          name: 'Ali',
          lostStreak: 5,
          onRestart: () => restarted = true,
        ),
      );

      // Still typing the roast: nothing to answer yet.
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byKey(excuse), findsNothing);

      // The roast is done in about a second, and the replies come up.
      await t.pump(const Duration(milliseconds: 900));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(excuse), findsOneWidget);

      await t.tap(find.byKey(excuse));
      await t.pump();
      expect(find.byKey(excuse), findsNothing);
      expect(find.text('Doosri app pe tha 👀'), findsOneWidget);

      // Ustu's comeback types out, then Day 1 is offered.
      await t.pump(const Duration(milliseconds: 1100));
      await t.pump(const Duration(milliseconds: 300));
      expect(
        _shown(t, const Key('broken-reply')),
        'Mujhe pata tha! 😤 Wapas aa gaye ho toh maaf kiya. Day 1, abhi.',
      );
      expect(find.text('Day 1 shuru karo 🔥'), findsOneWidget);

      await t.tap(find.byKey(const Key('broken-restart')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(restarted, isTrue);
      expect(find.byType(BrokenStreakContent), findsNothing);
    });

    testWidgets('a tap finishes the line being typed', (t) async {
      await _push(t, const BrokenStreakContent(name: 'Ali', lostStreak: 3));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(excuse), findsNothing);

      await t.tap(find.byType(SingleChildScrollView));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(excuse), findsOneWidget);
    });

    testWidgets('Baad mein closes it without starting practice', (t) async {
      var restarted = false;
      await _push(
        t,
        BrokenStreakContent(name: 'Ali', onRestart: () => restarted = true),
      );
      await t.pump(const Duration(milliseconds: 1500));
      await t.tap(find.byKey(const Key('broken-later')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(BrokenStreakContent), findsNothing);
      expect(restarted, isFalse);
    });

    testWidgets('with animations off it opens ready to answer', (t) async {
      await _push(
        t,
        const BrokenStreakContent(name: 'Ali', lostStreak: 2),
        reduceMotion: true,
      );
      await t.pump();
      expect(find.byKey(excuse), findsOneWidget);
    });
  });

  group('weak topic', () {
    const line = Key('weak-topic-line');
    const full =
        'Ustu ne notice kiya: "Trigonometry" mein 5 ghaltiyan. 5 min do, sudhaar do!';

    Widget moment() => WeakTopicOverlayContent(
      topic: 'Trigonometry',
      wrongCount: 5,
      exam: 'FAST-NU',
      section: 'Advanced Maths',
      onPracticeNow: () {},
    );

    testWidgets('starts typing straight away', (t) async {
      await _push(t, moment());
      await t.pump(const Duration(milliseconds: 250));
      expect(_shown(t, line), isNotEmpty);
    });

    testWidgets('the whole line and the buttons are up within 1.4 s', (
      t,
    ) async {
      await _push(t, moment());
      await t.pump(const Duration(milliseconds: 1100));
      expect(_shown(t, line), full);

      await t.pump(const Duration(milliseconds: 300));
      expect(_opacityAbove(t, find.byKey(const Key('weak-topic-later'))), 1);
    });

    testWidgets('a tap shows the whole line at once', (t) async {
      await _push(t, moment());
      await t.pump(const Duration(milliseconds: 100));
      expect(_shown(t, line), isNot(full));

      await t.tap(find.byKey(line));
      await t.pump();
      expect(_shown(t, line), full);
    });
  });
}
