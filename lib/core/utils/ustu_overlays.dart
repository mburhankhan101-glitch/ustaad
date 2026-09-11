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
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

class UstuOverlays {
  UstuOverlays._();

  // ── Public entry-points ─────────────────────────────────────────────────────

  static void showStreakProgressMap(
    BuildContext context, {
    required int currentStreak,
    bool isCatchUp = false,
  }) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
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
      pageBuilder: (_, __, ___) => _StreakProgressMapContent(
        currentStreak: currentStreak,
        isCatchUp: isCatchUp,
      ),
    );
  }

  static void showBrokenStreak(BuildContext context, {required String name}) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
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
  }

  static void showPerfectScore(
    BuildContext context, {
    required String name,
    required int correct,
    required int total,
  }) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
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
  }

  static void showBadScore(
    BuildContext context, {
    required String name,
    required int correct,
    required int total,
  }) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
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
  }

  static void showWeakTopicOverlay(
    BuildContext context, {
    required String topic,
    required int wrongCount,
    required String exam,
    required String section,
    required VoidCallback onPracticeNow,
  }) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STREAK PROGRESS MAP CONTENT (Curved Game Path)
// ─────────────────────────────────────────────────────────────────────────────

class _StreakProgressMapContent extends StatefulWidget {
  final int currentStreak;
  final bool isCatchUp;

  const _StreakProgressMapContent({
    required this.currentStreak,
    required this.isCatchUp,
  });

  @override
  State<_StreakProgressMapContent> createState() =>
      _StreakProgressMapContentState();
}

class _StreakProgressMapContentState extends State<_StreakProgressMapContent>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFFFD700);
  static const _primary = Color(0xFF6C63FF);

  late int _displayStreak;
  bool _showStageTwo = false;
  bool _animationComplete = false;

  late final AnimationController _btnCtrl;
  late final Animation<double> _btnAnim;

  late final int _stageStartDay;
  late final int _stageEndDay;

  @override
  void initState() {
    super.initState();

    _showStageTwo = widget.currentStreak >= 8;

    int stageMultiplier = ((widget.currentStreak - 1) ~/ 7);
    if (widget.currentStreak == 0) stageMultiplier = 0;

    _stageStartDay = (stageMultiplier * 7) + 1;
    _stageEndDay = _stageStartDay + 6;

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _btnAnim = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    if (widget.isCatchUp) {
      _displayStreak = (_stageStartDay - 1).clamp(0, 999);
      if (_displayStreak == widget.currentStreak) {
        _displayStreak = widget.currentStreak - 1;
      }

      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _displayStreak = widget.currentStreak);
          _triggerCompletionDelay(800);
        }
      });
    } else {
      _displayStreak = (widget.currentStreak - 1).clamp(0, 999);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _displayStreak = widget.currentStreak);
          _triggerCompletionDelay(1200);
        }
      });
    }
  }

  void _triggerCompletionDelay(int milliseconds) {
    Future.delayed(Duration(milliseconds: milliseconds), () {
      if (mounted) {
        setState(() => _animationComplete = true);
        _btnCtrl.forward();
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void dispose() {
    _btnCtrl.dispose();
    super.dispose();
  }

  double _getCurveX(double t, double width) {
    final double center = width / 2;
    final double amplitude = width * 0.35;
    return center + amplitude * sin(t * 2 * pi);
  }

  double _getCurveY(double t, double height) {
    return t * height;
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> bgColors = _showStageTwo
        ? [const Color(0xFF1A1464), const Color(0xFF0F0830)]
        : [const Color(0xFF0A0E2E), const Color(0xFF1A1464)];

    final screenHeight = MediaQuery.of(context).size.height;
    final double mapTopPadding = screenHeight * 0.22;
    final double mapBottomPadding = screenHeight * 0.30;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
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

          if (_showStageTwo)
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withOpacity(0.05),
                ),
              ),
            ),

          Positioned.fill(
            top: mapTopPadding,
            bottom: mapBottomPadding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double W = constraints.maxWidth;
                final double H = constraints.maxHeight;

                double relativeOwlStreak = (_displayStreak - _stageStartDay)
                    .toDouble();
                if (relativeOwlStreak < -1) relativeOwlStreak = -1;
                if (relativeOwlStreak > 6) relativeOwlStreak = 6;

                final double tOwl = relativeOwlStreak / 6.0;
                final double owlX = _getCurveX(tOwl, W);
                final double owlY = _getCurveY(tOwl, H);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _CurvedDashedPathPainter()),
                    ),

                    for (int i = 0; i <= 6; i++) ...[
                      Builder(
                        builder: (context) {
                          final double t = i / 6.0;
                          final double nodeX = _getCurveX(t, W);
                          final double nodeY = _getCurveY(t, H);
                          final int dayNumber = _stageStartDay + i;
                          final bool isReached = dayNumber <= _displayStreak;
                          final bool isCurrent = dayNumber == _displayStreak;

                          final double nodeSize = isCurrent ? 58.0 : 48.0;

                          return Positioned(
                            left: nodeX - (nodeSize / 2),
                            top: nodeY - (nodeSize / 2),
                            child: _buildNumberedNode(
                              dayNumber: dayNumber,
                              isReached: isReached,
                              isCurrent: isCurrent,
                              size: nodeSize,
                            ),
                          );
                        },
                      ),
                    ],

                    AnimatedPositioned(
                      duration: widget.isCatchUp
                          ? const Duration(milliseconds: 800)
                          : const Duration(milliseconds: 1200),
                      curve: Curves.easeInOutCubic,
                      left: owlX - 45,
                      top: owlY - 65,
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: Lottie.asset(
                          'assets/images/ustu_owl.json',
                          fit: BoxFit.contain,
                        ),
                      ),
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
                      _showStageTwo ? 'PHASE 2 UNLOCKED' : 'STREAK MAP',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: _showStageTwo ? _gold : _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.currentStreak} Days Strong 🔥',
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
            child: _AnimatedFade(
              animation: _btnAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_animationComplete && !widget.isCatchUp)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          'Ek aur din, ek aur qadam. Keep it up! 🚀',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.8),
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
                              color: _primary.withOpacity(0.35),
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
        ],
      ),
    );
  }

  Widget _buildNumberedNode({
    required int dayNumber,
    required bool isReached,
    required bool isCurrent,
    required double size,
  }) {
    final Color bgColor = isReached ? _gold : const Color(0xFF1A1A2E);
    final Color borderColor = isReached ? _gold : Colors.white.withOpacity(0.2);
    final Color textColor = isReached
        ? Colors.black
        : Colors.white.withOpacity(0.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrent ? Colors.white : borderColor,
          width: isCurrent ? 4 : 3,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _gold.withOpacity(0.6),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ]
            : (isReached
                  ? [BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 8)]
                  : []),
      ),
      alignment: Alignment.center,
      child: Text(
        '$dayNumber',
        style: TextStyle(
          fontFamily: 'Poppins',
          color: textColor,
          fontSize: isCurrent ? 24 : 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CurvedDashedPathPainter extends CustomPainter {
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
      ..color = Colors.white.withOpacity(0.2)
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
