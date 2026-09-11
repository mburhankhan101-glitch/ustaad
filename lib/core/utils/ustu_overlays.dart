// ─────────────────────────────────────────────────────────────────────────────
// ustu_overlays.dart
//
// Five Ustu SVG/Lottie overlay moments:
//   1. Ustu Broken Streak Overlay  → shown on HomeScreen when streak is broken
//   2. Ustu Perfect Score Overlay  → shown on ResultScreen when score ≥ 7
//   3. Ustu Bad Score Overlay      → shown on ResultScreen when score ≤ 6
//   4. Ustu Weak Topic Overlay     → shown on HomeScreen for the worst weak topic
//   5. Ustu Progress Map Overlay   → shown on HomeScreen/Quiz completion for streak progress
//
// HOW TO USE:
//   UstuOverlays.showBrokenStreak(context, name: 'Burhan');
//   UstuOverlays.showPerfectScore(context, name: 'Burhan', correct: 8, total: 10);
//   UstuOverlays.showBadScore(context, name: 'Burhan', correct: 4, total: 10);
//   UstuOverlays.showWeakTopicOverlay(context, topic: 'Trigonometry', wrongCount: 5, exam: 'FAST-NU', section: 'Advanced Maths', onPracticeNow: () { ... });
//   UstuOverlays.showStreakProgressMap(context, currentStreak: 3, isCatchUp: true);
//
// Every overlay goes through one queue, so two moments raised on the same
// frame (a streak increase and the daily weak topic, say) are shown one after
// the other in priority order instead of stacking. Each one also waits until
// its artwork is decoded and the screen underneath has finished its own
// transition, so it opens complete rather than popping its picture in late.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:ustaad/core/utils/overlay_queue.dart';

/// The order overlays raised together are shown in. Lower goes first.
abstract final class _OverlayPriority {
  /// A streak just earned is the moment the student came for, so it leads.
  static const streakMap = 0;
  static const brokenStreak = 1;
  static const score = 2;
  static const weakTopic = 3;
}

class UstuOverlays {
  UstuOverlays._();

  static const _owlAsset = 'assets/images/ustu_owl.json';

  /// One queue for every overlay. Waiting for the end of the frame before
  /// choosing lets everything raised by the same build arrive first, so
  /// priority decides the order rather than whichever callback ran first.
  static final OverlayQueue _queue = OverlayQueue(
    burstWindow: () => WidgetsBinding.instance.endOfFrame,
  );

  static Future<LottieComposition>? _owl;
  static final Map<String, Future<void>> _svgs = {};

  /// The owl, decoded once and reused.
  ///
  /// Lottie.asset used to load and parse the file when the map opened, so the
  /// sheet slid up with an empty space where the owl should be and the owl
  /// appeared a beat later, already partway along its path.
  static Future<LottieComposition> owlComposition() =>
      _owl ??= AssetLottie(_owlAsset).load();

  /// Decodes the owl ahead of time. Home calls this once it has drawn, so the
  /// first celebration of the session never waits on a file.
  static Future<void> warmUp() async {
    try {
      await owlComposition();
    } catch (e) {
      _owl = null; // try again next time rather than remembering the failure
      debugPrint('[UstuOverlays] owl failed to load: $e');
    }
  }

  /// Puts an SVG into flutter_svg's cache before its overlay opens. These are
  /// half a megabyte and more, and parsing one on first display is what made
  /// the artwork appear after the sheet rather than with it.
  static Future<void> _warmSvg(String asset) {
    return _svgs[asset] ??= () async {
      try {
        final loader = SvgAssetLoader(asset);
        await svg.cache.putIfAbsent(
          loader.cacheKey(null),
          () => loader.loadBytes(null),
        );
      } catch (e) {
        _svgs.remove(asset);
        debugPrint('[UstuOverlays] $asset failed to precache: $e');
      }
    }();
  }

  /// Queues an overlay, prepares its assets, and opens it once the screen
  /// underneath is settled. Completes with whether it was shown.
  static Future<bool> _present(
    BuildContext context, {
    required int priority,
    Future<void> Function()? prepare,
    required Future<void> Function() open,
  }) {
    return _queue.add(
      priority: priority,
      present: () async {
        if (prepare != null) await prepare();
        if (!context.mounted) return false;
        if (!await _routeSettled(context)) return false;
        if (!context.mounted) return false;
        await open();
        return true;
      },
    );
  }

  /// Waits for the caller's screen to finish any transition of its own.
  ///
  /// A celebration raised the moment the results screen is popped would
  /// otherwise slide up while that screen is still sliding away, and the two
  /// motions fight. Returns false if the screen is no longer the one on top.
  static Future<bool> _routeSettled(BuildContext context) async {
    final route = ModalRoute.of(context);
    if (route == null) return true;
    await _untilStatus(route.animation, AnimationStatus.completed);
    await _untilStatus(route.secondaryAnimation, AnimationStatus.dismissed);
    return context.mounted && route.isCurrent;
  }

  static Future<void> _untilStatus(
    Animation<double>? animation,
    AnimationStatus target,
  ) {
    if (animation == null || animation.status == target) {
      return Future<void>.value();
    }
    final done = Completer<void>();
    void listener(AnimationStatus status) {
      if (status == target && !done.isCompleted) done.complete();
    }

    animation.addStatusListener(listener);
    // Bounded, so a screen that stays covered cannot stall every overlay
    // queued behind this one.
    return done.future
        .timeout(const Duration(seconds: 2), onTimeout: () {})
        .whenComplete(() => animation.removeStatusListener(listener));
  }

  // ── Public entry-points ─────────────────────────────────────────────────────

  static Future<bool> showStreakProgressMap(
    BuildContext context, {
    required int currentStreak,
    bool isCatchUp = false,
  }) {
    LottieComposition? owl;
    return _present(
      context,
      priority: _OverlayPriority.streakMap,
      prepare: () async {
        try {
          owl = await owlComposition();
        } catch (e) {
          _owl = null;
          debugPrint('[UstuOverlays] owl failed to load: $e');
        }
      },
      open: () async {
        // No haptic here: the map now gives one when the owl lands, which is
        // the moment it means something.
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.85),
          transitionDuration: const Duration(milliseconds: 500),
          transitionBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
          pageBuilder: (_, __, ___) => StreakProgressMap(
            currentStreak: currentStreak,
            isCatchUp: isCatchUp,
            owlComposition: owl,
          ),
        );
      },
    );
  }

  static Future<bool> showBrokenStreak(
    BuildContext context, {
    required String name,
  }) {
    return _present(
      context,
      priority: _OverlayPriority.brokenStreak,
      prepare: () => _warmSvg('assets/images/ustu_broken_streak.svg'),
      open: () async {
        HapticFeedback.heavyImpact();
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.78),
          transitionDuration: const Duration(milliseconds: 480),
          transitionBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
          pageBuilder: (_, __, ___) => _BrokenStreakContent(name: name),
        );
      },
    );
  }

  static Future<bool> showPerfectScore(
    BuildContext context, {
    required String name,
    required int correct,
    required int total,
  }) {
    return _present(
      context,
      priority: _OverlayPriority.score,
      prepare: () => _warmSvg('assets/images/ustu_perfect_score.svg'),
      open: () async {
        HapticFeedback.heavyImpact();
        await showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'dismiss',
          barrierColor: Colors.black.withOpacity(0.65),
          transitionDuration: const Duration(milliseconds: 400),
          transitionBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(opacity: curved, child: child);
          },
          pageBuilder: (_, __, ___) =>
              _PerfectScoreContent(name: name, correct: correct, total: total),
        );
      },
    );
  }

  static Future<bool> showBadScore(
    BuildContext context, {
    required String name,
    required int correct,
    required int total,
  }) {
    return _present(
      context,
      priority: _OverlayPriority.score,
      prepare: () => _warmSvg('assets/images/ustu_bad_score.svg'),
      open: () async {
        HapticFeedback.heavyImpact();
        await showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'dismiss',
          barrierColor: Colors.black.withOpacity(0.65),
          transitionDuration: const Duration(milliseconds: 400),
          transitionBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(opacity: curved, child: child);
          },
          pageBuilder: (_, __, ___) =>
              _BadScoreContent(name: name, correct: correct, total: total),
        );
      },
    );
  }

  static Future<bool> showWeakTopicOverlay(
    BuildContext context, {
    required String topic,
    required int wrongCount,
    required String exam,
    required String section,
    required VoidCallback onPracticeNow,
  }) {
    return _present(
      context,
      priority: _OverlayPriority.weakTopic,
      prepare: () => _warmSvg('assets/images/ustu_weak_topic.svg'),
      open: () async {
        HapticFeedback.heavyImpact();
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.78),
          transitionDuration: const Duration(milliseconds: 450),
          transitionBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
          pageBuilder: (_, __, ___) => _WeakTopicOverlayContent(
            topic: topic,
            wrongCount: wrongCount,
            exam: exam,
            section: section,
            onPracticeNow: onPracticeNow,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STREAK PROGRESS MAP (Curved Game Path)
// ─────────────────────────────────────────────────────────────────────────────

/// The first day of the seven day stage a streak falls in: 1, 8, 15 and so on.
int streakStageStart(int streak) =>
    streak <= 1 ? 1 : ((streak - 1) ~/ 7) * 7 + 1;

/// Where the owl travels on the map, measured in node positions.
///
/// 0 is the stage's first day and 6 its last; -1 is the entry point just above
/// the first node. A catch-up replay always walks in from the entry point, and
/// an earned day hops from yesterday's node, or from the entry point when today
/// opens a new stage (day 8, day 15).
({double from, double to}) streakOwlTravel(
  int streak, {
  required bool isCatchUp,
}) {
  final start = streakStageStart(streak);
  final to = (streak - start).clamp(0, 6).toDouble();
  final from = isCatchUp ? -1.0 : to - 1;
  return (from: from, to: to);
}

/// The streak progress map.
///
/// Everything on it runs off a single timeline that starts when the sheet has
/// finished sliding in: the owl's walk, each day lighting up as it is reached,
/// the landing burst, and the button. It used to be a chain of fixed
/// Future.delayed timers started in initState, which knew nothing about the
/// sheet's own entrance or a slow first frame, so on a cold start the owl
/// could be halfway along its path before the sheet had even finished rising.
class StreakProgressMap extends StatefulWidget {
  final int currentStreak;
  final bool isCatchUp;

  /// The decoded owl, handed over by showStreakProgressMap so it never loads
  /// inside the sheet.
  final LottieComposition? owlComposition;

  /// Replaces the owl entirely, for tests that should not load a Lottie file.
  final Widget? owl;

  const StreakProgressMap({
    super.key,
    required this.currentStreak,
    required this.isCatchUp,
    this.owlComposition,
    this.owl,
  });

  @override
  State<StreakProgressMap> createState() => _StreakProgressMapState();
}

class _StreakProgressMapState extends State<StreakProgressMap>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFFFD700);
  static const _primary = Color(0xFF6C63FF);

  static const int _hopMs = 380;
  static const int _earnedTravelMs = 1000;
  static const int _burstMs = 520;
  static const int _buttonMs = 380;

  late final int _stageStart;
  late final double _from;
  late final double _to;
  late final AnimationController _timeline;
  late final Widget _owl;

  /// Fractions of the timeline at which the walk and the landing burst end.
  late final double _travelEnd;
  late final double _burstEnd;

  bool _started = false;
  bool _landed = false;
  late int _lastNodeTicked;
  ModalRoute<dynamic>? _route;
  int? _startCallbackId;

  @override
  void initState() {
    super.initState();

    _stageStart = streakStageStart(widget.currentStreak);
    final travel = streakOwlTravel(
      widget.currentStreak,
      isCatchUp: widget.isCatchUp,
    );
    _from = travel.from;
    _to = travel.to;
    _lastNodeTicked = _from.floor();

    // A replay walks further, so it is paced per day rather than squeezed into
    // one fixed duration, and capped so a full week does not drag.
    final int hops = (_to - _from).round().clamp(1, 7).toInt();
    final int travelMs = widget.isCatchUp
        ? (hops * _hopMs).clamp(700, 2400).toInt()
        : _earnedTravelMs;
    final int totalMs = travelMs + _burstMs + _buttonMs;
    _travelEnd = travelMs / totalMs;
    _burstEnd = (travelMs + _burstMs) / totalMs;

    _timeline = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    )..addListener(_onTick);

    _owl =
        widget.owl ??
        (widget.owlComposition != null
            ? Lottie(composition: widget.owlComposition, fit: BoxFit.contain)
            : Lottie.asset(UstuOverlays._owlAsset, fit: BoxFit.contain));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_started) return;
    _started = true;

    // With system animations turned off, open straight on the finished map.
    if (MediaQuery.disableAnimationsOf(context)) {
      _timeline.value = 1.0;
      return;
    }
    _startWhenEntered(Duration.zero);
  }

  /// Starts the timeline once the route holding the map is on screen and has
  /// finished coming in.
  ///
  /// Checked frame by frame rather than read once from the route's animation
  /// status. A pushed page route is first built offstage for a single frame so
  /// heroes can measure it, and during that frame its animation reports itself
  /// as already complete: a one-off status check then started the owl walking
  /// while the map was still off screen. The check costs nothing and stops the
  /// moment the timeline starts.
  void _startWhenEntered(Duration _) {
    _startCallbackId = null;
    if (!mounted || _timeline.isAnimating || _timeline.value > 0) return;

    final route = _route;
    final entrance = route?.animation;
    final bool entered =
        route == null ||
        entrance == null ||
        (!route.offstage && entrance.status == AnimationStatus.completed);

    if (entered) {
      _timeline.forward();
    } else {
      _startCallbackId = WidgetsBinding.instance.scheduleFrameCallback(
        _startWhenEntered,
      );
    }
  }

  @override
  void dispose() {
    final id = _startCallbackId;
    if (id != null) WidgetsBinding.instance.cancelFrameCallbackWithId(id);
    _timeline.dispose();
    super.dispose();
  }

  double _phase(double v, double start, double end) {
    if (end <= start) return v >= end ? 1.0 : 0.0;
    return ((v - start) / (end - start)).clamp(0.0, 1.0);
  }

  double _travelProgress(double v) => _phase(v, 0, _travelEnd);

  double _owlPosition(double v) =>
      _from +
      (_to - _from) * Curves.easeInOutCubic.transform(_travelProgress(v));

  void _onTick() {
    final v = _timeline.value;
    // On a replay, a soft tick for each day the owl passes, so the walk is
    // felt as well as seen. The landing gets its own, stronger one.
    if (widget.isCatchUp) {
      final node = _owlPosition(v).floor();
      if (node > _lastNodeTicked && node < _to) {
        _lastNodeTicked = node;
        if (node >= 0) HapticFeedback.selectionClick();
      }
    }
    if (!_landed && v >= _travelEnd) {
      _landed = true;
      HapticFeedback.mediumImpact();
    }
  }

  /// Jumps to the finished map. A student who has seen the walk before is
  /// never made to sit through it again.
  void _skip() {
    if (_timeline.value < 1.0) _timeline.value = 1.0;
  }

  double _curveX(double t, double width) {
    final double center = width / 2;
    final double amplitude = width * 0.35;
    return center + amplitude * sin(t * 2 * pi);
  }

  double _curveY(double t, double height) => t * height;

  String _daysStrong(int days) =>
      '$days ${days == 1 ? 'Day' : 'Days'} Strong 🔥';

  @override
  Widget build(BuildContext context) {
    final int stage = (_stageStart - 1) ~/ 7 + 1;
    final bool laterStage = stage > 1;
    final List<Color> bgColors = laterStage
        ? const [Color(0xFF1A1464), Color(0xFF0F0830)]
        : const [Color(0xFF0A0E2E), Color(0xFF1A1464)];

    final screenHeight = MediaQuery.of(context).size.height;
    final double mapTopPadding = screenHeight * 0.22;
    final double mapBottomPadding = screenHeight * 0.30;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: AnimatedBuilder(
          animation: _timeline,
          builder: (context, _) {
            final v = _timeline.value;
            final double travel = _travelProgress(v);
            final double p = _owlPosition(v);
            final bool landed = v >= _travelEnd;
            final double burst = _phase(v, _travelEnd, _burstEnd);
            final double button = _phase(v, _burstEnd, 1.0);
            final int shownDays = (_stageStart + p.floor()).clamp(
              0,
              widget.currentStreak,
            );

            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: bgColors,
                    ),
                  ),
                ),

                if (laterStage)
                  Positioned(
                    top: -100,
                    right: -50,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gold.withValues(alpha: 0.05),
                      ),
                    ),
                  ),

                Positioned.fill(
                  top: mapTopPadding,
                  bottom: mapBottomPadding,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double w = constraints.maxWidth;
                      final double h = constraints.maxHeight;
                      Offset point(double index) =>
                          Offset(_curveX(index / 6, w), _curveY(index / 6, h));

                      // The owl follows the dashed path itself. It used to be
                      // an AnimatedPositioned, which moves in a straight line
                      // between two points and so cut across the curve.
                      // Between days it also hops, lifting off one node and
                      // dropping onto the next.
                      final double lift = travel < 1
                          ? sin((p - p.floorToDouble()) * pi) * 22
                          : 0;
                      final Offset owl = point(p) - Offset(0, lift);
                      final Offset landing = point(_to);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _CurvedDashedPathPainter(),
                              ),
                            ),
                          ),
                          if (landed && burst < 1) ..._burst(landing, burst),
                          for (int i = 0; i <= 6; i++)
                            _node(i, point(i.toDouble()), p, landed, burst),
                          Positioned(
                            left: owl.dx - 45,
                            top: owl.dy - 65,
                            child: SizedBox(width: 90, height: 90, child: _owl),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            laterStage ? 'PHASE $stage UNLOCKED' : 'STREAK MAP',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: laterStage ? _gold : _primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Counts along with the owl, so the number changes
                          // on the day it lands on rather than at the start.
                          Text(
                            _daysStrong(shownDays),
                            key: const Key('streak-map-days'),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    ignoring: button <= 0,
                    child: Opacity(
                      key: const Key('streak-map-continue'),
                      opacity: button,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - button)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!widget.isCatchUp)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Text(
                                    'Ek aur din, ek aur qadam. Keep it up! 🚀',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_primary, Color(0xFF9B94FF)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primary.withValues(alpha: 0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Let\'s Go',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A day on the path, lit once the owl has reached it.
  Widget _node(int i, Offset at, double p, bool landed, double burst) {
    final int day = _stageStart + i;
    final bool reached = p >= i - 1e-6;
    final bool isLanding = i == _to.round();
    final bool isCurrent = landed ? isLanding : (reached && i == p.floor());

    // A day reached during this walk swells and settles as the owl passes, so
    // a replay lights the week one day at a time instead of all at once. Days
    // already lit when the map opened stay still.
    double scale = 1.0;
    if (isLanding && landed) {
      scale += 0.22 * sin(burst * pi);
    } else if (reached && i > _from && !isLanding) {
      final double since = p - i;
      if (since < 0.6) scale += 0.18 * sin((since / 0.6) * pi);
    }
    if (isCurrent) scale *= 1.2;

    const double size = 48;
    final Color bg = reached ? _gold : const Color(0xFF1A1A2E);
    final Color border = reached
        ? _gold
        : Colors.white.withValues(alpha: 0.2);
    final Color text = reached
        ? Colors.black
        : Colors.white.withValues(alpha: 0.5);

    return Positioned(
      left: at.dx - size / 2,
      top: at.dy - size / 2,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent ? Colors.white : border,
              width: isCurrent ? 4 : 3,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ]
                : reached
                ? [BoxShadow(color: _gold.withValues(alpha: 0.3), blurRadius: 8)]
                : const [],
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: text,
              fontSize: isCurrent ? 20 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// A gold ring and sparks thrown off today's node as the owl lands on it.
  List<Widget> _burst(Offset center, double t) {
    final double eased = Curves.easeOutCubic.transform(t);
    final double fade = 1 - t;
    final double ring = 30 + 46 * eased;

    return [
      Positioned(
        left: center.dx - ring,
        top: center.dy - ring,
        child: IgnorePointer(
          child: Container(
            width: ring * 2,
            height: ring * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _gold.withValues(alpha: 0.75 * fade),
                width: 3,
              ),
            ),
          ),
        ),
      ),
      for (int k = 0; k < 8; k++)
        Builder(
          builder: (_) {
            final double angle = k * pi / 4;
            final double distance = 34 + 42 * eased;
            final double spark = 2 + 6 * fade;
            return Positioned(
              left: center.dx + cos(angle) * distance - spark / 2,
              top: center.dy + sin(angle) * distance - spark / 2,
              child: IgnorePointer(
                child: Container(
                  width: spark,
                  height: spark,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold.withValues(alpha: fade),
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }
}

class _CurvedDashedPathPainter extends CustomPainter {
  const _CurvedDashedPathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    bool isFirst = true;

    for (double t = -0.2; t <= 1.2; t += 0.02) {
      double x = (size.width / 2) + (size.width * 0.35) * sin(t * 2 * pi);
      double y = t * size.height;

      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    Path dashedPath = Path();
    const double dashWidth = 12.0;
    const double dashSpace = 8.0;

    for (final measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        dashedPath.addPath(
          measurePath.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// BROKEN STREAK CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _BrokenStreakContent extends StatefulWidget {
  final String name;
  const _BrokenStreakContent({required this.name});

  @override
  State<_BrokenStreakContent> createState() => _BrokenStreakContentState();
}

class _BrokenStreakContentState extends State<_BrokenStreakContent>
    with TickerProviderStateMixin {
  static const _coral = Color(0xFFFF6B6B);

  late final AnimationController _svgCtrl;
  late final Animation<double> _svgScale;
  late final Animation<double> _svgFade;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  String _visibleText = '';
  late final String _fullText;
  bool _typewriterDone = false;

  late final AnimationController _btnCtrl;
  late final Animation<double> _btnAnim;

  @override
  void initState() {
    super.initState();

    _fullText =
        'Wah ${widget.name} Wah, sach sach btana kis doosri app par tyaari kr rhe thay?!';

    _svgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _svgScale = CurvedAnimation(
      parent: _svgCtrl,
      curve: const ElasticOutCurve(0.65),
    );
    _svgFade = CurvedAnimation(parent: _svgCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear);

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _btnAnim = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _svgCtrl.forward().then((_) {
        if (!mounted) return;
        _shakeCtrl.forward().then((_) {
          if (!mounted) return;
          _startTypewriter();
        });
      });
    });
  }

  void _startTypewriter() async {
    await Future.delayed(const Duration(milliseconds: 150));
    for (int i = 1; i <= _fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 28));
      if (!mounted) return;
      setState(() => _visibleText = _fullText.substring(0, i));
    }
    if (!mounted) return;
    setState(() => _typewriterDone = true);
    _btnCtrl.forward();
  }

  @override
  void dispose() {
    _svgCtrl.dispose();
    _shakeCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  double _shakeOffset(double t) {
    return 14 * (1 - t) * sin(t * 3.0 * 2 * pi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D1235),
                  Color(0xFF150F3A),
                  Color(0xFF1A0A2E),
                ],
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _coral.withOpacity(0.07),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),
                _AnimatedFade(
                  animation: _svgFade,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _coral.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _coral.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('💀', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 6),
                        Text(
                          'Streak Broken',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: _coral,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: Listenable.merge([_svgCtrl, _shakeCtrl]),
                  builder: (_, __) {
                    final shakeX = _typewriterDone
                        ? 0.0
                        : _shakeOffset(_shakeAnim.value);
                    return Transform.translate(
                      offset: Offset(shakeX, 0),
                      child: Transform.scale(
                        scale: _svgScale.value,
                        child: SvgPicture.asset(
                          'assets/images/ustu_broken_streak.svg',
                          width: 200,
                          height: 200,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: AnimatedBuilder(
                    animation: _svgFade,
                    builder: (_, __) => Opacity(
                      opacity: _svgFade.value,
                      child: _TypewriterText(
                        visibleText: _visibleText,
                        fullText: _fullText,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                        ),
                        cursorColor: _coral,
                        textAlign: TextAlign.center,
                        done: _typewriterDone,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _AnimatedFade(
                  animation: _btnAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Ustu ne notice kar liya tha. Ab wapas aa gaye ho toh theek hai.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _AnimatedFade(
                  animation: _btnAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _coral.withOpacity(0.9),
                              _coral.withOpacity(0.7),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _coral.withOpacity(0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Theek hai yaar 😤 — wapas aa gaya',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERFECT SCORE CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _PerfectScoreContent extends StatefulWidget {
  final String name;
  final int correct;
  final int total;
  const _PerfectScoreContent({
    required this.name,
    required this.correct,
    required this.total,
  });

  @override
  State<_PerfectScoreContent> createState() => _PerfectScoreContentState();
}

class _PerfectScoreContentState extends State<_PerfectScoreContent>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFFFD700);

  late final AnimationController _svgCtrl;
  late final Animation<double> _svgScale;
  late final Animation<double> _svgFade;

  late final AnimationController _starsCtrl;
  late final List<Animation<double>> _starAnims;

  late final AnimationController _textCtrl;
  late final Animation<double> _textAnim;
  late final Animation<double> _subtextAnim;

  late final AnimationController _btnCtrl;
  late final Animation<double> _btnAnim;

  String _visibleSub = '';
  late final String _fullSub;
  bool _subDone = false;

  @override
  void initState() {
    super.initState();

    _fullSub =
        '${widget.correct}/${widget.total} — Zabardast performance! Ustu proud hai 🦉';

    _svgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _svgScale = CurvedAnimation(
      parent: _svgCtrl,
      curve: const ElasticOutCurve(0.7),
    );
    _svgFade = CurvedAnimation(parent: _svgCtrl, curve: Curves.easeOut);

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _starAnims = List.generate(
      5,
      (i) => CurvedAnimation(
        parent: _starsCtrl,
        curve: Interval(
          i * 0.15,
          (i * 0.15 + 0.5).clamp(0, 1),
          curve: const ElasticOutCurve(0.8),
        ),
      ),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textAnim = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic);
    _subtextAnim = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _btnAnim = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    _starsCtrl.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _svgCtrl.forward().then((_) {
        if (!mounted) return;
        _textCtrl.forward().then((_) {
          if (!mounted) return;
          _startSubTypewriter();
        });
      });
    });
  }

  void _startSubTypewriter() async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 1; i <= _fullSub.length; i++) {
      await Future.delayed(const Duration(milliseconds: 22));
      if (!mounted) return;
      setState(() => _visibleSub = _fullSub.substring(0, i));
    }
    if (!mounted) return;
    setState(() => _subDone = true);
    _btnCtrl.forward();
  }

  @override
  void dispose() {
    _svgCtrl.dispose();
    _starsCtrl.dispose();
    _textCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _subDone ? () => Navigator.of(context).pop() : null,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A0E2E),
                    Color(0xFF1A1464),
                    Color(0xFF0F0830),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _svgFade,
              builder: (_, __) => Positioned.fill(
                child: Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withOpacity(0.08 * _svgFade.value),
                          blurRadius: 90,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return AnimatedBuilder(
                        animation: _starAnims[i],
                        builder: (_, __) => Transform.scale(
                          scale: _starAnims[i].value,
                          child: Opacity(
                            opacity: _starAnims[i].value.clamp(0.0, 1.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text(
                                i == 2 ? '⭐' : '✨',
                                style: TextStyle(fontSize: i == 2 ? 28 : 20),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _svgCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _svgFade.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _svgScale.value,
                        child: SvgPicture.asset(
                          'assets/images/ustu_perfect_score.svg',
                          width: 200,
                          height: 200,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedBuilder(
                    animation: _textAnim,
                    builder: (_, __) => Opacity(
                      opacity: _textAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _textAnim.value)),
                        child: Text(
                          'Shaabaash ${widget.name}!!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: _gold,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            shadows: [Shadow(color: _gold, blurRadius: 16)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: AnimatedBuilder(
                      animation: _subtextAnim,
                      builder: (_, __) => Opacity(
                        opacity: _subtextAnim.value,
                        child: _TypewriterText(
                          visibleText: _visibleSub,
                          fullText: _fullSub,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 14,
                            height: 1.6,
                          ),
                          cursorColor: _gold,
                          textAlign: TextAlign.center,
                          done: _subDone,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  _AnimatedFade(
                    animation: _btnAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                      child: Text(
                        'Tap anywhere to continue',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.28),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  _AnimatedFade(
                    animation: _btnAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFBB00)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Shukriya Ustu 🦉 — Aage badhte hain',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Color(0xFF0A0E2E),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BAD SCORE CONTENT (score ≤ 6)
// ─────────────────────────────────────────────────────────────────────────────

class _BadScoreContent extends StatefulWidget {
  final String name;
  final int correct;
  final int total;
  const _BadScoreContent({
    required this.name,
    required this.correct,
    required this.total,
  });

  @override
  State<_BadScoreContent> createState() => _BadScoreContentState();
}

class _BadScoreContentState extends State<_BadScoreContent>
    with TickerProviderStateMixin {
  static const _coral = Color(0xFFFF6B6B);

  late final AnimationController _svgCtrl;
  late final Animation<double> _svgScale;
  late final Animation<double> _svgFade;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  String _visibleText = '';
  late final String _fullText;
  bool _typewriterDone = false;

  late final AnimationController _btnCtrl;
  late final Animation<double> _btnAnim;

  @override
  void initState() {
    super.initState();

    _fullText =
        'Wah ${widget.name} Wah, ${widget.correct}/${widget.total}?! Ustu disappointed hai lekin umeed hai!';

    _svgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _svgScale = CurvedAnimation(
      parent: _svgCtrl,
      curve: const ElasticOutCurve(0.65),
    );
    _svgFade = CurvedAnimation(parent: _svgCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear);

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _btnAnim = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _svgCtrl.forward().then((_) {
        if (!mounted) return;
        _shakeCtrl.forward().then((_) {
          if (!mounted) return;
          _startTypewriter();
        });
      });
    });
  }

  void _startTypewriter() async {
    await Future.delayed(const Duration(milliseconds: 150));
    for (int i = 1; i <= _fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 28));
      if (!mounted) return;
      setState(() => _visibleText = _fullText.substring(0, i));
    }
    if (!mounted) return;
    setState(() => _typewriterDone = true);
    _btnCtrl.forward();
  }

  @override
  void dispose() {
    _svgCtrl.dispose();
    _shakeCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  double _shakeOffset(double t) {
    return 14 * (1 - t) * sin(t * 3.0 * 2 * pi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D1235),
                  Color(0xFF150F3A),
                  Color(0xFF1A0A2E),
                ],
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _coral.withOpacity(0.07),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),
                _AnimatedFade(
                  animation: _svgFade,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _coral.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _coral.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('💀', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 6),
                        Text(
                          'Needs Improvement',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: _coral,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: Listenable.merge([_svgCtrl, _shakeCtrl]),
                  builder: (_, __) {
                    final shakeX = _typewriterDone
                        ? 0.0
                        : _shakeOffset(_shakeAnim.value);
                    return Transform.translate(
                      offset: Offset(shakeX, 0),
                      child: Transform.scale(
                        scale: _svgScale.value,
                        child: SvgPicture.asset(
                          'assets/images/ustu_bad_score.svg',
                          width: 200,
                          height: 200,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: AnimatedBuilder(
                    animation: _svgFade,
                    builder: (_, __) => Opacity(
                      opacity: _svgFade.value,
                      child: _TypewriterText(
                        visibleText: _visibleText,
                        fullText: _fullText,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                        ),
                        cursorColor: _coral,
                        textAlign: TextAlign.center,
                        done: _typewriterDone,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _AnimatedFade(
                  animation: _btnAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Ustu disappointed hai lekin umeed hai \n Agla attempt better hoga! 😤',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _AnimatedFade(
                  animation: _btnAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _coral.withOpacity(0.9),
                              _coral.withOpacity(0.7),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _coral.withOpacity(0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Dobara try karte hain',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEAK TOPIC OVERLAY CONTENT (once per day)
// ─────────────────────────────────────────────────────────────────────────────

class _WeakTopicOverlayContent extends StatefulWidget {
  final String topic;
  final int wrongCount;
  final String exam;
  final String section;
  final VoidCallback onPracticeNow;

  const _WeakTopicOverlayContent({
    required this.topic,
    required this.wrongCount,
    required this.exam,
    required this.section,
    required this.onPracticeNow,
  });

  @override
  State<_WeakTopicOverlayContent> createState() =>
      _WeakTopicOverlayContentState();
}

class _WeakTopicOverlayContentState extends State<_WeakTopicOverlayContent>
    with TickerProviderStateMixin {
  static const _primary = Color(0xFF6C63FF);
  static const _gold = Color(0xFFFFD700);

  late final AnimationController _svgCtrl;
  late final Animation<double> _svgScale;
  late final Animation<double> _svgFade;

  String _visibleText = '';
  late final String _fullText;
  bool _typewriterDone = false;

  late final AnimationController _btnCtrl;
  late final Animation<double> _btnAnim;

  @override
  void initState() {
    super.initState();

    _fullText =
        'Ustu ne notice kiya: "${widget.topic}" mein ${widget.wrongCount} ghaltiyan. 5 min do, sudhaar do!';

    _svgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _svgScale = CurvedAnimation(
      parent: _svgCtrl,
      curve: const ElasticOutCurve(0.7),
    );
    _svgFade = CurvedAnimation(parent: _svgCtrl, curve: Curves.easeOut);

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _btnAnim = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _svgCtrl.forward().then((_) {
        if (!mounted) return;
        _startTypewriter();
      });
    });
  }

  void _startTypewriter() async {
    await Future.delayed(const Duration(milliseconds: 150));
    for (int i = 1; i <= _fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      if (!mounted) return;
      setState(() => _visibleText = _fullText.substring(0, i));
    }
    if (!mounted) return;
    setState(() => _typewriterDone = true);
    _btnCtrl.forward();
  }

  @override
  void dispose() {
    _svgCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0E2E),
                  Color(0xFF1A1464),
                  Color(0xFF0F0830),
                ],
              ),
            ),
          ),
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withOpacity(0.08),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),
                _AnimatedFade(
                  animation: _svgFade,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _primary.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🦉', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 6),
                        Text(
                          'Weak Spot Alert',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: _primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _svgCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _svgScale.value,
                    child: Opacity(
                      opacity: _svgFade.value.clamp(0.0, 1.0),
                      child: SvgPicture.asset(
                        'assets/images/ustu_weak_topic.svg',
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: AnimatedBuilder(
                    animation: _svgFade,
                    builder: (_, __) => Opacity(
                      opacity: _svgFade.value,
                      child: _TypewriterText(
                        visibleText: _visibleText,
                        fullText: _fullText,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                        ),
                        cursorColor: _gold,
                        textAlign: TextAlign.center,
                        done: _typewriterDone,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _AnimatedFade(
                  animation: _btnAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Competitive dost ne shayad yeh topic pehle hi clear kar liya. Der mat karo!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _AnimatedFade(
                  animation: _btnAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Baad Mein',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                              widget.onPracticeNow();
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_primary, Color(0xFF9B94FF)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('⚡', style: TextStyle(fontSize: 14)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Practice Now',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TypewriterText extends StatefulWidget {
  final String visibleText;
  final String fullText;
  final TextStyle style;
  final Color cursorColor;
  final TextAlign textAlign;
  final bool done;

  const _TypewriterText({
    required this.visibleText,
    required this.fullText,
    required this.style,
    required this.cursorColor,
    required this.textAlign,
    required this.done,
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorCtrl;
  late final Animation<double> _cursorAnim;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    _cursorAnim = CurvedAnimation(parent: _cursorCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: _alignFromTextAlign(),
      children: [
        Text(
          widget.fullText,
          textAlign: widget.textAlign,
          style: widget.style.copyWith(color: Colors.transparent),
        ),
        AnimatedBuilder(
          animation: _cursorAnim,
          builder: (_, __) {
            final showCursor = !widget.done;
            return RichText(
              textAlign: widget.textAlign,
              text: TextSpan(
                children: [
                  TextSpan(text: widget.visibleText, style: widget.style),
                  if (showCursor)
                    TextSpan(
                      text: '|',
                      style: widget.style.copyWith(
                        color: widget.cursorColor.withOpacity(
                          _cursorAnim.value,
                        ),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  AlignmentGeometry _alignFromTextAlign() {
    switch (widget.textAlign) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }
}

class _AnimatedFade extends AnimatedWidget {
  final Widget child;
  const _AnimatedFade({
    required Animation<double> animation,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final anim = listenable as Animation<double>;
    return Opacity(opacity: anim.value.clamp(0.0, 1.0), child: child);
  }
}
