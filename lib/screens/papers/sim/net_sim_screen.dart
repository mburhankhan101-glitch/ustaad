// lib/screens/papers/sim/net_sim_screen.dart
//
// A copy of the NUST NET entry test interface, for mobile.
//
// Same reasoning as the FAST one: on exam day the software should be the
// boring part. A student who has sat twenty mocks should already know the
// green minutes counter sits top right, that the section strip says
// "Q 4 of 200" and "3/200 answered", and that the grid button in the middle
// of the footer opens the full question palette.
//
// Taken from the real thing on a phone. The desktop version puts Save,
// Review and Bookmark on the right of a wide toolbar; on mobile they are
// three pills across the top, and the footer splits into two rows — section
// navigation above, question navigation below.
//
// Only the chrome is copied. Timing, answers and scoring stay Ustaad's.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/providers/paper_provder.dart';

abstract final class NetSim {
  static const headerDark = Color(0xFF14566B);
  static const headerLight = Color(0xFF1C7391);
  static const green = Color(0xFF22C55E);
  static const strip = Color(0xFFE3F1F8);
  static const stripInk = Color(0xFF13475A);
  /// The page shares the strip's tint. Plain white made the two cards
  /// disappear into the background and looked nothing like the real one.
  static const page = strip;
  static const footer = Color(0xFFEDF4F8);
  static const optionFill = Color(0xFFF2F8FB);
  static const optionBorder = Color(0xFFD3E3EC);
  static const selectedFill = Color(0xFFDCEBF7);
  static const selectedBorder = Color(0xFF2B7BB9);
  static const blue = Color(0xFF2B7BB9);
  static const red = Color(0xFFC0392B);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFF8A9BA6);
  static const cardBorder = Color(0xFFD8E2E8);
}

class NetSimScreen extends ConsumerStatefulWidget {
  const NetSimScreen({
    super.key,
    required this.session,
    required this.onSubmit,
  });

  final PaperSessionState session;
  final VoidCallback onSubmit;

  @override
  ConsumerState<NetSimScreen> createState() => _NetSimScreenState();
}

class _NetSimScreenState extends ConsumerState<NetSimScreen> {
  PaperSessionState get s => widget.session;

  int get _answeredTotal {
    var n = 0;
    for (final sec in s.sections) {
      for (final q in sec.questions) {
        if (s.answers[q.id]?.selectedIndex != null) n++;
      }
    }
    return n;
  }

  int get _totalQuestions =>
      s.sections.fold(0, (n, sec) => n + sec.questions.length);

  int get _globalIndex {
    var n = 0;
    for (var i = 0; i < s.currentSectionIndex; i++) {
      n += s.sections[i].questions.length;
    }
    return n + s.currentQuestionIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(paperSessionProvider.notifier);
    final q = s.currentQuestion;
    final selected = s.answers[q.id]?.selectedIndex;

    return Scaffold(
      backgroundColor: NetSim.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            _sectionStrip(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _questionCard(q),
                    const SizedBox(height: 14),
                    _answerCard(q, selected, notifier),
                  ],
                ),
              ),
            ),
            _footer(context, notifier),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _header() {
    final mins = (s.globalSecondsLeft / 60).ceil();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [NetSim.headerDark, NetSim.headerLight],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s.currentSection.config.label,
              style: const TextStyle(
                color: NetSim.green,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.access_time, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            '$mins min',
            style: const TextStyle(
              color: NetSim.green,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionStrip() {
    return Container(
      color: NetSim.strip,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Text(
            'Q $_globalIndex of $_totalQuestions',
            style: const TextStyle(
              color: NetSim.stripInk,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            '$_answeredTotal/$_totalQuestions answered',
            style: const TextStyle(
              color: Color(0xFF5B7A89),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Question and answers ─────────────────────────────────────────────────

  Widget _questionCard(Question q) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: NetSim.cardBorder),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF7FAFC),
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            child: const Text(
              'Question',
              style: TextStyle(
                color: NetSim.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: NetSim.cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
            child: Text(
              q.text,
              style: const TextStyle(
                color: NetSim.ink,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerCard(Question q, int? selected, PaperSessionNotifier n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: NetSim.cardBorder),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF2F9FC),
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Answer ',
                    style: TextStyle(
                      color: NetSim.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: '( Please select your correct option )',
                    style: TextStyle(
                      color: NetSim.red,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                for (var i = 0; i < q.options.length; i++) ...[
                  _option(i, q.options[i], selected == i, n),
                  if (i != q.options.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(int i, String text, bool on, PaperSessionNotifier n) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        n.selectOption(i);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
        decoration: BoxDecoration(
          color: on ? NetSim.selectedFill : NetSim.optionFill,
          border: Border.all(
            color: on ? NetSim.selectedBorder : NetSim.optionBorder,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: on ? NetSim.selectedBorder : const Color(0xFF9FB3BF),
                  width: on ? 5.5 : 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: NetSim.ink,
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer: section row above, question row below ────────────────────────

  Widget _footer(BuildContext context, PaperSessionNotifier n) {
    final hasPrevSection = s.currentSectionIndex > 0;
    final hasNextSection = s.currentSectionIndex < s.sections.length - 1;
    final atFirst =
        s.currentSectionIndex == 0 && s.currentQuestionIndex == 0;

    return Container(
      color: NetSim.footer,
      padding: EdgeInsets.fromLTRB(
        10,
        9,
        10,
        10 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _sectionJump(
                label: 'Prev Section',
                leading: true,
                enabled: hasPrevSection,
                onTap: () => n.switchToSection(s.currentSectionIndex - 1),
              ),
              Expanded(
                child: Text(
                  '${s.currentSection.config.label} '
                  '(${s.currentSectionIndex + 1}/${s.sections.length})',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NetSim.stripInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _sectionJump(
                label: 'Next Section',
                leading: false,
                enabled: hasNextSection,
                onTap: () => n.switchToSection(s.currentSectionIndex + 1),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _navButton(
                  label: 'Prev',
                  icon: Icons.chevron_left,
                  leading: true,
                  enabled: !atFirst,
                  onTap: n.previousQuestion,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showPalette(context, n),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: NetSim.optionBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grid_view,
                            size: 14, color: NetSim.blue),
                        const SizedBox(width: 6),
                        Text(
                          '$_globalIndex/$_totalQuestions',
                          style: const TextStyle(
                            color: NetSim.blue,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _navButton(
                  label: 'Next',
                  icon: Icons.chevron_right,
                  leading: false,
                  enabled: true,
                  onTap: n.nextQuestion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onSubmit();
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: NetSim.headerDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Finish Test',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionJump({
    required String label,
    required bool leading,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled ? NetSim.blue : NetSim.muted;
    final icon = Icon(
      leading ? Icons.first_page : Icons.last_page,
      size: 15,
      color: color,
    );
    final text = Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    );
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: leading ? [icon, const SizedBox(width: 4), text]
            : [text, const SizedBox(width: 4), icon],
      ),
    );
  }

  Widget _navButton({
    required String label,
    required IconData icon,
    required bool leading,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled ? NetSim.ink : NetSim.muted;
    final parts = [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 2),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF1F4F6),
          border: Border.all(color: NetSim.optionBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: leading ? parts : parts.reversed.toList(),
        ),
      ),
    );
  }

  // ── The question palette ─────────────────────────────────────────────────

  void _showPalette(BuildContext context, PaperSessionNotifier n) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Text(
                  'Questions',
                  style: TextStyle(
                    color: NetSim.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  children: [
                    for (var sec = 0; sec < s.sections.length; sec++) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Text(
                          s.sections[sec].config.label,
                          style: const TextStyle(
                            color: NetSim.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: NetSim.optionBorder),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0;
                              i < s.sections[sec].questions.length;
                              i++)
                            _paletteCell(sheetCtx, n, sec, i),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paletteCell(
    BuildContext sheetCtx,
    PaperSessionNotifier n,
    int sec,
    int i,
  ) {
    final q = s.sections[sec].questions[i];
    final answered = s.answers[q.id]?.selectedIndex != null;
    var number = i + 1;
    for (var k = 0; k < sec; k++) {
      number += s.sections[k].questions.length;
    }

    final Color border =
        answered ? NetSim.selectedBorder : NetSim.optionBorder;

    return GestureDetector(
      onTap: () {
        Navigator.of(sheetCtx).pop();
        n.switchToSection(sec);
        n.jumpToPage(i, 1);
      },
      child: Container(
        width: 46,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: answered ? NetSim.selectedFill : Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: answered ? NetSim.stripInk : NetSim.ink,
            fontSize: 13,
            fontWeight: answered ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
