// lib/screens/papers/paper_result_screen.dart
// Style C – Full-width web dashboard with navbar & two columns

import 'package:flutter/material.dart';
import '../../models/paper_model.dart';
import '../../providers/progress_provider.dart';
import '../home/home_screen.dart';

class PaperResultScreen extends StatefulWidget {
  final PaperResult result;
  const PaperResultScreen({super.key, required this.result});

  @override
  State<PaperResultScreen> createState() => _PaperResultScreenState();
}

class _PaperResultScreenState extends State<PaperResultScreen> {
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

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Text(
            _hasNegative
                ? widget.result.netScore.toStringAsFixed(2)
                : widget.result.totalCorrect.toString(),
            style: TextStyle(
              color: _accentColor,
              fontSize: 52,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              height: 1,
            ),
          ),
          Text(
            'out of ${_maxMarks.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          // Stats row
          if (_hasNegative)
            _StatsRow(
              items: [
                _StatItem(
                  label: 'Marks earned',
                  value: widget.result.totalEarned.toStringAsFixed(2),
                  color: const Color(0xFF4CAF50),
                ),
                _StatItem(
                  label: 'Negative marks',
                  value: widget.result.totalPenalty.toStringAsFixed(2),
                  color: const Color(0xFFFF6B6B),
                ),
                _StatItem(
                  label: 'Accuracy',
                  value: '${widget.result.accuracyPercent.toStringAsFixed(1)}%',
                  color: const Color(0xFFFFD700),
                ),
              ],
            )
          else
            _StatsRow(
              items: [
                _StatItem(
                  label: 'Correct',
                  value: '${widget.result.totalCorrect}',
                  color: const Color(0xFF4CAF50),
                ),
                _StatItem(
                  label: 'Wrong / Skipped',
                  value:
                      '${widget.result.totalWrong + widget.result.totalSkipped}',
                  color: const Color(0xFFFFD700),
                ),
                _StatItem(
                  label: 'Accuracy',
                  value: '${widget.result.accuracyPercent.toStringAsFixed(1)}%',
                  color: Colors.white,
                ),
              ],
            ),
        ],
      ),
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
            onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            ),
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

class _StatItem {
  final String label;
  final String value;
  final Color color;
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _StatsRow extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 28,
              color: Colors.white.withOpacity(0.1),
            ),
          Expanded(
            child: Column(
              children: [
                Text(
                  items[i].value,
                  style: TextStyle(
                    color: items[i].color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  items[i].label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 9,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
