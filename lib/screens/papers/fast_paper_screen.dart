// lib/screens/papers/fast_paper_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/paper_provder.dart';
import '../../models/paper_model.dart';
import 'paper_result_screen.dart';

class FastPaperScreen extends ConsumerStatefulWidget {
  final ExamType examType;
  const FastPaperScreen({super.key, required this.examType});

  @override
  ConsumerState<FastPaperScreen> createState() => _FastPaperScreenState();
}

class _FastPaperScreenState extends ConsumerState<FastPaperScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paperSessionProvider.notifier).startPaper(widget.examType);
    });
  }

  // ── Quit confirmation dialog ─────────────────────────────────────────────────
  void _showQuitDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // must tap a button — no accidental dismissal
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
            onPressed: () =>
                Navigator.pop(context), // close dialog, stay in paper
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // leave the paper screen
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

    // PopScope intercepts the Android back button AND the swipe-back gesture.
    // canPop: false means Flutter will never pop automatically — we decide.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // already handled, nothing to do
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
              loading: () => const _LoadingView(message: 'Loading paper...'),
              error: (e, _) => _ErrorView(error: e.toString()),
              data: (session) {
                if (session == null)
                  return const _LoadingView(message: 'Preparing...');
                if (session.isSubmitted) return const SizedBox.shrink();
                return _FastExamBody(session: session);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Main exam body ───────────────────────────────────────────────────────────

class _FastExamBody extends ConsumerWidget {
  final PaperSessionState session;
  const _FastExamBody({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = session.currentSection;
    final question = session.currentQuestion;
    final answer = session.answerFor(question.id);
    final qIndex = session.currentQuestionIndex;
    final sections = session.sections;
    final secIdx = session.currentSectionIndex;

    // Per-section seconds left
    final secLeft = session.sectionSecondsLeft[section.config.id] ?? 0;
    final mins = (secLeft ~/ 60).toString().padLeft(2, '0');
    final secs = (secLeft % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        // ── Top bar: section pill + timer ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionPill(label: section.config.label),
              _TimerBox(time: '$mins:$secs', isUrgent: secLeft < 120),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Section progress dots with labels ──────────────────────────────
        _SectionDots(
          sections: sections,
          currentIndex: secIdx,
          session: session,
        ),

        const SizedBox(height: 10),

        // ── Question progress bar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Q ${qIndex + 1} of ${section.questions.length}',
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
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),

        // ── Marking chips ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Row(
            children: [
              _MarkChip(
                label: '+${section.config.markCorrect} correct',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 6),
              _MarkChip(
                label: '${section.config.markWrong} wrong',
                color: const Color(0xFFFF6B6B),
              ),
              const SizedBox(width: 6),
              _MarkChip(label: '0 skipped', color: Colors.white38),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Question card ──────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
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

                      // Options
                      ...List.generate(question.options.length, (i) {
                        final isSelected = answer?.selectedIndex == i;
                        final isConfirmed = answer?.isConfirmed == true;

                        Color borderColor = Colors.white.withOpacity(0.1);
                        Color bgColor = Colors.white.withOpacity(0.05);
                        Color letterBg = Colors.white.withOpacity(0.08);
                        Color letterTxt = Colors.white.withOpacity(0.5);

                        if (isSelected && isConfirmed) {
                          bgColor = const Color(0xFF4CAF50).withOpacity(0.15);
                          borderColor = const Color(
                            0xFF4CAF50,
                          ).withOpacity(0.5);
                          letterBg = const Color(0xFF4CAF50);
                          letterTxt = Colors.white;
                        } else if (isSelected) {
                          bgColor = const Color(0xFF6C63FF).withOpacity(0.2);
                          borderColor = const Color(
                            0xFF6C63FF,
                          ).withOpacity(0.6);
                          letterBg = const Color(0xFF6C63FF);
                          letterTxt = Colors.white;
                        }

                        return GestureDetector(
                          onTap: isConfirmed
                              ? null
                              : () => ref
                                    .read(paperSessionProvider.notifier)
                                    .selectOption(i),
                          child: Opacity(
                            opacity: (isConfirmed && !isSelected) ? 0.4 : 1.0,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: letterBg,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      isSelected && isConfirmed
                                          ? '✓'
                                          : String.fromCharCode(65 + i),
                                      style: TextStyle(
                                        color: letterTxt,
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
                          ),
                        );
                      }),

                      // Confirmed lock notice
                      if (answer?.isConfirmed == true) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.25),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock,
                                color: Color(0xFF4CAF50),
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Answer locked — cannot be changed',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Bottom nav: prev | confirm | next ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavArrow(
                icon: Icons.chevron_left,
                onTap: qIndex > 0
                    ? () => ref
                          .read(paperSessionProvider.notifier)
                          .previousQuestion()
                    : null,
              ),
              _ConfirmButton(
                isConfirmed: answer?.isConfirmed == true,
                hasSelection: answer?.selectedIndex != null,
                onTap: () =>
                    ref.read(paperSessionProvider.notifier).confirmAnswer(),
              ),
              _NavArrow(
                icon: Icons.chevron_right,
                onTap: qIndex < section.questions.length - 1
                    ? () =>
                          ref.read(paperSessionProvider.notifier).nextQuestion()
                    : null,
              ),
            ],
          ),
        ),

        // Next Section button
        _NextSectionButton(
          session: session,
          onTap: () => _onNextSection(context, ref, session),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  void _onNextSection(
    BuildContext context,
    WidgetRef ref,
    PaperSessionState session,
  ) {
    final isLast = session.currentSectionIndex >= session.sections.length - 1;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isLast ? 'Submit Paper?' : 'Move to Next Section?',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 16,
          ),
        ),
        content: Text(
          isLast
              ? 'This will submit your paper. You cannot make any changes after this.'
              : 'You cannot return to this section once you move forward.',
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
              style: TextStyle(color: Color(0xFF6C63FF), fontFamily: 'Poppins'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isLast) {
                final result = ref
                    .read(paperSessionProvider.notifier)
                    .submitPaper();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaperResultScreen(result: result),
                  ),
                );
              } else {
                ref.read(paperSessionProvider.notifier).advanceToNextSection();
              }
            },
            child: Text(
              isLast ? 'Submit' : 'Next Section',
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionPill extends StatelessWidget {
  final String label;
  const _SectionPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.25),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9B8FFF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

class _TimerBox extends StatelessWidget {
  final String time;
  final bool isUrgent;
  const _TimerBox({required this.time, required this.isUrgent});

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? const Color(0xFFFF6B6B) : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withOpacity(0.12),
        border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            'Section time',
            style: TextStyle(
              color: const Color(0xFFFF6B6B).withOpacity(0.7),
              fontSize: 9,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDots extends StatelessWidget {
  final List<LoadedSection> sections;
  final int currentIndex;
  final PaperSessionState session;

  const _SectionDots({
    required this.sections,
    required this.currentIndex,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: List.generate(sections.length, (i) {
          final isDone = i < currentIndex;
          final isActive = i == currentIndex;
          final isUpcoming = i > currentIndex;

          Color barColor;
          Color labelColor;
          String subLabel;

          if (isDone) {
            barColor = const Color(0xFF4CAF50).withOpacity(0.6);
            labelColor = const Color(0xFF4CAF50).withOpacity(0.7);
            subLabel = '✓ Done';
          } else if (isActive) {
            barColor = const Color(0xFF6C63FF);
            labelColor = const Color(0xFF9B8FFF);
            subLabel =
                'Q${session.currentQuestionIndex + 1}/${sections[i].questions.length}';
          } else {
            barColor = Colors.white.withOpacity(0.15);
            labelColor = Colors.white.withOpacity(0.3);
            subLabel = i == currentIndex + 1 ? 'Up next' : 'Upcoming';
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sections[i].config.label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 7.5,
                      fontFamily: 'Poppins',
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subLabel,
                    style: TextStyle(
                      color: labelColor.withOpacity(0.7),
                      fontSize: 7,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MarkChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MarkChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontFamily: 'Poppins'),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(onTap == null ? 0.04 : 0.08),
          border: Border.all(
            color: Colors.white.withOpacity(onTap == null ? 0.06 : 0.12),
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(onTap == null ? 0.2 : 1.0),
          size: 20,
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final bool isConfirmed;
  final bool hasSelection;
  final VoidCallback onTap;
  const _ConfirmButton({
    required this.isConfirmed,
    required this.hasSelection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isConfirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '✓ Confirmed',
          style: TextStyle(
            color: Color(0xFF4CAF50),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: hasSelection ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          gradient: hasSelection
              ? const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF)],
                )
              : null,
          color: hasSelection ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Confirm Answer',
          style: TextStyle(
            color: hasSelection ? Colors.white : Colors.white.withOpacity(0.3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

class _NextSectionButton extends StatelessWidget {
  final PaperSessionState session;
  final VoidCallback onTap;
  const _NextSectionButton({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLast = session.currentSectionIndex >= session.sections.length - 1;
    final nextSection = isLast
        ? null
        : session.sections[session.currentSectionIndex + 1].config.label;

    return TextButton(
      onPressed: onTap,
      child: Text(
        isLast ? 'Submit Paper ⚠' : 'Next Section → $nextSection ⚠',
        style: const TextStyle(
          color: Color(0xFFFF6B6B),
          fontSize: 11,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

// ─── Loading / Error views ────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF6C63FF)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Something went wrong.\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}
