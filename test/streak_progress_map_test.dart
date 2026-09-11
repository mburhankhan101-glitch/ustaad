import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/core/utils/ustu_overlays.dart';

/// The streak progress map's choreography.
///
/// The owl is replaced by a plain box so nothing here loads a Lottie file.
const _owl = SizedBox(key: Key('owl'), width: 90, height: 90);

Widget _app(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child,
      ),
    ),
  );
}

String _days(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('streak-map-days'))).data!;

double _continueOpacity(WidgetTester t) =>
    t.widget<Opacity>(find.byKey(const Key('streak-map-continue'))).opacity;

void main() {
  group('stage and travel', () {
    test('streaks fall into seven day stages', () {
      expect(streakStageStart(0), 1);
      expect(streakStageStart(1), 1);
      expect(streakStageStart(7), 1);
      expect(streakStageStart(8), 8);
      expect(streakStageStart(14), 8);
      expect(streakStageStart(15), 15);
    });

    test('an earned day hops from yesterday to today', () {
      final t = streakOwlTravel(3, isCatchUp: false);
      expect(t.from, 1);
      expect(t.to, 2);
    });

    test('an earned day that opens a new stage hops in from the entry point', () {
      final t = streakOwlTravel(8, isCatchUp: false);
      expect(t.from, -1);
      expect(t.to, 0);
    });

    test('a replay always walks in from the entry point', () {
      final t = streakOwlTravel(10, isCatchUp: true);
      expect(t.from, -1);
      expect(t.to, 2);
    });
  });

  group('earned day', () {
    testWidgets('shows yesterday, lands on today, then offers the button', (
      t,
    ) async {
      await t.pumpWidget(
        _app(const StreakProgressMap(currentStreak: 3, isCatchUp: false, owl: _owl)),
      );
      expect(_days(t), '2 Days Strong 🔥');
      expect(_continueOpacity(t), 0);

      // Mid-hop: the count waits for the landing instead of jumping ahead.
      await t.pump(const Duration(milliseconds: 400));
      expect(_days(t), '2 Days Strong 🔥');
      expect(_continueOpacity(t), 0);

      await t.pumpAndSettle();
      expect(_days(t), '3 Days Strong 🔥');
      expect(_continueOpacity(t), 1);
      expect(find.text('Ek aur din, ek aur qadam. Keep it up! 🚀'), findsOneWidget);
    });

    testWidgets('a first ever day reads "1 Day", not "1 Days"', (t) async {
      await t.pumpWidget(
        _app(const StreakProgressMap(currentStreak: 1, isCatchUp: false, owl: _owl)),
      );
      await t.pumpAndSettle();
      expect(_days(t), '1 Day Strong 🔥');
    });
  });

  group('replay', () {
    testWidgets('counts up through each day on the way to today', (t) async {
      await t.pumpWidget(
        _app(const StreakProgressMap(currentStreak: 3, isCatchUp: true, owl: _owl)),
      );
      final seen = <String>{_days(t)};
      for (var i = 0; i < 200; i++) {
        await t.pump(const Duration(milliseconds: 16));
        seen.add(_days(t));
      }
      expect(
        seen,
        containsAll(['1 Day Strong 🔥', '2 Days Strong 🔥', '3 Days Strong 🔥']),
      );
      expect(_days(t), '3 Days Strong 🔥');
    });
  });

  group('control', () {
    testWidgets('tapping the map skips straight to the end', (t) async {
      await t.pumpWidget(
        _app(const StreakProgressMap(currentStreak: 6, isCatchUp: true, owl: _owl)),
      );
      await t.pump(const Duration(milliseconds: 16));
      expect(_continueOpacity(t), 0);

      await t.tap(find.byKey(const Key('streak-map-days')));
      await t.pump();
      expect(_days(t), '6 Days Strong 🔥');
      expect(_continueOpacity(t), 1);
    });

    testWidgets('with animations turned off it opens on the finished map', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          const StreakProgressMap(currentStreak: 4, isCatchUp: true, owl: _owl),
          reduceMotion: true,
        ),
      );
      expect(_days(t), '4 Days Strong 🔥');
      expect(_continueOpacity(t), 1);
    });

    testWidgets('waits for its own route to finish opening before it starts', (
      t,
    ) async {
      // A route with a 300 ms entrance and no visual transition, so the owl's
      // position on screen reflects the map's own timeline and nothing else.
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (_, __, ___) => const StreakProgressMap(
                    currentStreak: 5,
                    isCatchUp: true,
                    owl: _owl,
                  ),
                  transitionsBuilder: (_, __, ___, child) => child,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      final atOpen = t.getTopLeft(find.byKey(const Key('owl')));

      await t.pump(const Duration(milliseconds: 200));
      expect(
        t.getTopLeft(find.byKey(const Key('owl'))),
        atOpen,
        reason: 'the owl must not move while the route is still opening',
      );

      await t.pumpAndSettle();
      expect(t.getTopLeft(find.byKey(const Key('owl'))), isNot(atOpen));
      expect(_days(t), '5 Days Strong 🔥');
    });

    testWidgets("Let's Go closes the map", (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StreakProgressMap(
                    currentStreak: 2,
                    isCatchUp: true,
                    owl: _owl,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byType(StreakProgressMap), findsOneWidget);

      await t.tap(find.text("Let's Go"));
      await t.pumpAndSettle();
      expect(find.byType(StreakProgressMap), findsNothing);
    });
  });
}
