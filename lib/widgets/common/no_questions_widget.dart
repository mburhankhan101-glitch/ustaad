// lib/widgets/common/no_questions_widget.dart
//
// What a student sees when a subject has no questions behind it yet.
//
// The old behaviour here was a line of grey text reading "No questions
// found.\nCheck your Firestore data." — a note from me to myself that
// shipped to real students. An MBBS student tapping English on MDCAT hit it
// every time, because the MDCAT English bank is still empty.
//
// A section can come up empty for two very different reasons, and they
// deserve different words:
//   • We haven't written those questions yet  → say so, offer other subjects.
//   • Something went wrong fetching them      → offer a retry.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NoQuestionsWidget extends StatelessWidget {
  /// Subject the student tapped, e.g. 'English'. Used in the copy.
  final String section;

  /// Exam it belongs to, e.g. 'MDCAT'.
  final String exam;

  /// Takes them back to the subject list.
  final VoidCallback onBack;

  /// Shown only when this was a failed fetch rather than an empty bank.
  final VoidCallback? onRetry;

  const NoQuestionsWidget({
    super.key,
    required this.section,
    required this.exam,
    required this.onBack,
    this.onRetry,
  });

  bool get _isFetchFailure => onRetry != null;

  @override
  Widget build(BuildContext context) {
    final title = _isFetchFailure
        ? 'Ustu ko ye sawal mil hi nahi rahe 🦉'
        : '$section ke sawal abhi tayyar ho rahe hain ✍️';

    final body = _isFetchFailure
        ? 'Kuch gadbad ho gayi questions laate waqt.\n'
              'Ek dafa phir koshish karo.'
        : 'Hum $exam ke $section section par kaam kar rahe hain. '
              'Jaise hi ready honge, yahin aa jayenge.\n\n'
              'Tab tak koi aur subject try karo — streak toot na jaye!';

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                _isFetchFailure
                    ? 'assets/images/ustu_no_internet.svg'
                    : 'assets/images/book_ustu.svg',
                height: 170,
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.62),
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 30),
              if (_isFetchFailure)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF6C63FF),
                  ),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
              if (_isFetchFailure) const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: onBack,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                  ),
                  child: const Text(
                    'Pick another subject',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Colors.white,
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
}
