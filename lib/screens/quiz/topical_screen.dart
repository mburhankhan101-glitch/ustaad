// lib/screens/quiz/topical_screen.dart
//
// The Topical tab: pick a test, a subject, then a chapter.
//
// This replaced the old Quiz tab, which opened a bottom sheet over home. A
// sheet is somewhere you pass through, and choosing what to study is not a
// passing decision — it wants a place you can be, go back in, and change your
// mind. The first attempt at this feature put a second small icon inside the
// home section cards instead, where one stray tap started a random quiz
// rather than opening the chapter list. Two actions in one tile is a trap.
//
// So: home stays the one-tap "give me a quiz" screen, and everything
// deliberate lives here.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/user_selection_provider.dart';
import 'package:ustaad/screens/home/home_screen.dart'
    show ExamTab, QuizSection, UstaadColors, visibleExamTabs;
import 'package:ustaad/screens/quiz/topic_practice_screen.dart';

class TopicalScreen extends ConsumerStatefulWidget {
  const TopicalScreen({super.key});

  @override
  ConsumerState<TopicalScreen> createState() => _TopicalScreenState();
}

class _TopicalScreenState extends ConsumerState<TopicalScreen> {
  int _exam = 0;

  void _openSection(ExamTab tab, QuizSection s) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => TopicPracticeScreen(
          // NTS stores its questions under 'NTS' while the tab's id is
          // 'NAT-NTS'; label is the one that matches the bank.
          exam: tab.label,
          section: s.dbSection,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTestsProvider).valueOrNull ?? const [];
    final tabs = visibleExamTabs(selected);
    final index = _exam.clamp(0, tabs.length - 1);
    final tab = tabs[index];

    return Scaffold(
      backgroundColor: UstaadColors.background1,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          children: [
            const Text(
              'Topical practice',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Pick a subject, then the chapter you want to work on.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),

            if (tabs.length > 1) ...[
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final on = i == index;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _exam = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: on ? UstaadColors.primary : Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: on
                                ? const Color(0xFF8B84FF).withOpacity(0.6)
                                : Colors.white10,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            tabs[i].label,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: on
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.65),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],

            for (final s in tab.sections) _sectionRow(tab, s),
          ],
        ),
      ),
    );
  }

  Widget _sectionRow(ExamTab tab, QuizSection s) {
    final enabled = !s.comingSoon;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _openSection(tab, s) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.barColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(s.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.comingSoon
                            ? 'No questions here yet'
                            : 'Browse chapters',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.35),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
