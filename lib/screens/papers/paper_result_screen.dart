// lib/screens/papers/paper_result_screen.dart
// Style C – Full-width web dashboard with navbar & two columns

import 'package:flutter/material.dart';
import '../../models/paper_model.dart';
import '../../providers/progress_provider.dart';

class PaperResultScreen extends StatefulWidget {
  final PaperResult result;
  const PaperResultScreen({super.key, required this.result});

  @override
  State<PaperResultScreen> createState() => _PaperResultScreenState();
}

class _PaperResultScreenState extends State<PaperResultScreen> {
  /// Counts by default, percentages on tap — the same gesture as the
  /// quiz result screen, so the two behave alike.
  bool _showPercent = false;
  @override
  void initState() {
    super.initState();
    updateStreak();
  }

  Color get _accentColor {
    switch (widget.result.examType) {
      case ExamType.fastNU:
        return const Color(0xFF6C63FF);
      case ExamType.nustNET:
        return const Color(0xFF4CAF50);
      case ExamType.nts:
        return const Color(0xFFFF6B6B);
      case ExamType.mdcat:
        return const Color(0xFF00BFA5);
      case ExamType.numsMdcat:
        return const Color(0xFF2196F3);
    }
  }

  Color get _accentLight {
    switch (widget.result.examType) {
      case ExamType.fastNU:
        return const Color(0xFF9B8FFF);
      case ExamType.nustNET:
        return const Color(0xFF81C784);
      case ExamType.nts:
        return const Color(0xFFFF9999);
      case ExamType.mdcat:
        return const Color(0xFF64FFDA);
      case ExamType.numsMdcat:
        return const Color(0xFF90CAF9);
    }
  }

  double get _maxMarks => PaperConfigs.maxMarks(widget.result.examType);
  bool get _hasNegative => widget.result.examType == ExamType.fastNU;

  String _formatTime() {
    final s = widget.result.secondsTaken;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m ${sec}s';
    return '${m}m ${sec}s';
  }

  String get _feedbackEmoji {
    final acc = widget.result.accuracyPercent;
    if (acc >= 80) return '🦉🌟';
    if (acc >= 60) return '🦉👍';
    return '🦉💪';
  }

  String get _feedbackText {
    final acc = widget.result.accuracyPercent;
    if (acc >= 80) return 'Outstanding performance!';
    if (acc >= 60) return 'Good effort, keep going!';
    return 'Keep practising — Ustu believes in you!';
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E2E),
      body: Column(
        children: [
          // Web top navbar
          if (isWeb) _buildWebNavBar(),
          // Content area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A0E2E),
                    Color(0xFF1A1464),
                    Color(0xFF2A1E80),
                  ],
                ),
              ),
              child: isWeb
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: _buildWebContent(),
                    )
                  : SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                        child: _buildMobileContent(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Web navbar ────────────────────────────────────────────────────────
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
            onTap: () => Navigator.pop(context),
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
            widget.result.examLabel,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Mobile content (unchanged) ────────────────────────────────────────
  Widget _buildMobileContent() {
    return Column(
      children: [
        _buildOwlAndTitle(),
        const SizedBox(height: 20),
        _buildScoreCard(),
        const SizedBox(height: 16),
        _buildSectionBreakdown(),
        const SizedBox(height: 24),
        _buildButtons(),
      ],
    );
  }

  // ── Web content: two-column layout ────────────────────────────────────
  Widget _buildWebContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOwlAndTitle(),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: score card + stats
            Expanded(flex: 3, child: _buildScoreCard()),
            const SizedBox(width: 32),
            // Right column: section breakdown + buttons
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildSectionBreakdown(),
                  const SizedBox(height: 24),
                  _buildButtons(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Shared widgets (slightly adjusted for reusability) ────────────────

  Widget _buildOwlAndTitle() {
    return Column(
      children: [
        Text(_feedbackEmoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 10),
        const Text(
          'Paper Complete!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.result.examLabel} · ${_formatTime()}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          _feedbackText,
          style: TextStyle(
            color: _accentLight,
            fontSize: 11,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  /// The score, in the same language the quiz result screen now speaks.
  ///
  /// That screen used to show the same figures four times over — a ring,
  /// stat cards and a duplicate bar breakdown — and was cut back to one
  /// animated strip. A paper ending in a different visual language than a
  /// quiz makes the app feel like two apps, so this follows it: the number,
  /// then one bar carrying the whole shape of the attempt.
  ///
  /// Skipped is real here, unlike on a quiz. A paper can be submitted with
  /// questions left blank, and on a negatively marked paper leaving one
  /// blank is often the right call — so it gets its own segment rather than
  /// being folded into wrong.
  Widget _buildScoreCard() {
    final r = widget.result;
    final total = r.totalCorrect + r.totalWrong + r.totalSkipped;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            _hasNegative ? 'Net Score' : 'Total Score',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              final shown = _hasNegative
                  ? (r.netScore * t).toStringAsFixed(2)
                  : (r.totalCorrect * t).round().toString();
              return Text(
                shown,
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  height: 1,
                ),
              );
            },
          ),
          Text(
            'out of ' + _maxMarks.toStringAsFixed(0),
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showPercent = !_showPercent),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 950),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                int flex(int n) =>
                    ((total > 0 ? n / total : 0.0) * 1000 * t).round() + 1;
                String show(int n) {
                  if (_showPercent) {
                    final pct = total > 0 ? ((n / total) * 100).round() : 0;
                    return pct.toString() + '%';
                  }
                  return (n * t).round().toString();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 14,
                        child: Row(
                          children: [
                            if (r.totalCorrect > 0)
                              Expanded(
                                flex: flex(r.totalCorrect),
                                child:
                                    Container(color: const Color(0xFF4CAF50)),
                              ),
                            if (r.totalWrong > 0)
                              Expanded(
                                flex: flex(r.totalWrong),
                                child:
                                    Container(color: const Color(0xFFFF6B6B)),
                              ),
                            if (r.totalSkipped > 0)
                              Expanded(
                                flex: flex(r.totalSkipped),
                                child: Container(
                                  color: Colors.white.withOpacity(0.22),
                                ),
                              ),
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
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        _tally(const Color(0xFF4CAF50), 'Right',
                            show(r.totalCorrect)),
                        _tally(const Color(0xFFFF6B6B), 'Wrong',
                            show(r.totalWrong)),
                        if (r.totalSkipped > 0)
                          _tally(Colors.white.withOpacity(0.35), 'Left',
                              show(r.totalSkipped)),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tally(Color color, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.5),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSectionBreakdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SECTION BREAKDOWN',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 9,
              letterSpacing: 1.2,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 12),
          ...widget.result.sectionResults.map((r) {
            final total = r.correct + r.wrong + r.skipped;
            final pct = total == 0 ? 0.0 : r.correct / total;
            final barColor = pct >= 0.7
                ? const Color(0xFF4CAF50)
                : pct >= 0.4
                ? _accentColor
                : const Color(0xFFFF6B6B);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      r.config.label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation(barColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(
                      _hasNegative
                          ? '${r.netMarks.toStringAsFixed(1)}'
                          : '${r.correct}/${r.correct + r.wrong + r.skipped}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accentColor, _accentLight]),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Back to Home',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reusable stat widgets (unchanged) ─────────────────────────────────
