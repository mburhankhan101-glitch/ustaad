import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/paper_provder.dart';
import '../../models/paper_model.dart';
import 'paper_result_screen.dart';

// ─── Booklet enum ─────────────────────────────────────────────────────────────
enum NtsBooklet {
  yellow(
    code: 'A',
    label: 'Light Yellow',
    bgColor: Color(0xFFFFF8E1),
    textColor: Color(0xFF7B5E00),
    examBg: Color(0xFF1A1800),
    accent: Color(0xFFFFD54F),
  ),
  green(
    code: 'B',
    label: 'Light Green',
    bgColor: Color(0xFFF1F8E9),
    textColor: Color(0xFF2E5E00),
    examBg: Color(0xFF0D1A0D),
    accent: Color(0xFF81C784),
  ),
  blue(
    code: 'C',
    label: 'Light Blue',
    bgColor: Color(0xFFE3F2FD),
    textColor: Color(0xFF0D3F6E),
    examBg: Color(0xFF0A1020),
    accent: Color(0xFF64B5F6),
  ),
  pink(
    code: 'D',
    label: 'Light Pink',
    bgColor: Color(0xFFFDE8E8),
    textColor: Color(0xFF6E1515),
    examBg: Color(0xFF1A0D0D),
    accent: Color(0xFFEF9A9A),
  );

  final String code;
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color examBg;
  final Color accent;

  const NtsBooklet({
    required this.code,
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.examBg,
    required this.accent,
  });
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class NtsPaperScreen extends ConsumerStatefulWidget {
  final ExamType examType;
  const NtsPaperScreen({super.key, required this.examType});

  @override
  ConsumerState<NtsPaperScreen> createState() => _NtsPaperScreenState();
}

class _NtsPaperScreenState extends ConsumerState<NtsPaperScreen> {
  NtsBooklet? _selectedBooklet;
  bool _bookletConfirmed = false;

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
                color: Color(0xFF6C63FF),
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
    if (!_bookletConfirmed) {
      return PopScope(
        canPop: true,
        child: _BookletSelectionScreen(
          selectedBooklet: _selectedBooklet,
          onSelect: (b) => setState(() => _selectedBooklet = b),
          onConfirm: () {
            setState(() => _bookletConfirmed = true);
            ref
                .read(paperSessionProvider.notifier)
                .startPaper(
                  widget.examType,
                  uid: FirebaseAuth.instance.currentUser!.uid,
                );
          },
        ),
      );
    }

    final sessionAsync = ref.watch(paperSessionProvider);

    ref.listen<AsyncValue<PaperSessionState?>>(paperSessionProvider, (_, next) {
      final session = next.value;
      if (session != null && session.isSubmitted) {
        final result = ref.read(paperSessionProvider.notifier).buildResult();
        if (result != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PaperResultScreen(result: result),
                ),
              );
            }
          });
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showQuitDialog(context);
      },
      child: Scaffold(
        body: sessionAsync.when(
          loading: () => const _NtsLoadingView(),
          error: (e, _) => _NtsErrorView(error: e.toString()),
          data: (session) {
            if (session == null) return const _NtsLoadingView();
            if (session.isSubmitted) return const _NtsLoadingView();
            return _NtsBookletBody(
              session: session,
              booklet: _selectedBooklet ?? NtsBooklet.yellow,
            );
          },
        ),
      ),
    );
  }
}

// ─── Booklet selection ────────────────────────────────────────────────────────

class _BookletSelectionScreen extends StatefulWidget {
  final NtsBooklet? selectedBooklet;
  final ValueChanged<NtsBooklet> onSelect;
  final VoidCallback onConfirm;

  const _BookletSelectionScreen({
    required this.selectedBooklet,
    required this.onSelect,
    required this.onConfirm,
  });

  @override
  State<_BookletSelectionScreen> createState() =>
      _BookletSelectionScreenState();
}

class _BookletSelectionScreenState extends State<_BookletSelectionScreen> {
  NtsBooklet? _local;
  static const _kContentMaxWidth = 600.0;

  @override
  void initState() {
    super.initState();
    _local = widget.selectedBooklet;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF2A1E80)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > _kContentMaxWidth;
              final contentWidth = isWide ? _kContentMaxWidth : double.infinity;

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.chevron_left,
                                color: Colors.white54,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'NTS — CS',
                              style: TextStyle(
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
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        child: Text(
                          'Select your booklet to begin',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),

                      // 4 booklet cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: NtsBooklet.values.map((b) {
                            final isSel = _local == b;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _local = b);
                                widget.onSelect(b);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? b.bgColor.withOpacity(0.18)
                                      : b.bgColor.withOpacity(0.06),
                                  border: Border.all(
                                    color: isSel
                                        ? b.accent
                                        : Colors.white.withOpacity(0.12),
                                    width: isSel ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: b.bgColor,
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.4,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(2, 2),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        b.code,
                                        style: TextStyle(
                                          color: b.textColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      b.label.replaceFirst('Light ', 'Light\n'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSel
                                            ? b.accent
                                            : Colors.white.withOpacity(0.4),
                                        fontSize: 9,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Detail card
                      if (_local != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _local!.bgColor.withOpacity(0.07),
                              border: Border.all(
                                color: _local!.accent.withOpacity(0.4),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Booklet ${_local!.code} — ${_local!.label}',
                                  style: TextStyle(
                                    color: _local!.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: const [
                                    _DetailStat('Total MCQs', '90'),
                                    _DetailStat('Time', '100 min'),
                                    _DetailStat('Marks', '100'),
                                    _DetailStat(
                                      'Negative',
                                      'None',
                                      valueColor: Color(0xFF4CAF50),
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: Colors.white12,
                                  height: 20,
                                ),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: const [
                                    _SectionTag('20 English'),
                                    _SectionTag('20 Analytical'),
                                    _SectionTag('20 Quantitative'),
                                    _SectionTag('30 CS'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                      const Spacer(),

                      // Confirm button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                        child: GestureDetector(
                          onTap: _local != null ? widget.onConfirm : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: _local != null
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF6C63FF),
                                        Color(0xFF9B8FFF),
                                      ],
                                    )
                                  : null,
                              color: _local == null
                                  ? Colors.white.withOpacity(0.08)
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _local != null
                                  ? 'Open Booklet ${_local!.code} ›'
                                  : 'Select a booklet to continue',
                              style: TextStyle(
                                color: _local != null
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Exam body ────────────────────────────────────────────────────────────────

const int _kQuestionsPerPage = 3;

class _NtsBookletBody extends ConsumerWidget {
  final PaperSessionState session;
  final NtsBooklet booklet;
  const _NtsBookletBody({required this.session, required this.booklet});

  static const _kContentMaxWidth = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = booklet.accent;
    final examBg = booklet.examBg;

    final sections = session.sections;
    final secIdx = session.currentSectionIndex;
    final currentSec = session.currentSection;
    final qIdx = session.currentQuestionIndex;

    final totalSec = session.globalSecondsLeft;
    final hh = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final mm = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSec % 60).toString().padLeft(2, '0');
    final isUrgent = totalSec < 300;

    final pageIndex = qIdx ~/ _kQuestionsPerPage;
    final totalPages = (currentSec.questions.length / _kQuestionsPerPage)
        .ceil();
    final pageStart = pageIndex * _kQuestionsPerPage;
    final pageEnd = (pageStart + _kQuestionsPerPage).clamp(
      0,
      currentSec.questions.length,
    );
    final pageQuestions = currentSec.questions.sublist(pageStart, pageEnd);

    final isLastSection = secIdx >= sections.length - 1;
    final isLastPage = pageIndex >= totalPages - 1;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: examBg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > _kContentMaxWidth;
            final contentWidth = isWide ? _kContentMaxWidth : double.infinity;

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    // ── Header ────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booklet ${booklet.code} · ${currentSec.config.label}',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                'Page ${pageIndex + 1} of $totalPages  ·  '
                                'Q${pageStart + 1}–$pageEnd of ${currentSec.questions.length}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 9,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B).withOpacity(0.12),
                              border: Border.all(
                                color: const Color(0xFFFF6B6B).withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Time left',
                                  style: TextStyle(
                                    color: const Color(
                                      0xFFFF6B6B,
                                    ).withOpacity(0.6),
                                    fontSize: 8,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  '$hh:$mm:$ss',
                                  style: TextStyle(
                                    color: isUrgent
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.white70,
                                    fontSize: 14,
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

                    // ── Section strips ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: Row(
                        children: List.generate(sections.length, (i) {
                          final isActive = i == secIdx;
                          final isDone = i < secIdx;
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: i < sections.length - 1 ? 3 : 0,
                              ),
                              height: 3,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? accent.withOpacity(0.45)
                                    : isActive
                                    ? accent
                                    : Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 3, 18, 0),
                      child: Row(
                        children: List.generate(sections.length, (i) {
                          final isActive = i == secIdx;
                          return Expanded(
                            child: Text(
                              sections[i].config.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive
                                    ? accent
                                    : Colors.white.withOpacity(0.25),
                                fontSize: 8,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // ── Page dots ─────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(totalPages, (i) {
                            final isActive = i == pageIndex;
                            final isDone = i < pageIndex;
                            return Container(
                              margin: const EdgeInsets.only(right: 5),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? accent.withOpacity(0.4)
                                    : isActive
                                    ? accent
                                    : Colors.white.withOpacity(0.15),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── 3 questions ────────────────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(color: accent.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: List.generate(pageQuestions.length, (
                                pi,
                              ) {
                                final q = pageQuestions[pi];
                                final qNum = pageStart + pi + 1;
                                final answer = session.answerFor(q.id);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (pi > 0) ...[
                                      const SizedBox(height: 12),
                                      Divider(
                                        color: Colors.white.withOpacity(0.08),
                                        height: 1,
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Text(
                                      'Q $qNum',
                                      style: TextStyle(
                                        color: accent.withOpacity(0.8),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      q.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        height: 1.4,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // 2‑column layout
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final cellWidth =
                                            (constraints.maxWidth - 5) / 2;
                                        return Wrap(
                                          spacing: 5,
                                          runSpacing: 5,
                                          children: List.generate(q.options.length, (
                                            i,
                                          ) {
                                            final isSel =
                                                answer?.selectedIndex == i;
                                            return GestureDetector(
                                              onTap: () => ref
                                                  .read(
                                                    paperSessionProvider
                                                        .notifier,
                                                  )
                                                  .selectOptionById(q.id, i),
                                              child: SizedBox(
                                                width: cellWidth,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 7,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isSel
                                                        ? accent.withOpacity(
                                                            0.2,
                                                          )
                                                        : Colors.white
                                                              .withOpacity(
                                                                0.05,
                                                              ),
                                                    border: Border.all(
                                                      color: isSel
                                                          ? accent.withOpacity(
                                                              0.6,
                                                            )
                                                          : Colors.white
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Container(
                                                        width: 18,
                                                        height: 18,
                                                        decoration: BoxDecoration(
                                                          color: isSel
                                                              ? accent
                                                              : Colors.white
                                                                    .withOpacity(
                                                                      0.08,
                                                                    ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        alignment:
                                                            Alignment.center,
                                                        child: Text(
                                                          String.fromCharCode(
                                                            65 + i,
                                                          ),
                                                          style: TextStyle(
                                                            color: isSel
                                                                ? Colors.white
                                                                : Colors.white
                                                                      .withOpacity(
                                                                        0.5,
                                                                      ),
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontFamily:
                                                                'Poppins',
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Expanded(
                                                        child: Text(
                                                          q.options[i],
                                                          style: TextStyle(
                                                            color: Colors.white
                                                                .withOpacity(
                                                                  0.85,
                                                                ),
                                                            fontSize: 9.5,
                                                            fontFamily:
                                                                'Poppins',
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Page nav ───────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _NavArrow(
                            icon: Icons.chevron_left,
                            accent: accent,
                            onTap: pageIndex > 0
                                ? () => ref
                                      .read(paperSessionProvider.notifier)
                                      .jumpToPage(
                                        pageIndex - 1,
                                        _kQuestionsPerPage,
                                      )
                                : null,
                          ),
                          Text(
                            'Swipe to turn page',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 10,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          _NavArrow(
                            icon: Icons.chevron_right,
                            accent: accent,
                            onTap: () {
                              if (!isLastPage) {
                                ref
                                    .read(paperSessionProvider.notifier)
                                    .jumpToPage(
                                      pageIndex + 1,
                                      _kQuestionsPerPage,
                                    );
                              } else if (!isLastSection) {
                                ref
                                    .read(paperSessionProvider.notifier)
                                    .advanceToNextSection();
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── Submit ─────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                      child: GestureDetector(
                        onTap: () => _confirmSubmit(context, ref),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.15),
                            border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.35),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Submit Paper',
                            style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
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
          'Once submitted you cannot change any answers.',
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

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  const _NavArrow({required this.icon, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withOpacity(active ? 0.12 : 0.04),
          border: Border.all(color: accent.withOpacity(active ? 0.3 : 0.1)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: accent.withOpacity(active ? 0.9 : 0.25),
          size: 18,
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _DetailStat(this.label, this.value, {this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _SectionTag extends StatelessWidget {
  final String label;
  const _SectionTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 9,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

class _NtsLoadingView extends StatelessWidget {
  const _NtsLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0E2E),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFD700)),
            SizedBox(height: 16),
            Text(
              'Opening booklet...',
              style: TextStyle(color: Colors.white54, fontFamily: 'Poppins'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NtsErrorView extends StatelessWidget {
  final String error;
  const _NtsErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0E2E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong.\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }
}
