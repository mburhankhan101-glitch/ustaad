import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/services/firestore_service.dart';
import 'package:ustaad/providers/progress_provider.dart';

// ─── Colors — swap with UstaadColors from app_theme.dart ─────────────────────
class _C {
  static const bg1 = Color(0xFF0A0E2E);
  static const bg2 = Color(0xFF1A1464);
  static const bg3 = Color(0xFF6C63FF);
  static const primary = Color(0xFF6C63FF);
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFFF6B6B);
  static const gold = Color(0xFFFFD700);
}

// ─────────────────────────────────────────────────────────────────────────────
// ResultScreen
//
// Navigate here from QuizScreen when all 10 questions are answered:
//

// ─────────────────────────────────────────────────────────────────────────────

class ResultScreen extends StatefulWidget {
  final List<Question> questions;
  final List<int?> selectedAnswers;
  final String exam;
  final String section;

  const ResultScreen({
    super.key,
    required this.questions,
    required this.selectedAnswers,
    required this.exam,
    required this.section,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  // ── Computed scores ─────────────────────────────────────────────────────────
  late final int _correct;
  late final int _wrong;
  late final int _skipped;
  late final int _total;
  late final int _accuracy;
  late final int _tier; // 0=needs work  1=good  2=excellent
  late final Color _ringColor;

  // ── Animation controllers ────────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _heroAnim;
  late final Animation<double> _statsAnim;
  late final Animation<double> _breakdownAnim;
  late final Animation<double> _msgAnim;
  late final Animation<double> _btnsAnim;

  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  late final AnimationController _countCtrl;
  late final Animation<int> _countAnim;

  // One controller per star so they pop independently
  late final AnimationController _s1Ctrl;
  late final AnimationController _s2Ctrl;
  late final AnimationController _s3Ctrl;
  late final Animation<double> _s1Anim;
  late final Animation<double> _s2Anim;
  late final Animation<double> _s3Anim;

  @override
  void initState() {
    super.initState();
    _computeScore();
    _setupAnimations();
    _saveUserProgress();
    HapticFeedback.mediumImpact();

    // Staggered entrance
    _entranceCtrl.forward();

    // Ring + count start 200ms after entrance
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _ringCtrl.forward();
      _countCtrl.forward();
    });

    // Stars pop after ring finishes (~900ms)
    if (_tier >= 0) {
      Future.delayed(const Duration(milliseconds: 950), () {
        if (mounted) _s1Ctrl.forward();
      });
    }
    if (_tier >= 1) {
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) _s2Ctrl.forward();
      });
    }
    if (_tier >= 2) {
      Future.delayed(const Duration(milliseconds: 1250), () {
        if (mounted) _s3Ctrl.forward();
      });
    }
  }

  void _saveUserProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("🔴 USTAAD ERROR: No user logged in.");
      return;
    }

    // Await the save so it finishes before the user navigates away
    await FirestoreService().saveProgress(
      uid: user.uid,
      exam: widget.exam,
      section: widget.section,
      score: _correct,
      totalSessionQuestions: _total, // Usually 10
      totalPoolSize: 75, // Hardcoded to 75 for now based on your DB
    );

    // Update streak — runs after every completed quiz session
    await updateStreak();
  }

  void _computeScore() {
    _total = widget.questions.length;
    int correct = 0, wrong = 0, skipped = 0;

    for (int i = 0; i < _total; i++) {
      final sel = widget.selectedAnswers[i];
      if (sel == null) {
        skipped++;
      } else if (sel == widget.questions[i].correctIndex) {
        correct++;
      } else {
        wrong++;
      }
    }

    _correct = correct;
    _wrong = wrong;
    _skipped = skipped;
    _accuracy = _total > 0 ? ((_correct / _total) * 100).round() : 0;
    _tier = _correct >= 8
        ? 2
        : _correct >= 5
        ? 1
        : 0;
    _ringColor = _tier == 2
        ? _C.success
        : _tier == 1
        ? _C.primary
        : _C.error;
  }

  void _setupAnimations() {
    // ── Entrance stagger ──────────────────────────────────────────────────────
    _entranceCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    Animation<double> _s(double begin, double end) => CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );

    _heroAnim = _s(0.00, 0.50);
    _statsAnim = _s(0.15, 0.65);
    _breakdownAnim = _s(0.28, 0.78);
    _msgAnim = _s(0.40, 0.90);
    _btnsAnim = _s(0.52, 1.00);

    // ── Ring fill ─────────────────────────────────────────────────────────────
    _ringCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _ringAnim = CurvedAnimation(
      parent: _ringCtrl,
      curve: const ElasticOutCurve(0.8),
    );

    // ── Score count-up ────────────────────────────────────────────────────────
    _countCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _countAnim = IntTween(
      begin: 0,
      end: _correct,
    ).animate(CurvedAnimation(parent: _countCtrl, curve: Curves.easeOut));

    // ── Stars ─────────────────────────────────────────────────────────────────
    AnimationController _starCtrl() => AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    Animation<double> _starAnim(AnimationController c) =>
        CurvedAnimation(parent: c, curve: const ElasticOutCurve(0.6));

    _s1Ctrl = _starCtrl();
    _s1Anim = _starAnim(_s1Ctrl);
    _s2Ctrl = _starCtrl();
    _s2Anim = _starAnim(_s2Ctrl);
    _s3Ctrl = _starCtrl();
    _s3Anim = _starAnim(_s3Ctrl);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _ringCtrl.dispose();
    _countCtrl.dispose();
    _s1Ctrl.dispose();
    _s2Ctrl.dispose();
    _s3Ctrl.dispose();
    super.dispose();
  }

  // ── Content helpers ──────────────────────────────────────────────────────────

  String get _title =>
      const ['Needs More Practice', 'Good Effort!', 'Excellent Work!'][_tier];

  String get _subtitle => const [
    "Don't give up — every attempt makes you stronger.",
    "You're improving. A bit more practice and you'll ace it.",
    "You're in the top 20% for this section.",
  ][_tier];

  String get _ustuMsg {
    if (_tier == 2)
      return "Outstanding! $_correct/10 is excellent. You've mastered this section — try the next one!";
    if (_tier == 1)
      return "Solid work! You missed $_wrong question${_wrong > 1 ? 's' : ''}. Try again and focus on those weak spots.";
    return "You got $_correct right — that's a start! Review the concepts for the $_wrong wrong answers before retrying.";
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg1,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_C.bg1, _C.bg2, _C.bg3],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 24),
                  _buildHero(),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 18),
                  _buildBreakdown(),
                  const SizedBox(height: 18),
                  _buildUstuMessage(),
                  const SizedBox(height: 20),
                  _buildButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return _fadeUp(
      _heroAnim,
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${widget.section.toUpperCase()} · ${widget.exam}',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 38),
          ],
        ),
      ),
    );
  }

  // ── Hero — ring + stars + title ──────────────────────────────────────────────

  Widget _buildHero() {
    return _fadeUp(
      _heroAnim,
      Column(
        children: [
          // Score ring — larger with more spacing
          SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated ring
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (_, __) {
                    final progress = (_correct / _total) * _ringAnim.value;
                    return CustomPaint(
                      size: const Size(170, 170),
                      painter: _RingPainter(
                        progress: progress,
                        ringColor: _ringColor,
                        strokeWidth: 12,
                        gap: 20, // spacing between ring and content
                      ),
                    );
                  },
                ),
                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _countAnim,
                      builder: (_, __) => Text(
                        '${_countAnim.value}/$_total',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SCORE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStar(_s1Anim, _tier >= 1),
              const SizedBox(width: 8),
              _buildStar(_s2Anim, _tier >= 2),
              const SizedBox(width: 8),
              _buildStar(_s3Anim, _tier >= 3),
            ],
          ),

          const SizedBox(height: 14),

          // Title
          Text(
            _title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStar(Animation<double> anim, bool earned) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Transform.scale(
        scale: earned ? anim.value : 1.0,
        child: Text(
          '⭐',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white.withOpacity(earned ? 1.0 : 0.15),
          ),
        ),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return _fadeUp(
      _statsAnim,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            _statCard(_correct.toString(), 'CORRECT', _C.success),
            const SizedBox(width: 10),
            _statCard(_wrong.toString(), 'WRONG', _C.error),
            const SizedBox(width: 10),
            _statCard(_skipped.toString(), 'SKIPPED', _C.gold),
            const SizedBox(width: 10),
            _statCard('$_accuracy%', 'ACCURACY', Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String number, String label, Color numColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: numColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.45),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Breakdown bars ────────────────────────────────────────────────────────────

  Widget _buildBreakdown() {
    return _fadeUp(
      _breakdownAnim,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERFORMANCE BREAKDOWN',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            _barRow('✅', 'Correct', _correct, _C.success),
            const SizedBox(height: 10),
            _barRow('❌', 'Wrong', _wrong, _C.error),
            const SizedBox(height: 10),
            _barRow('⏭', 'Skipped', _skipped, _C.gold),
          ],
        ),
      ),
    );
  }

  Widget _barRow(String icon, String label, int value, Color color) {
    final pct = _total > 0 ? value / _total : 0.0;
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 10),
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.65),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AnimatedBuilder(
              animation: _breakdownAnim,
              builder: (_, __) => LinearProgressIndicator(
                value: pct * _breakdownAnim.value,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 20,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── Ustu message ──────────────────────────────────────────────────────────────

  Widget _buildUstuMessage() {
    return _fadeUp(
      _msgAnim,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.primary.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🦉', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ustu says',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ustuMsg,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFFC8C4FF),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────────

  Widget _buildButtons() {
    return _fadeUp(
      _btnsAnim,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            // Home button
            GestureDetector(
              onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                alignment: Alignment.center,
                child: const Text('🏠', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            // Retry button
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Pop back to QuizScreen — it will re-fetch and shuffle questions
                  Navigator.pop(context);
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _C.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔄', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text(
                        'Try Again',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 14,
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
    );
  }

  // ── Animation helper ──────────────────────────────────────────────────────────

  Widget _fadeUp(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring painter — draws the animated score circle
// strokeWidth and gap are separate so the ring has clear breathing room
// between the stroke edge and the center content
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final double strokeWidth;
  final double gap; // extra spacing — not used by painter but documents intent

  const _RingPainter({
    required this.progress,
    required this.ringColor,
    this.strokeWidth = 12,
    this.gap = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2) - 4;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withOpacity(0.08),
    );

    // Filled arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        2 * math.pi * progress, // sweep by progress
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = ringColor,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
