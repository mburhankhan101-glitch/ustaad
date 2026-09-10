// lib/screens/explanation/explanation_body.dart
//
// The rendered explanation, split out from ExplanationSheet.
//
// The sheet around it needs Riverpod for the credit gate and Firebase for
// analytics, which makes it awkward to test. This part needs neither: it takes
// a string and draws it. Keeping it separate means the thing a student
// actually reads can be pumped in a widget test without a Firebase app.

import 'package:flutter/material.dart';
import 'package:ustaad/models/explanation.dart';
import 'package:ustaad/models/question_model.dart';

class ExplanationColors {
  static const primary = Color(0xFF6C63FF);
  static const gold = Color(0xFFFFD700);
  static const accent = Color(0xFFFF6B6B);
}

/// Renders a stored explanation as the four labelled parts it is made of.
///
/// The whole string used to go into a single Text at 13pt and 82% opacity, so
/// "Concept:", "Solution:", and every step number appeared as literal grey
/// characters inside one paragraph, to a student who had just got the question
/// wrong.
class ExplanationBody extends StatefulWidget {
  final Question question;

  /// The already-loaded explanation, in whichever language is selected.
  final String explanation;

  /// Which option the student picked, when known.
  final int? selectedIndex;

  const ExplanationBody({
    super.key,
    required this.question,
    required this.explanation,
    this.selectedIndex,
  });

  @override
  State<ExplanationBody> createState() => _ExplanationBodyState();
}

class _ExplanationBodyState extends State<ExplanationBody> {
  late Explanation _parsed;
  late int _stepsShown;
  bool _trickOpen = false;
  bool _mistakeOpen = false;

  bool get _answeredWrong =>
      widget.selectedIndex != null &&
      widget.selectedIndex != widget.question.correctIndex;

  List<String> get _steps => _parsed.partFor('Solution')?.steps ?? const [];

  @override
  void initState() {
    super.initState();
    _reparse();
  }

  @override
  void didUpdateWidget(covariant ExplanationBody old) {
    super.didUpdateWidget(old);
    // The language toggle swaps the string in place.
    if (old.explanation != widget.explanation) {
      setState(_reparse);
    }
  }

  void _reparse() {
    _parsed = Explanation.parse(widget.explanation);
    // A student who got it wrong is walked through the working one step at a
    // time, because that is how it would be explained to them in person and
    // because tapping through it is the difference between reading and
    // following. Anyone who got it right, or is only reviewing, gets the whole
    // thing at once; they do not need to be taught it again.
    _stepsShown = _answeredWrong ? 1 : _steps.length;
    _trickOpen = false;
    _mistakeOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.explanation.trim().isEmpty) {
      return Text(
        'Is sawal ki explanation abhi tayar ho rahi hai.',
        key: const Key('explanation-empty'),
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
          height: 1.6,
        ),
      );
    }

    final rtl = isRtlText(widget.explanation);
    final concept = _parsed.partFor('Concept');
    final solution = _parsed.partFor('Solution');
    final trick = _parsed.partFor('Trick');
    final mistake = _parsed.partFor('Mistake');

    // An explanation written in some other shape still has to render, so fall
    // back to the raw prose rather than showing an empty sheet.
    if (concept == null && solution == null) {
      return _prose(widget.explanation, rtl, const Key('explanation-fallback'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_answeredWrong) ...[
          _yourAnswer(),
          const SizedBox(height: 18),
        ],
        if (concept != null) ...[
          _partLabel('The idea', Icons.lightbulb_outline_rounded,
              ExplanationColors.primary),
          const SizedBox(height: 8),
          _prose(concept.body, rtl, const Key('explanation-concept')),
          const SizedBox(height: 20),
        ],
        if (solution != null) ...[
          _partLabel('Working', Icons.route_rounded, ExplanationColors.primary),
          const SizedBox(height: 10),
          if (solution.hasSteps)
            _stepList(solution.steps, rtl)
          else
            _prose(solution.body, rtl, const Key('explanation-solution')),
          const SizedBox(height: 20),
        ],
        // Trick and Mistake are depth, not the answer. Collapsed by default so
        // the sheet opens on the working, and because opening one is a tap the
        // student chose to make.
        if (trick != null)
          _callout(
            key: const Key('explanation-trick'),
            title: 'Exam trick',
            icon: Icons.bolt_rounded,
            color: ExplanationColors.gold,
            body: trick.body,
            open: _trickOpen,
            rtl: rtl,
            onTap: () => setState(() => _trickOpen = !_trickOpen),
          ),
        if (mistake != null) ...[
          const SizedBox(height: 10),
          _callout(
            key: const Key('explanation-mistake'),
            title: _mistakeNamesTheirAnswer(mistake.body)
                ? 'Yehi galti aap ne ki'
                : 'Aam galti',
            icon: Icons.error_outline_rounded,
            color: ExplanationColors.accent,
            body: mistake.body,
            open: _mistakeOpen || _mistakeNamesTheirAnswer(mistake.body),
            rtl: rtl,
            onTap: () => setState(() => _mistakeOpen = !_mistakeOpen),
          ),
        ],
      ],
    );
  }

  /// Whether the stored Mistake actually names the option this student picked.
  ///
  /// Checked rather than assumed: the sheet only says "you made this mistake"
  /// when the explanation really is describing their answer.
  bool _mistakeNamesTheirAnswer(String mistakeBody) {
    if (!_answeredWrong) return false;
    final picked = widget.question.options[widget.selectedIndex!].trim();
    if (picked.length < 3) return false;
    return mistakeBody.toLowerCase().contains(picked.toLowerCase());
  }

  /// Opens the explanation on the answer this student actually chose.
  Widget _yourAnswer() {
    final i = widget.selectedIndex!;
    final letter = const ['A', 'B', 'C', 'D'][i];
    return Container(
      key: const Key('explanation-your-answer'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ExplanationColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ExplanationColors.accent.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ExplanationColors.accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aap ne yeh chuna tha',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: ExplanationColors.accent.withValues(alpha: 0.9),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.question.options[i],
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepList(List<String> steps, bool rtl) {
    final shown = _stepsShown.clamp(0, steps.length);
    final remaining = steps.length - shown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _stepRow(i + 1, steps[i], rtl),
          ),
        if (remaining > 0)
          Row(
            children: [
              _stepButton(
                key: const Key('explanation-next-step'),
                label: 'Agla step',
                filled: true,
                onTap: () => setState(() => _stepsShown++),
              ),
              const SizedBox(width: 10),
              _stepButton(
                key: const Key('explanation-show-all'),
                label: 'Sab dikhayein',
                filled: false,
                onTap: () => setState(() => _stepsShown = steps.length),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '$remaining baaki',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _stepRow(int n, String text, bool rtl) {
    final row = <Widget>[
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: ExplanationColors.primary.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: ExplanationColors.primary.withValues(alpha: 0.38),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$n',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: _prose(text, rtl, null)),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rtl ? row.reversed.toList() : row,
    );
  }

  Widget _stepButton({
    required Key key,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? ExplanationColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? ExplanationColors.primary
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.65),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _partLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 7),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Poppins',
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _callout({
    required Key key,
    required String title,
    required IconData icon,
    required Color color,
    required String body,
    required bool open,
    required bool rtl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: open ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: open ? 0.32 : 0.16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: color.withValues(alpha: 0.7),
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 9),
              _prose(body, rtl, null),
            ],
          ],
        ),
      ),
    );
  }

  /// Body text.
  ///
  /// Direction comes from the string, not from the language toggle. 1,599 of
  /// the 1,819 Urdu explanations in the bank are roman Urdu written in the
  /// Latin alphabet, and every one of them was being laid out right to left.
  Widget _prose(String text, bool rtl, Key? key) {
    return Text(
      text,
      key: key,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white.withValues(alpha: 0.86),
        fontSize: rtl ? 16 : 13.5,
        height: rtl ? 2.0 : 1.65,
      ),
    );
  }
}
