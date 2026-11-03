// lib/screens/home/widgets/exam_debrief_sheet.dart
//
// Asks a student how their paper went, once, the day after they sat it.
//
// Two things shaped this. It has to be answerable in one tap, because a
// student who has just had a bad exam will not fill in a form — so the mood
// buttons submit on their own and the text box is optional. And whatever they
// say has to be answered, by name and in Ustu's voice, because the point is
// not collecting data. A student who types something painful and gets a grey
// "Submitted" toast has been processed, not heard.
//
// It is raised through UstuOverlays so it takes its turn in the shared queue
// rather than landing on top of a streak celebration.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ustaad/core/exam/exam_countdown.dart';
import 'package:ustaad/screens/home/home_screen.dart'; // UstaadColors

class ExamDebriefSheet extends StatefulWidget {
  const ExamDebriefSheet({
    super.key,
    required this.examId,
    required this.firstName,
    required this.onSubmit,
  });

  final String examId;

  /// Used once, in the acknowledgement. Empty is fine and the copy adapts.
  final String firstName;

  /// Persists the answer. Returning false shows the retry line rather than
  /// pretending it was saved.
  final Future<bool> Function(ExamMood mood, String note) onSubmit;

  @override
  State<ExamDebriefSheet> createState() => _ExamDebriefSheetState();
}

class _ExamDebriefSheetState extends State<ExamDebriefSheet> {
  final _note = TextEditingController();
  ExamMood? _mood;
  bool _sending = false;
  bool _sent = false;
  bool _failed = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mood = _mood;
    if (mood == null || _sending) return;
    setState(() {
      _sending = true;
      _failed = false;
    });
    FocusScope.of(context).unfocus();

    final ok = await widget.onSubmit(mood, _note.text.trim());
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = ok;
      _failed = !ok;
    });
    if (ok) HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: const BoxDecoration(
            color: UstaadColors.background2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              // Lifts the sheet clear of the keyboard when the note is open.
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _sent ? _thanks() : _ask(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Asking ───────────────────────────────────────────────────────────────

  Widget _ask() {
    return Column(
      key: const ValueKey('ask'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grabber(),
        Center(
          child: SvgPicture.asset(
            'assets/images/exam_ustu.svg',
            height: 110,
            placeholderBuilder: (_) => const SizedBox(height: 110),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'How did ${widget.examId} go?',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "No right answer here. I just want to know how you're doing.",
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.62),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        for (final mood in ExamMood.values) ...[
          _moodButton(mood),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 7),
        TextField(
          controller: _note,
          maxLines: 4,
          minLines: 3,
          maxLength: 1000,
          enabled: !_sending,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 14,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: 'Anything you want to get off your chest? (optional)',
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            counterStyle: TextStyle(color: Colors.white.withOpacity(0.28)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: UstaadColors.primary),
            ),
          ),
        ),
        if (_failed) ...[
          const SizedBox(height: 4),
          Text(
            "That didn't send. Have another go?",
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: UstaadColors.accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _sending
                    ? null
                    : () => Navigator.of(context).maybePop(),
                child: Text(
                  'Not now',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _mood == null || _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UstaadColors.primary,
                  disabledBackgroundColor: Colors.white.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Send',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: _mood == null
                              ? Colors.white.withOpacity(0.35)
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _moodButton(ExamMood mood) {
    final selected = _mood == mood;
    final tint = _tintFor(mood);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _sending
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _mood = mood);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? tint.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? tint.withOpacity(0.75) : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(_emojiFor(mood), style: const TextStyle(fontSize: 19)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mood.label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: selected ? Colors.white : Colors.white.withOpacity(0.82),
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: tint, size: 19),
          ],
        ),
      ),
    );
  }

  // ── Answering ────────────────────────────────────────────────────────────

  Widget _thanks() {
    final mood = _mood ?? ExamMood.mixed;
    final name = widget.firstName.trim();
    return Column(
      key: const ValueKey('thanks'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grabber(),
        Center(
          child: SvgPicture.asset(
            'assets/images/chai_ustu.svg',
            height: 128,
            placeholderBuilder: (_) => const SizedBox(height: 128),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          name.isEmpty ? 'Thank you for telling me.' : 'Thank you, $name.',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _replyFor(mood),
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.74),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.55,
          ),
        ),
        if (_note.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: UstaadColors.primary, width: 2.5),
              ),
            ),
            child: Text(
              'I have read what you wrote, and it has gone to the person who '
              'builds Ustaad.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.68),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: UstaadColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Thanks, Ustu',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// What Ustu says back. Written so that none of the three answers is
  /// treated as the wrong one, and so the rough case is not met with
  /// cheerfulness, which is what makes encouragement feel automated.
  static String _replyFor(ExamMood mood) {
    switch (mood) {
      case ExamMood.good:
        return 'That is good to hear. You did the work for it, and days like '
            'that are earned rather than lucky. Rest it off before the next one.';
      case ExamMood.mixed:
        return 'That is how most papers feel on the way out, and it is very '
            'often better than it felt. You turned up and you finished it, '
            'which is the part you control.';
      case ExamMood.rough:
        return 'I am sorry it went that way. One paper is not the whole story '
            'and it is not a verdict on you. Be kind to yourself today, and I '
            'will be here when you want to pick things back up.';
    }
  }

  static String _emojiFor(ExamMood mood) {
    switch (mood) {
      case ExamMood.good:
        return '😄';
      case ExamMood.mixed:
        return '😐';
      case ExamMood.rough:
        return '😞';
    }
  }

  static Color _tintFor(ExamMood mood) {
    switch (mood) {
      case ExamMood.good:
        return UstaadColors.success;
      case ExamMood.mixed:
        return UstaadColors.gold;
      case ExamMood.rough:
        return UstaadColors.accent;
    }
  }

  Widget _grabber() => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
