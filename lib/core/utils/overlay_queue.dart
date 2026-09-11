import 'dart:async';

import 'package:flutter/foundation.dart';

/// Shows one overlay at a time, in priority order.
///
/// Home can raise several overlays from a single build: a streak celebration,
/// the daily weak topic nudge, the broken streak roast. Each used to call
/// showGeneralDialog on its own, so they stacked, and the one underneath played
/// its animation unseen and was revealed half finished when the top one was
/// dismissed — which looked exactly like the celebration arriving late.
///
/// Kept free of BuildContext so the ordering rules can be tested directly.
class OverlayQueue {
  OverlayQueue({Future<void> Function()? burstWindow})
    : _burstWindow = burstWindow ?? _immediately;

  static Future<void> _immediately() => Future<void>.value();

  /// Waited on before each overlay is chosen, so everything raised in the same
  /// burst has arrived and priority, not arrival order, picks the first.
  final Future<void> Function() _burstWindow;

  final List<_Entry> _entries = [];
  bool _draining = false;
  int _sequence = 0;

  /// Whether an overlay is on screen or about to be.
  bool get isBusy => _draining;

  /// Queues an overlay.
  ///
  /// [present] shows it and completes when it is dismissed, returning false if
  /// it decided not to show after all, for instance because its screen went
  /// away in the meantime. The returned future completes with the same value.
  /// Lower [priority] goes first; equal priorities keep their arrival order.
  Future<bool> add({
    required int priority,
    required Future<bool> Function() present,
  }) {
    final entry = _Entry(priority, _sequence++, present);
    _entries.add(entry);
    unawaited(_drain());
    return entry.done.future;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_entries.isNotEmpty) {
        await _burstWindow();
        _entries.sort(_Entry.compare);
        final entry = _entries.removeAt(0);

        var shown = false;
        try {
          shown = await entry.present();
        } catch (error, stack) {
          // One broken overlay, a missing asset say, must not hold every
          // later overlay hostage for the rest of the session.
          debugPrint('[OverlayQueue] overlay failed: $error\n$stack');
        }
        entry.done.complete(shown);
      }
    } finally {
      _draining = false;
    }
  }
}

class _Entry {
  _Entry(this.priority, this.sequence, this.present);

  final int priority;
  final int sequence;
  final Future<bool> Function() present;
  final Completer<bool> done = Completer<bool>();

  static int compare(_Entry a, _Entry b) => a.priority != b.priority
      ? a.priority.compareTo(b.priority)
      : a.sequence.compareTo(b.sequence);
}
