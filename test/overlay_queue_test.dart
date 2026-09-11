import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/core/utils/overlay_queue.dart';

/// The queue every Ustu overlay goes through.
///
/// These pin down the three things that made the streak celebration look late
/// or go missing: overlays stacking on top of each other, the wrong one going
/// first when several fire together, and one failure jamming the rest.
void main() {
  test('only one overlay is on screen at a time', () async {
    final queue = OverlayQueue();
    final events = <String>[];
    final firstDismissed = Completer<void>();

    final a = queue.add(
      priority: 0,
      present: () async {
        events.add('a opened');
        await firstDismissed.future;
        events.add('a dismissed');
        return true;
      },
    );
    final b = queue.add(
      priority: 0,
      present: () async {
        events.add('b opened');
        return true;
      },
    );

    await pumpEventQueue();
    expect(events, ['a opened'], reason: 'b must wait for a to be dismissed');

    firstDismissed.complete();
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(events, ['a opened', 'a dismissed', 'b opened']);
  });

  test('within one burst, priority decides the order, not arrival', () async {
    // Home raises the weak topic nudge and a streak celebration from the same
    // build. Whichever callback happened to run first used to win.
    final queue = OverlayQueue();
    final order = <String>[];

    final weakTopic = queue.add(
      priority: 3,
      present: () async {
        order.add('weak topic');
        return true;
      },
    );
    final streak = queue.add(
      priority: 0,
      present: () async {
        order.add('streak map');
        return true;
      },
    );

    await Future.wait([weakTopic, streak]);
    expect(order, ['streak map', 'weak topic']);
  });

  test('equal priorities keep their arrival order', () async {
    final queue = OverlayQueue();
    final order = <int>[];
    final all = [
      for (var i = 0; i < 3; i++)
        queue.add(
          priority: 1,
          present: () async {
            order.add(i);
            return true;
          },
        ),
    ];
    await Future.wait(all);
    expect(order, [0, 1, 2]);
  });

  test('an overlay that throws does not block the ones after it', () async {
    final queue = OverlayQueue();
    final broken = queue.add(
      priority: 0,
      present: () async => throw StateError('asset missing'),
    );
    final next = queue.add(priority: 1, present: () async => true);

    expect(await broken, isFalse);
    expect(await next, isTrue);
  });

  test('an overlay that declines to show is reported as not shown', () async {
    // e.g. its screen was covered again before it could open, which Home uses
    // to keep the celebration for later instead of losing it.
    final queue = OverlayQueue();
    expect(await queue.add(priority: 0, present: () async => false), isFalse);
  });

  test('the queue starts again after going idle', () async {
    final queue = OverlayQueue();
    expect(await queue.add(priority: 0, present: () async => true), isTrue);
    expect(queue.isBusy, isFalse);
    expect(await queue.add(priority: 0, present: () async => true), isTrue);
  });

  test('the burst window is waited on before each overlay is chosen', () async {
    var windows = 0;
    final queue = OverlayQueue(
      burstWindow: () async {
        windows += 1;
      },
    );
    await Future.wait([
      queue.add(priority: 0, present: () async => true),
      queue.add(priority: 0, present: () async => true),
    ]);
    expect(windows, 2);
  });
}
