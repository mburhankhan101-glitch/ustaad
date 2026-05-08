// lib/screens/papers/nust_paper_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/paper_provder.dart';
import '../../models/paper_model.dart';
import 'paper_result_screen.dart';

class NustPaperScreen extends ConsumerStatefulWidget {
  final ExamType examType;
  const NustPaperScreen({super.key, required this.examType});

  @override
  ConsumerState<NustPaperScreen> createState() => _NustPaperScreenState();
}

class _NustPaperScreenState extends ConsumerState<NustPaperScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paperSessionProvider.notifier).startPaper(widget.examType);
    });
  }

  void _showQuitDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End the Paper?',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Your progress will be lost and a new paper will load next time.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Poppins',
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Quit',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(paperSessionProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showQuitDialog(context);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF2A1E80)],
            ),
          ),
          child: SafeArea(
            child: sessionAsync.when(
              loading: () => const _NustLoadingView(),
              error: (e, _) => _NustErrorView(error: e.toString()),
              data: (session) {
                if (session == null) return const _NustLoadingView();
                if (session.isSubmitted) return const SizedBox.shrink();
                return _NustExamBody(session: session);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Main exam body ───────────────────────────────────────────────────────────

class _NustExamBody extends ConsumerWidget {
  final PaperSessionState session;
  const _NustExamBody({required this.session});

  // NUST brand colour
  static const _green = Color(0xFF4CAF50);
  static const _greenLight = Color(0xFF81C784);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = session.currentSection;
    final question = session.currentQuestion;
    final answer = session.answerFor(question.id);
    final qIndex = session.currentQuestionIndex;
    final secIdx = session.currentSectionIndex;

    // Global timer
    final totalSec = session.globalSecondsLeft;
    final hours = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final mins = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSec % 60).toString().padLeft(2, '0');
    final timerStr = '$hours:$mins:$secs';
    final isUrgent = totalSec < 300; // last 5 min

    // Running totals for the mini scorecard
    final totalAnswered = session.answers.values
        .where((a) => a.selectedIndex != null)
        .length;
    final totalQuestions = session.sections.fold(
      0,
      (s, ls) => s + ls.questions.length,
    );
    final totalSkipped = totalQuestions - totalAnswered;

    return Column(
      children: [
        // ── Top bar: global timer + no-negative badge ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total time remaining',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 9,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    timerStr,
                    style: TextStyle(
                      color: isUrgent ? const Color(0xFFFF6B6B) : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.15),
                  border: Border.all(color: _green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Marking',
                      style: TextStyle(
                        color: _green.withOpacity(0.6),
                        fontSize: 8,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const Text(
                      'No negative',
                      style: TextStyle(
                        color: _greenLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Section tabs — all tappable, free switching ────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: List.generate(session.sections.length, (i) {
              final s = session.sections[i];
              final isActive = i == secIdx;
              final answered = session.answeredInSection(i);
              final total = s.questions.length;

              return Expanded(
                child: GestureDetector(
                  onTap: () => ref
                      .read(paperSessionProvider.notifier)
                      .switchToSection(i),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: i < session.sections.length - 1 ? 6 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _green.withOpacity(0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color: isActive
                            ? _green.withOpacity(0.4)
                            : Colors.white.withOpacity(0.1),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          s.config.label,
                          style: TextStyle(
                            color: isActive
                                ? _greenLight
                                : Colors.white.withOpacity(0.45),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$answered/$total',
                          style: TextStyle(
                            color: isActive
                                ? _greenLight.withOpacity(0.6)
                                : Colors.white.withOpacity(0.25),
                            fontSize: 8,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Free switching hint
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 5, 18, 0),
          child: Text(
            'Tap any section above to switch — your answers are saved',
            style: TextStyle(
              color: _green.withOpacity(0.55),
              fontSize: 9,
              fontFamily: 'Poppins',
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Question progress bar for current section ──────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Q ${qIndex + 1} of ${section.questions.length} · ${section.config.label}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '${((qIndex + 1) / section.questions.length * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (qIndex + 1) / section.questions.length,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(_green),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),

        // ── Mini scorecard ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ScoreChip(
                  label: 'Answered',
                  value: '$totalAnswered',
                  color: Colors.white,
                ),
                _Divider(),
                _ScoreChip(
                  label: 'Skipped',
                  value: '$totalSkipped',
                  color: const Color(0xFFFFD700),
                ),
                _Divider(),
                _ScoreChip(
                  label: 'Current score',
                  value: '$totalAnswered / 200',
                  color: _greenLight,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Question card ──────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${qIndex + 1} · ${section.config.label}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Options — no lock, change anytime
                  ...List.generate(question.options.length, (i) {
                    final isSelected = answer?.selectedIndex == i;

                    return GestureDetector(
                      onTap: () => ref
                          .read(paperSessionProvider.notifier)
                          .selectOption(i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _green.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: isSelected
                                ? _green.withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _green
                                    : Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                question.options[i],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // No confirm button hint
                  const SizedBox(height: 4),
                  Text(
                    'Tap option to select · change anytime',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 10,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Bottom nav: prev | submit | next ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavArrow(
                icon: Icons.chevron_left,
                color: _green,
                onTap: qIndex > 0
                    ? () => ref
                          .read(paperSessionProvider.notifier)
                          .previousQuestion()
                    : null,
              ),
              Text(
                '${qIndex + 1} / ${section.questions.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontFamily: 'Poppins',
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right,
                color: _green,
                onTap: qIndex < section.questions.length - 1
                    ? () =>
                          ref.read(paperSessionProvider.notifier).nextQuestion()
                    : null,
              ),
            ],
          ),
        ),

        // Submit button
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: GestureDetector(
            onTap: () => _confirmSubmit(context, ref),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.15),
                border: Border.all(
                  color: const Color(0xFFFF6B6B).withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Submit Paper',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
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

  void _confirmSubmit(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Submit Paper?',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 16,
          ),
        ),
        content: Text(
          'Make sure you have answered as many questions as possible. You cannot undo this.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Poppins',
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF4CAF50), fontFamily: 'Poppins'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final result = ref
                  .read(paperSessionProvider.notifier)
                  .submitPaper();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PaperResultScreen(result: result),
                ),
              );
            },
            child: const Text(
              'Submit',
              style: TextStyle(color: Color(0xFFFF6B6B), fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _NavArrow({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(onTap == null ? 0.04 : 0.1),
          border: Border.all(
            color: color.withOpacity(onTap == null ? 0.1 : 0.25),
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color.withOpacity(onTap == null ? 0.2 : 0.8),
          size: 20,
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ScoreChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 8,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withOpacity(0.1),
    );
  }
}

class _NustLoadingView extends StatelessWidget {
  const _NustLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50)),
          SizedBox(height: 16),
          Text(
            'Loading paper...',
            style: TextStyle(color: Colors.white54, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}

class _NustErrorView extends StatelessWidget {
  final String error;
  const _NustErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Something went wrong.\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins'),
        ),
      ),
    );
  }
}
