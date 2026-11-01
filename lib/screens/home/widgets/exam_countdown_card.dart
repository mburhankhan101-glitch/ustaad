// lib/screens/home/widgets/exam_countdown_card.dart
//
// The countdown to the student's next paper, on the home screen.
//
// One widget carries both states — a date set, and no date set — rather than
// a separate empty-state widget, because the two have to stay in visual step
// and the unset case is a prompt to set it, not an absence. The card is
// always tappable: that is how a date gets set in the first place and how a
// wrong one gets corrected, so there is no settings screen to go hunting in.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/core/analytics/analytics_service.dart';
import 'package:ustaad/core/exam/exam_countdown.dart';
import 'package:ustaad/providers/auth_provider.dart';
import 'package:ustaad/providers/exam_date_provider.dart';
import 'package:ustaad/providers/user_selection_provider.dart';
import 'package:ustaad/screens/home/home_screen.dart'; // UstaadColors

class ExamCountdownCard extends ConsumerWidget {
  const ExamCountdownCard({super.key, this.horizontalPadding = 22});

  /// The home screen's mobile column insets its children by 22; the web
  /// column already has its own padding and passes 0.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTestsProvider).valueOrNull ?? const [];
    final dates = ref.watch(examDatesProvider).valueOrNull ?? const {};

    // Nothing to count down to and nothing to set a date for. A student who
    // has not picked an exam yet is mid-onboarding; prompting them for a date
    // would be asking a question they have not reached.
    if (selected.isEmpty) return const SizedBox.shrink();

    final target = ExamCountdown.nearest(
      dates: dates,
      selectedTests: selected,
      now: DateTime.now(),
    );

    final urgency = ExamCountdown.urgencyFor(target?.daysLeft);
    final accent = _accentFor(urgency);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pickDate(context, ref, selected, dates, target),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: accent.withOpacity(target == null ? 0.06 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withOpacity(target == null ? 0.18 : 0.30),
            ),
          ),
          child: target == null
              ? _unsetBody(accent)
              : _countdownBody(target, accent, urgency),
        ),
      ),
    );
  }

  // ── A date is set ────────────────────────────────────────────────────────

  Widget _countdownBody(ExamTarget target, Color accent, ExamUrgency urgency) {
    return Row(
      children: [
        Text(
          urgency == ExamUrgency.imminent ? '⏰' : '📅',
          style: const TextStyle(fontSize: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // The number carries the message, so it gets the weight —
                  // the same treatment the streak bar gives its own figure.
                  if (target.daysLeft > 1) ...[
                    Text(
                      '${target.daysLeft}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'days to go',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: accent.withOpacity(0.92),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ] else
                    Text(
                      ExamCountdown.phrase(target.daysLeft),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${target.examId} · ${_formatDate(target.date)}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.edit_calendar_outlined,
            size: 18, color: Colors.white.withOpacity(0.35)),
      ],
    );
  }

  // ── No date yet ──────────────────────────────────────────────────────────

  Widget _unsetBody(Color accent) {
    return Row(
      children: [
        const Text('📅', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When is your test?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Set the date and Ustu will count it down with you',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.add_circle_outline, size: 20, color: accent.withOpacity(0.8)),
      ],
    );
  }

  // ── Setting the date ─────────────────────────────────────────────────────

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    List<String> selected,
    Map<String, DateTime> dates,
    ExamTarget? target,
  ) async {
    HapticFeedback.lightImpact();

    // Which exam is being dated. With one selected there is nothing to ask;
    // with several, asking is the only way to know, and guessing would write
    // the date onto the wrong paper.
    final examId = selected.length == 1
        ? selected.first
        : await _askWhichExam(context, selected, dates);
    if (examId == null || !context.mounted) return;

    final now = DateTime.now();
    final existing = dates[examId];
    final picked = await showDatePicker(
      context: context,
      initialDate: existing != null && !existing.isBefore(_today(now))
          ? existing
          : _today(now),
      firstDate: _today(now),
      lastDate: ExamCountdown.lastSensibleDate(now),
      helpText: 'Date of your $examId paper',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: UstaadColors.primary,
            surface: UstaadColors.background2,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    final uid = ref.read(authProvider).user?.uid;
    if (uid == null) return;

    try {
      await saveExamDate(uid: uid, examId: examId, date: picked);
      Analytics.instance.examDateSet(
        exam: examId,
        daysAway: ExamCountdown.daysUntil(picked, DateTime.now()),
      );
      ref.invalidate(examDatesProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: UstaadColors.accent,
          content: Text("Could not save that date: $e"),
        ),
      );
    }
  }

  Future<String?> _askWhichExam(
    BuildContext context,
    List<String> selected,
    Map<String, DateTime> dates,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: UstaadColors.background2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Which test?',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.92),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final id in selected)
              ListTile(
                title: Text(
                  id,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: dates[id] == null
                    ? null
                    : Text(
                        _formatDate(dates[id]!),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                        ),
                      ),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.white38, size: 20),
                onTap: () => Navigator.of(ctx).pop(id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static DateTime _today(DateTime now) =>
      DateTime(now.year, now.month, now.day);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static Color _accentFor(ExamUrgency u) {
    switch (u) {
      case ExamUrgency.imminent:
        return UstaadColors.accent;
      case ExamUrgency.near:
        return UstaadColors.gold;
      case ExamUrgency.calm:
        return UstaadColors.primary;
    }
  }
}
