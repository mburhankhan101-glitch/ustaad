// lib/screens/papers/sim/fast_sim_screen.dart
//
// A copy of the FAST-NU online admission test interface, for mobile.
//
// The point of a mock paper is that nothing on exam day is a surprise, and
// that includes the software. A student who has sat twenty of these should
// recognise the navy bar, know that Next is the green one and Back the blue
// one, and not waste thirty seconds hunting for the unanswered list. So this
// is deliberately not Ustaad's design language: it is theirs, down to the
// colours and the button order.
//
// Taken from the real thing on a phone, not from the desktop site — the
// mobile layout stacks the header into three rows and folds the four
// controls into a 2x2 block, and the unanswered button reads "Unanswered
// (119)" rather than spelling it out.
//
// Only the chrome is copied. The timer, the answers and the scoring are
// Ustaad's own, through PaperSessionState.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/providers/paper_provder.dart';

/// The real simulator's palette, sampled from it rather than approximated.
abstract final class FastSim {
  static const navy = Color(0xFF1C3B5A);
  static const headerTeal = Color(0xFF2E5C7E);
  static const blue = Color(0xFF2B6CB0);
  static const green = Color(0xFF2F855A);
  static const grey = Color(0xFFCBD2D9);
  static const greyText = Color(0xFF6B7280);
  static const page = Color(0xFFF7F8FA);
  static const cardBorder = Color(0xFFD9DEE5);
  static const ink = Color(0xFF1A202C);
}

class FastSimScreen extends ConsumerWidget {
  const FastSimScreen({
    super.key,
    required this.session,
    required this.onSubmit,
    required this.onQuit,
  });

  final PaperSessionState session;
  final VoidCallback onSubmit;
  final VoidCallback onQuit;

  /// Whole-paper time remaining.
  ///
  /// FAST is scored section by section and the notifier ticks
  /// sectionSecondsLeft, leaving globalSecondsLeft untouched — which is why
  /// this read 2:00:00 for ever. Summing what is left across all sections is
  /// the number the real simulator puts here, and it comes from live state.
  String get _clock {
    final s = session.sections.fold<int>(
      0,
      (n, sec) => n + (session.sectionSecondsLeft[sec.config.id] ?? 0),
    );
    final h = (s ~/ 3600).toString();
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h : $m : $sec';
  }

  int get _unanswered {
    var n = 0;
    for (final sec in session.sections) {
      for (final q in sec.questions) {
        if (session.answers[q.id]?.selectedIndex == null) n++;
      }
    }
    return n;
  }

  /// Question number across the whole paper, which is what the real one
  /// shows — "Question # 2/120", not 2 of this section.
  int get _globalIndex {
    var n = 0;
    for (var i = 0; i < session.currentSectionIndex; i++) {
      n += session.sections[i].questions.length;
    }
    return n + session.currentQuestionIndex + 1;
  }

  int get _totalQuestions =>
      session.sections.fold(0, (n, s) => n + s.questions.length);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(paperSessionProvider.notifier);
    final q = session.currentQuestion;
    final selected = session.answers[q.id]?.selectedIndex;

    return Scaffold(
      backgroundColor: FastSim.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  24 + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _questionCard(context, q, selected, notifier),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header: three stacked rows, as the phone layout has it ───────────────

  Widget _header(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            color: FastSim.navy,
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/fast_nu_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'FAST-NU Online Admission Test 2026',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onSubmit();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: FastSim.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 13),
                        SizedBox(width: 5),
                        Text(
                          'Submit Paper',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 0),
            child: Row(
              children: [
                Text(
                  'Time Left: $_clock',
                  style: const TextStyle(
                    color: FastSim.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // The count stays, as a read-out rather than a button. It is
                // the number a student checks before submitting, and the
                // button slot was better spent on moving between sections.
                Text(
                  '$_unanswered unanswered',
                  style: const TextStyle(
                    color: FastSim.greyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 11),
            child: Row(
              children: [
                const Spacer(),
                const Text(
                  '2026 - Engineering & CS',
                  style: TextStyle(
                    color: FastSim.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E8EC)),
        ],
      ),
    );
  }

  // ── The question card ────────────────────────────────────────────────────

  Widget _questionCard(
    BuildContext context,
    Question q,
    int? selected,
    PaperSessionNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: FastSim.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: FastSim.headerTeal,
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question # $_globalIndex/$_totalQuestions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Section: ${session.currentSection.config.label}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'Q) ',
                    style: TextStyle(
                      color: FastSim.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: q.text,
                    style: const TextStyle(
                      color: FastSim.ink,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < q.options.length; i++)
            _option(i, q.options[i], selected == i, notifier),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E8EC)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _controls(context, notifier, selected),
          ),
        ],
      ),
    );
  }

  Widget _option(
    int index,
    String text,
    bool on,
    PaperSessionNotifier notifier,
  ) {
    const letters = ['a', 'b', 'c', 'd', 'e'];
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        notifier.selectOption(index);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 9, 14, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 17,
              height: 17,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? FastSim.blue : const Color(0xFFADB5BD),
                  width: on ? 5 : 1.4,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${letters[index]}) $text',
                style: const TextStyle(
                  color: FastSim.ink,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── The 2x2 control block ────────────────────────────────────────────────

  Widget _controls(
    BuildContext context,
    PaperSessionNotifier notifier,
    int? selected,
  ) {
    final atFirst = session.currentSectionIndex == 0 &&
        session.currentQuestionIndex == 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _button(
                label: 'Reset Choice',
                icon: Icons.refresh,
                fill: FastSim.grey,
                textColor: selected == null
                    ? FastSim.greyText
                    : const Color(0xFF2D3748),
                onTap: selected == null ? null : notifier.clearAnswer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _button(
                label: 'Back',
                icon: Icons.arrow_back,
                iconLeading: true,
                fill: FastSim.blue,
                textColor: Colors.white,
                onTap: atFirst ? null : notifier.previousQuestion,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _button(
                label: 'Next',
                icon: Icons.arrow_forward,
                fill: FastSim.green,
                textColor: Colors.white,
                onTap: notifier.nextQuestion,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _button(
                label: 'Next Section',
                icon: Icons.skip_next,
                iconLeading: true,
                fill: FastSim.blue,
                textColor: Colors.white,
                onTap: session.currentSectionIndex <
                        session.sections.length - 1
                    ? () => notifier
                        .switchToSection(session.currentSectionIndex + 1)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required Color fill,
    required Color textColor,
    required VoidCallback? onTap,
    bool iconLeading = false,
  }) {
    final dim = onTap == null;
    final content = [
      Icon(icon, size: 14, color: textColor.withOpacity(dim ? 0.6 : 1)),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor.withOpacity(dim ? 0.6 : 1),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ];
    return Opacity(
      opacity: dim ? 0.65 : 1,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: iconLeading ? content : content.reversed.toList(),
          ),
        ),
      ),
    );
  }
}
