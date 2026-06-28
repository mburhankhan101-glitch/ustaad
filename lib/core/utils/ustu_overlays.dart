// ─────────────────────────────────────────────────────────────────────────────
// ustu_overlays.dart
//
// Four Ustu SVG overlay moments:
//   1. Ustu Broken Streak Overlay  → shown on HomeScreen when streak is broken (once per day)
//   2. Ustu Perfect Score Overlay  → shown on ResultScreen when score ≥ 7
//   3. Ustu Bad Score Overlay      → shown on ResultScreen when score ≤ 6
//   4. Ustu Weak Topic Overlay     → shown on HomeScreen for the worst weak topic (once per day)
//
// HOW TO USE:
//   UstuOverlays.showBrokenStreak(context, name: 'Burhan');
//   UstuOverlays.showPerfectScore(context, name: 'Burhan', correct: 8, total: 10);
//   UstuOverlays.showBadScore(context, name: 'Burhan', correct: 4, total: 10);
//   UstuOverlays.showWeakTopicOverlay(context, topic: 'Trigonometry', wrongCount: 5, exam: 'FAST-NU', section: 'Advanced Maths', onPracticeNow: () { ... });
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UstuOverlays {
  UstuOverlays._();

  // ── Public entry-points ─────────────────────────────────────────────────────

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
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));

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
    return 10 * (1 - t) * _sineWave(t, frequency: 3.0);
  }

  double _sineWave(double t, {required double frequency}) {
    return (t * frequency * 3.14159 * 2).let((radians) => _sin(radians));
  }

  double _sin(double x) {
    const pi = 3.14159265358979;
    x = x % (2 * pi);
    if (x > pi) x -= 2 * pi;
    return (16 * x * (pi - x)) / (5 * pi * pi - 4 * x * (pi - x));
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
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));

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
    return 10 * (1 - t) * _sineWave(t, frequency: 3.0);
  }

  double _sineWave(double t, {required double frequency}) {
    return (t * frequency * 3.14159 * 2).let((radians) => _sin(radians));
  }

  double _sin(double x) {
    const pi = 3.14159265358979;
    x = x % (2 * pi);
    if (x > pi) x -= 2 * pi;
    return (16 * x * (pi - x)) / (5 * pi * pi - 4 * x * (pi - x));
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

extension _Let<T> on T {
  R let<R>(R Function(T it) block) => block(this);
}
