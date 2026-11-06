import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/services/firestore_service.dart';
import 'package:ustaad/providers/progress_provider.dart';
import 'package:ustaad/core/utils/ustu_overlays.dart';

class _C {
  static const bg1 = Color(0xFF0A0E2E);
  static const bg2 = Color(0xFF1A1464);
  static const bg3 = Color(0xFF6C63FF);
  static const primary = Color(0xFF6C63FF);
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFFF6B6B);
}

/// How well they did, as a share of what they attempted.
///
/// Both of these were absolute counts until a four-question weak-topic
/// drill answered perfectly scored 4, fell under the "<= 6" branch, and was
/// congratulated with the bad-score overlay. Every threshold here is a
/// percentage so that a quiz of any length is judged on its own terms.

/// Ring colour band: 2 is the best, 0 the worst.
int scoreTier(int accuracyPercent) {
  if (accuracyPercent >= 80) return 2;
  if (accuracyPercent >= 50) return 1;
  return 0;
}

/// Whether Ustu congratulates them rather than commiserating.
///
/// [attempted] is the number of questions answered in THIS sitting; zero
/// means everything was carried over from a resumed quiz, and Ustu should
/// say nothing at all rather than judge a session that did not happen.
bool celebratesScore({required int attempted, required int accuracyPercent}) =>
    attempted > 0 && accuracyPercent >= 70;

bool commiseratesScore({
  required int attempted,
  required int accuracyPercent,
}) => attempted > 0 && accuracyPercent < 70;

class ResultScreen extends StatefulWidget {
  final List<Question> questions;
  final List<int?> selectedAnswers;
  final String exam;
  final String section;
  final int poolSize;
  final bool isWeakTopicPractice; // Bug 2 flag

  const ResultScreen({
    super.key,
    required this.questions,
    required this.selectedAnswers,
    required this.exam,
    required this.section,
    required this.poolSize,
    this.isWeakTopicPractice = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late final int _correct;
  late final int _wrong;
  late final int _total;
  late final int _accuracy;

  /// Counts by default; percentages on tap.
  bool _showPercent = false;
  late final int _tier;
  late final Color _ringColor;

  late final Map<String, int> _weakTopics;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _heroAnim;
  late final Animation<double> _statsAnim;
  late final Animation<double> _breakdownAnim;
  late final Animation<double> _weakAnim;
  late final Animation<double> _btnsAnim;

  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  late final AnimationController _countCtrl;
  late final Animation<int> _countAnim;

  late final AnimationController _s1Ctrl;
  late final AnimationController _s2Ctrl;
  late final AnimationController _s3Ctrl;
  late final Animation<double> _s1Anim;
  late final Animation<double> _s2Anim;
  late final Animation<double> _s3Anim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _computeScore(); // ← initialises all score fields
    _setupAnimations();
    _saveUserProgress();
    _begin();
  }

  /// Runs the entrance, but only once the student can see it.
  ///
  /// A good or bad score raises a full-screen overlay over this page. The
  /// animations used to start in initState regardless, so the ring filled,
  /// the stars landed and the bar grew behind that overlay — and the student
  /// dismissed it to find a finished, static screen. Exactly the bug
  /// OverlayQueue was written for, except here it is the page underneath
  /// rather than a second overlay.
  ///
  /// So the overlay is awaited first. Its future completes when the sheet is
  /// dismissed, and the entrance starts then.
  Future<void> _begin() async {
    final celebrate = celebratesScore(
      attempted: _total,
      accuracyPercent: _accuracy,
    );
    // _total == 0 means every question was carried over from a resumed quiz,
    // so there is nothing to say either way.
    final commiserate = commiseratesScore(
      attempted: _total,
      accuracyPercent: _accuracy,
    );

    if (celebrate || commiserate) {
      // The overlay needs this route mounted in the tree before it can sit
      // on top of it.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final name = _firstName();
      if (celebrate) {
        await UstuOverlays.showPerfectScore(
          context,
          name: name,
          correct: _correct,
          total: _total,
        );
      } else {
        await UstuOverlays.showBadScore(
          context,
          name: name,
          correct: _correct,
          total: _total,
        );
      }
      if (!mounted) return;
    }

    _runEntrance();
  }

  void _runEntrance() {
    HapticFeedback.mediumImpact();
    _entranceCtrl.forward();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _ringCtrl.forward();
      _countCtrl.forward();
    });

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

  String _firstName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Student';
    final displayName = user.displayName ?? '';
    if (displayName.trim().isEmpty) return 'Student';
    return displayName.trim().split(' ').first;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FULL implementation – no placeholders
  // ──────────────────────────────────────────────────────────────────────────
  void _computeScore() {
    final int rawTotal = widget.questions.length;
    int correct = 0, wrong = 0;
    final Map<String, int> weakMap = {};
    int notAttempted = 0;

    for (int i = 0; i < rawTotal; i++) {
      final sel = widget.selectedAnswers[i];
      if (sel == -2) {
        notAttempted++;
        continue;
      } else if (sel == null) {
        notAttempted++;
        continue;
      } else if (sel == widget.questions[i].correctIndex) {
        correct++;
      } else {
        wrong++;
        final topic = widget.questions[i].topic.trim();
        if (topic.isNotEmpty && topic != 'General') {
          weakMap[topic] = (weakMap[topic] ?? 0) + 1;
        }
      }
    }

    _total = rawTotal - notAttempted;
    _correct = correct;
    _wrong = wrong;
    _accuracy = _total > 0 ? ((_correct / _total) * 100).round() : 0;
    // Share of what they actually attempted, not a raw count. These were
    // _correct >= 8 and >= 5, which silently assumed every quiz is ten
    // questions long. A four-question weak-topic drill answered perfectly
    // scored 4, landed in the bottom tier, and got the red ring.
    _tier = scoreTier(_accuracy);
    _ringColor = _tier == 2
        ? _C.success
        : _tier == 1
        ? _C.primary
        : _C.error;

    final sorted = weakMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _weakTopics = Map.fromEntries(sorted);
  }

  void _saveUserProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Started first, not queued behind the saves below. Those are
    // transactions, which each need a server round trip and fail outright
    // offline, and the streak used to wait for both before it even began:
    // several seconds on a slow connection, long enough to be back on Home
    // before the streak had changed. They write different fields, so running
    // side by side is safe.
    final streak = updateStreak();

    await FirestoreService().saveProgress(
      uid: user.uid,
      exam: widget.exam,
      section: widget.section,
      score: _correct,
      totalSessionQuestions: _total,
      totalPoolSize: widget.poolSize,
    );

    // ✅ Bug 2 fix: skip weak‑topic write when this is a practice session
    if (_weakTopics.isNotEmpty && !widget.isWeakTopicPractice) {
      await FirestoreService().saveWeakTopics(
        uid: user.uid,
        sessionWeakTopics: _weakTopics,
        exam: widget.exam,
        section: widget.section,
      );
    }

    // Which questions, not just which topics. Written on every session,
    // weak-topic drills included, because getting a drilled question right
    // is exactly the signal that should eventually retire its flashcard.
    final wrongQs = <Question>[];
    final rightIds = <String>[];
    for (var i = 0; i < widget.questions.length; i++) {
      final sel = widget.selectedAnswers[i];
      if (sel == null || sel == -2) continue; // unreached, or an older sitting
      if (sel == widget.questions[i].correctIndex) {
        rightIds.add(widget.questions[i].id);
      } else {
        wrongQs.add(widget.questions[i]);
      }
    }
    await FirestoreService().recordMistakes(
      uid: user.uid,
      wrong: wrongQs,
      rightIds: rightIds,
    );

    await streak;
  }

  void _setupAnimations() {
    _entranceCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    Animation<double> _s(double begin, double end) => CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );

    _heroAnim = _s(0.00, 0.50);
    _statsAnim = _s(0.15, 0.65);
    _breakdownAnim = _s(0.28, 0.78);
    _weakAnim = _s(0.38, 0.88);
    _btnsAnim = _s(0.55, 1.00);

    _ringCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _ringAnim = CurvedAnimation(
      parent: _ringCtrl,
      curve: const ElasticOutCurve(0.8),
    );

    _countCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _countAnim = IntTween(
      begin: 0,
      end: _correct,
    ).animate(CurvedAnimation(parent: _countCtrl, curve: Curves.easeOut));

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
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _entranceCtrl.dispose();
    _ringCtrl.dispose();
    _countCtrl.dispose();
    _s1Ctrl.dispose();
    _s2Ctrl.dispose();
    _s3Ctrl.dispose();
    super.dispose();
  }

  String get _title =>
      const ['Needs More Practice', 'Good Effort!', 'Excellent Work!'][_tier];

  void _goHome() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: _C.bg1,
      body: Column(
        children: [
          if (isWeb) _buildWebNavBar(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.bg1, _C.bg2, _C.bg3],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: 32 + MediaQuery.of(context).viewPadding.bottom,
                  ),
                  child: isWeb ? _buildWebContent() : _buildMobileContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    return Column(
      children: [
        _buildTopBar(),
        const SizedBox(height: 24),
        _buildHero(),
        const SizedBox(height: 20),
        _buildScoreStrip(),
        if (_weakTopics.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildWeakTopicsSection(),
        ],
        const SizedBox(height: 22),
        _buildButtons(),
      ],
    );
  }

  Widget _buildWebContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildHero(),
                const SizedBox(height: 24),
                _buildScoreStrip(),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                if (_weakTopics.isNotEmpty) _buildWeakTopicsSection(),
                if (_weakTopics.isNotEmpty) const SizedBox(height: 24),
                _buildWebButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebNavBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goHome,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${widget.section.toUpperCase()} · ${widget.exam}',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildWebButtons() {
    return _fadeUp(
      _btnsAnim,
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _goHome,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _C.primary,
                  borderRadius: BorderRadius.circular(14),
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
    );
  }

  Widget _buildTopBar() {
    return _fadeUp(
      _heroAnim,
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: _goHome,
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

  Widget _buildHero() {
    return _fadeUp(
      _heroAnim,
      Column(
        children: [
          SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
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
                        gap: 20,
                      ),
                    );
                  },
                ),
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

  /// One animated bar instead of four boxes and three more bars.
  ///
  /// The old screen showed the same three numbers twice: stat cards reading
  /// Correct 2, Wrong 8, Accuracy 20%, then a breakdown repeating Correct 2
  /// and Wrong 8 underneath. The ring above already says 2/10, which is the
  /// same fact a third time.
  ///
  /// So this is the one thing those were all circling: the shape of the
  /// attempt. A bar that fills to show how much of it went right, with the
  /// counts tallying up alongside it. Tapping swaps counts for percentages,
  /// because a student comparing attempts thinks in percentages while one
  /// reviewing this attempt thinks in questions.
  Widget _buildScoreStrip() {
    return _fadeUp(
      _statsAnim,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showPercent = !_showPercent);
          },
          child: AnimatedBuilder(
            animation: _breakdownAnim,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(
                _breakdownAnim.value.clamp(0.0, 1.0),
              );
              final shownCorrect = (_correct * t).round();
              final shownWrong = (_wrong * t).round();
              final correctShare = _total > 0 ? _correct / _total : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The bar. Correct grows from the left, wrong fills the
                  // rest, so the split itself is the headline.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          if (_correct > 0)
                            Expanded(
                              flex: (correctShare * 1000 * t).round() + 1,
                              child: Container(color: _C.success),
                            ),
                          if (_wrong > 0)
                            Expanded(
                              flex:
                                  (((1 - correctShare) * 1000 * t).round() + 1),
                              child: Container(color: _C.error),
                            ),
                          // The unfilled remainder while the bar animates in.
                          if (t < 1)
                            Expanded(
                              flex: ((1 - t) * 1000).round() + 1,
                              child: Container(
                                color: Colors.white.withOpacity(0.07),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _tally(
                        _C.success,
                        'Right',
                        _showPercent
                            ? '${_total > 0 ? ((_correct / _total) * 100).round() : 0}%'
                            : '$shownCorrect',
                      ),
                      const SizedBox(width: 22),
                      _tally(
                        _C.error,
                        'Wrong',
                        _showPercent
                            ? '${_total > 0 ? ((_wrong / _total) * 100).round() : 0}%'
                            : '$shownWrong',
                      ),
                      const Spacer(),
                      Text(
                        _showPercent ? 'tap for counts' : 'tap for %',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.28),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tally(Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeakTopicsSection() {
    return _fadeUp(
      _weakAnim,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'TOPICS TO REVIEW',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _C.primary.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🦉', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        'Ustu will remind you',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._weakTopics.entries.map(
              (entry) => _topicChip(entry.key, entry.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topicChip(String topic, int wrongCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _C.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.error.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              topic,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _C.error.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$wrongCount wrong',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: _C.error,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return _fadeUp(
      _btnsAnim,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            GestureDetector(
              onTap: _goHome,
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
            Expanded(
              child: GestureDetector(
                onTap: _goHome,
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final double strokeWidth;
  final double gap;

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

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withOpacity(0.08),
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
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
