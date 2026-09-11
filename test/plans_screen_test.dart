import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/screens/plans/plans_screen.dart';

/// The paywall: that it fits every phone, and that picking a plan changes
/// what the button offers.
Widget _app({bool reduceMotion = true}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PlansScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester t, Size size, {bool reduceMotion = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_app(reduceMotion: reduceMotion));
  await t.tap(find.text('open'));
  if (reduceMotion) {
    await t.pumpAndSettle();
  } else {
    // Ustu floats for as long as the screen is open, so it never settles.
    await t.pump();
    await t.pump(const Duration(milliseconds: 1200));
  }
}

void main() {
  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    testWidgets('lays out on a ${size.width.toInt()}x${size.height.toInt()} '
        'screen without overflowing', (t) async {
      await _open(t, size);
      expect(find.byType(PlansScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('starts on Pro Monthly, and choosing credits changes the button',
      (t) async {
    await _open(t, const Size(412, 915));
    expect(find.text('Get Pro  ·  PKR 399'), findsOneWidget);
    expect(find.text('Cancel anytime.'), findsOneWidget);

    await t.ensureVisible(find.byKey(const Key('plan-credits')));
    await t.tap(find.byKey(const Key('plan-credits')));
    await t.pumpAndSettle();
    expect(find.text('Get 50 credits  ·  PKR 249'), findsOneWidget);
    expect(find.text('Get Pro  ·  PKR 399'), findsNothing);

    await t.tap(find.byKey(const Key('plan-monthly')));
    await t.pumpAndSettle();
    expect(find.text('Get Pro  ·  PKR 399'), findsOneWidget);
  });

  testWidgets('the button says payment is coming until billing is wired',
      (t) async {
    await _open(t, const Size(412, 915));
    await t.tap(find.byKey(const Key('plans-cta')));
    await t.pump();
    expect(find.text('Payment coming soon! 🚀'), findsOneWidget);
  });

  testWidgets('Maybe later leaves the paywall', (t) async {
    await _open(t, const Size(412, 915));
    await t.tap(find.text('Maybe later'));
    await t.pumpAndSettle();
    expect(find.byType(PlansScreen), findsNothing);
  });

  testWidgets('the close button leaves the paywall', (t) async {
    await _open(t, const Size(412, 915));
    await t.tap(find.byKey(const Key('plans-close')));
    await t.pumpAndSettle();
    expect(find.byType(PlansScreen), findsNothing);
  });

  testWidgets('with animations on, it opens and closes cleanly', (t) async {
    await _open(t, const Size(412, 915), reduceMotion: false);
    expect(find.text('Limit khatam.'), findsOneWidget);

    await t.tap(find.byKey(const Key('plans-close')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(PlansScreen), findsNothing);
  });
}
