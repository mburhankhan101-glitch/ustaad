// lib/screens/papers/program_selection_screen.dart
//
// Shown AFTER the user taps a paper card on PapersScreen.
// Shows the correct program card based on what the user selected
// on TestSelectionScreen — no extra choice needed.
// Tapping "Start Paper" navigates to the correct exam screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/models/paper_model.dart';
import 'package:ustaad/providers/paper_provder.dart';
import 'package:ustaad/screens/papers/fast_paper_screen.dart';
import 'package:ustaad/screens/papers/nts_paper_screen.dart';
import 'package:ustaad/screens/papers/nust_paper_screen.dart';

// ─── What the user picked on TestSelectionScreen ──────────────────────────────
// Pass this in from wherever you store the user's test selection.
// For now it's an enum — wire it to your auth/user provider as needed.

enum UserProgram {
  // FAST-NU
  fastCS, // CS / AI / DS / SE / EE
  fastBusiness, // Business / Fintech / Analytics
  // NUST-NET
  nustEngineering, // Engineering / CS
  nustBusiness, // Business / Social Sciences
  // NTS
  ntsCS, // General / COMSATS CS
}

class ProgramSelectionScreen extends ConsumerWidget {
  final ExamType examType;
  final UserProgram userProgram;

  const ProgramSelectionScreen({
    super.key,
    required this.examType,
    required this.userProgram,
  });

  // ── Colours ────────────────────────────────────────────────────────────────
  Color get _accent {
    switch (examType) {
      case ExamType.fastNU:
        return const Color(0xFF6C63FF);
      case ExamType.nustNET:
        return const Color(0xFF4CAF50);
      case ExamType.nts:
        return const Color(0xFFFF6B6B);
    }
  }

  Color get _accentLight {
    switch (examType) {
      case ExamType.fastNU:
        return const Color(0xFF9B8FFF);
      case ExamType.nustNET:
        return const Color(0xFF81C784);
      case ExamType.nts:
        return const Color(0xFFFF9999);
    }
  }

  String get _examLabel {
    switch (examType) {
      case ExamType.fastNU:
        return 'FAST-NU';
      case ExamType.nustNET:
        return 'NUST-NET';
      case ExamType.nts:
        return 'NTS';
    }
  }

  // ── Build program info based on user's program ────────────────────────────
  _ProgramInfo get _programInfo {
    switch (userProgram) {
      // ── FAST-NU ─────────────────────────────────────────────────────────
      case UserProgram.fastCS:
        return _ProgramInfo(
          label: 'CS / AI / DS / SE / EE',
          subtitle: 'Computer Sciences & Engineering',
          sections: const [
            _SectionTag('50 Advanced Maths'),
            _SectionTag('20 Basic Maths'),
            _SectionTag('20 Analytical & IQ'),
            _SectionTag('30 English'),
          ],
          markingLines: const [
            'Maths & IQ: +1 correct  ·  −0.25 wrong',
            'English:   +0.344 correct  ·  −0.0844 wrong',
          ],
          totalMCQs: 120,
          totalTime: '120 min',
          totalMarks: '100',
          hasNegative: true,
        );

      case UserProgram.fastBusiness:
        return _ProgramInfo(
          label: 'Business / Fintech / Analytics',
          subtitle: 'Business & Social Sciences',
          sections: const [
            _SectionTag('50 Basic Maths'),
            _SectionTag('25 Analytical & IQ'),
            _SectionTag('15 Essay Writing'),
            _SectionTag('10 English'),
          ],
          markingLines: const [
            'MCQs: +1 correct  ·  −0.25 wrong',
            'Essay component is marked separately',
          ],
          totalMCQs: 100,
          totalTime: '120 min',
          totalMarks: '100',
          hasNegative: true,
        );

      // ── NUST-NET ─────────────────────────────────────────────────────────
      case UserProgram.nustEngineering:
        return _ProgramInfo(
          label: 'Engineering / CS',
          subtitle: 'National University of Sciences & Technology',
          sections: const [
            _SectionTag('100 Mathematics'),
            _SectionTag('60 Physics'),
            _SectionTag('40 English'),
          ],
          markingLines: const [
            '+1 for every correct answer',
            'No negative marking',
          ],
          totalMCQs: 200,
          totalTime: '180 min',
          totalMarks: '200',
          hasNegative: false,
        );

      case UserProgram.nustBusiness:
        return _ProgramInfo(
          label: 'Business / Social Sciences',
          subtitle: 'National University of Sciences & Technology',
          sections: const [
            _SectionTag('100 Quantitative Maths'),
            _SectionTag('100 English'),
          ],
          markingLines: const [
            '+1 for every correct answer',
            'No negative marking',
          ],
          totalMCQs: 200,
          totalTime: '180 min',
          totalMarks: '200',
          hasNegative: false,
        );

      // ── NTS ──────────────────────────────────────────────────────────────
      case UserProgram.ntsCS:
        return _ProgramInfo(
          label: 'General / COMSATS CS',
          subtitle: 'National Testing Service',
          sections: const [
            _SectionTag('20 English'),
            _SectionTag('20 Analytical'),
            _SectionTag('20 Quantitative'),
            _SectionTag('30 Computer Science'),
          ],
          markingLines: const [
            '+1 for every correct answer',
            'No negative marking',
          ],
          totalMCQs: 90,
          totalTime: '100 min',
          totalMarks: '100',
          hasNegative: false,
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = _programInfo;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF6C63FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _examLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: Text(
                  'Your program',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),

              // ── Program card ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    border: Border.all(color: _accent.withOpacity(0.45)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "YOUR PROGRAM" badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'YOUR PROGRAM',
                          style: TextStyle(
                            color: _accentLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        info.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Section tags
                      Wrap(spacing: 6, runSpacing: 6, children: info.sections),

                      const SizedBox(height: 14),

                      // Stats row: MCQs | Time | Marks
                      Row(
                        children: [
                          _StatChip(label: 'MCQs', value: '${info.totalMCQs}'),
                          const SizedBox(width: 12),
                          _StatChip(label: 'Time', value: info.totalTime),
                          const SizedBox(width: 12),
                          _StatChip(label: 'Marks', value: info.totalMarks),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: info.hasNegative
                                  ? const Color(0xFFFF6B6B).withOpacity(0.15)
                                  : const Color(0xFF4CAF50).withOpacity(0.15),
                              border: Border.all(
                                color: info.hasNegative
                                    ? const Color(0xFFFF6B6B).withOpacity(0.3)
                                    : const Color(0xFF4CAF50).withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              info.hasNegative ? 'Negative' : 'No negative',
                              style: TextStyle(
                                color: info.hasNegative
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF4CAF50),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Marking scheme box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MARKING SCHEME',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 9,
                                letterSpacing: 1,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...info.markingLines.map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  line,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontFamily: 'Poppins',
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
              ),

              const SizedBox(height: 14),

              // ── Warning banner ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.08),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withOpacity(0.25),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          examType == ExamType.nustNET
                              ? 'Exam Mode: One global timer of 180 min. '
                                    'You can freely switch between Maths, Physics and English at any time. '
                                    'Paper auto-submits when time is up.'
                              : examType == ExamType.nts
                              ? 'Exam Mode: One global timer of 100 min. '
                                    'Sections appear in order: English → Analytical → Quantitative → CS. '
                                    'Paper auto-submits when time is up.'
                              : 'Exam Mode: Sections are randomised. Each section has its own timer. '
                                    'You cannot return to a previous section once you move forward. '
                                    'Paper auto-submits when time is up.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            height: 1.5,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Start Paper button ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: GestureDetector(
                  onTap: () => _startPaper(context, ref),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accent, _accentLight]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Start Paper  ›',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startPaper(BuildContext context, WidgetRef ref) {
    // Reset any previous session before starting a new one
    ref.read(paperSessionProvider.notifier).reset();

    Widget screen;
    switch (examType) {
      case ExamType.fastNU:
        screen = FastPaperScreen(examType: examType);
        break;
      case ExamType.nustNET:
        screen = NustPaperScreen(examType: examType);
        break;
      case ExamType.nts:
        screen = NtsPaperScreen(examType: examType);
        break;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _ProgramInfo {
  final String label;
  final String subtitle;
  final List<Widget> sections;
  final List<String> markingLines;
  final int totalMCQs;
  final String totalTime;
  final String totalMarks;
  final bool hasNegative;

  const _ProgramInfo({
    required this.label,
    required this.subtitle,
    required this.sections,
    required this.markingLines,
    required this.totalMCQs,
    required this.totalTime,
    required this.totalMarks,
    required this.hasNegative,
  });
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionTag extends StatelessWidget {
  final String label;
  const _SectionTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 10,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
