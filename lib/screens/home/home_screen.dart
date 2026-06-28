import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ustaad/screens/papers/paper_selection_screen.dart';
import 'package:ustaad/screens/quiz/quiz_screen.dart';
import 'package:ustaad/screens/profile/profile_screen.dart';
import 'package:ustaad/providers/progress_provider.dart';
import 'package:ustaad/providers/auth_provider.dart';
import 'package:ustaad/core/utils/ustu_overlays.dart';
import 'package:ustaad/core/utils/connectivity_service.dart';
import 'package:ustaad/services/haptic_service.dart';

class UstaadColors {
  static const Color background1 = Color(0xFF0A0E2E);
  static const Color background2 = Color(0xFF1A1464);
  static const Color background3 = Color(0xFF6C63FF);
  static const Color primary = Color(0xFF6C63FF);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4CAF50);
  static const Color gold = Color(0xFFFFD700);
}

final currentUserProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).user?.displayName;
});

class QuizSection {
  final String emoji;
  final String title;
  final String weightLabel;
  final String dbSection;
  final double progress;
  final Color barColor;
  const QuizSection({
    required this.emoji,
    required this.title,
    required this.weightLabel,
    required this.dbSection,
    this.progress = 0.0,
    required this.barColor,
  });
}

const _fastNuSections = [
  QuizSection(
    emoji: '📐',
    title: 'Advanced Maths',
    dbSection: 'Advanced Maths',
    weightLabel: '50% of FAST-NU',
    barColor: UstaadColors.primary,
  ),
  QuizSection(
    emoji: '🔢',
    title: 'Basic Maths',
    dbSection: 'Quantitative',
    weightLabel: '20% of FAST-NU',
    barColor: UstaadColors.success,
  ),
  QuizSection(
    emoji: '🧩',
    title: 'IQ & Analytical',
    dbSection: 'Analytical',
    weightLabel: '20% of FAST-NU',
    barColor: UstaadColors.gold,
  ),
  QuizSection(
    emoji: '📝',
    title: 'English',
    dbSection: 'English',
    weightLabel: '10% of FAST-NU',
    barColor: UstaadColors.success,
  ),
];
const _nustNetSections = [
  QuizSection(
    emoji: '📐',
    title: 'Maths',
    dbSection: 'Quantitative',
    weightLabel: '50% of NUST-NET',
    barColor: UstaadColors.primary,
  ),
  QuizSection(
    emoji: '⚡',
    title: 'Physics',
    dbSection: 'Physics',
    weightLabel: '30% of NUST-NET',
    barColor: UstaadColors.accent,
  ),
  QuizSection(
    emoji: '📝',
    title: 'English',
    dbSection: 'English',
    weightLabel: '20% of NUST-NET',
    barColor: UstaadColors.success,
  ),
];
const _ntsSections = [
  QuizSection(
    emoji: '📐',
    title: 'Quantitative',
    dbSection: 'Quantitative',
    weightLabel: '20% of NTS',
    barColor: UstaadColors.primary,
  ),
  QuizSection(
    emoji: '📝',
    title: 'English',
    dbSection: 'English',
    weightLabel: '20% of NTS',
    barColor: UstaadColors.success,
  ),
  QuizSection(
    emoji: '🧩',
    title: 'IQ & Analytical',
    dbSection: 'Analytical',
    weightLabel: '20% of NTS',
    barColor: UstaadColors.gold,
  ),
  QuizSection(
    emoji: '⚡',
    title: 'Computer Science',
    dbSection: 'Computer Science',
    weightLabel: '30% of NTS',
    barColor: UstaadColors.accent,
  ),
];

class ExamTab {
  final String label;
  final List<QuizSection> sections;
  const ExamTab({required this.label, required this.sections});
}

const _examTabs = [
  ExamTab(label: 'FAST-NU', sections: _fastNuSections),
  ExamTab(label: 'NUST-NET', sections: _nustNetSections),
  ExamTab(label: 'NTS', sections: _ntsSections),
];

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

const _navItems = [
  _NavItem(icon: Icons.home_rounded, label: 'Home'),
  _NavItem(icon: Icons.quiz_rounded, label: 'Quiz'),
  _NavItem(icon: Icons.description_rounded, label: 'Papers'),
  _NavItem(icon: Icons.person_rounded, label: 'Profile'),
];

const int kDailyGoal = 20;

// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedExam = 0;
  int _selectedNav = 0;

  String? _cachedGreeting;
  bool _weakTopicShown = false;
  bool _brokenStreakShown = false;

  AnimationController? _entranceCtrl;
  Animation<double>? _headerAnim;
  Animation<double>? _streakAnim;
  Animation<double>? _statsAnim;
  Animation<double>? _continueAnim;
  Animation<double>? _quizAnim;
  bool _entrancePlayed = false;

  static final _noAnim = AlwaysStoppedAnimation<double>(1.0);

  // ── Topic → Section lookup (Bug 1 fix) ─────────────────────────────────
  static const Map<String, Map<String, String>> _topicSectionMap = {
    'FAST-NU': {
      'Number Series': 'Analytical',
      // Add more as needed
    },
    'NTS': {
      'Number Series': 'Analytical',
      // Add more as needed
    },
    // NUST-NET topics if any
  };

  String _getSectionForTopic(String exam, String topic) {
    final examMap = _topicSectionMap[exam];
    if (examMap != null && examMap.containsKey(topic)) {
      return examMap[topic]!;
    }
    // fallback – empty string will prevent the overlay from opening a quiz with wrong section
    return '';
  }

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      duration: const Duration(milliseconds: 680),
      vsync: this,
    );
    _setupEntranceAnims();
  }

  void _setupEntranceAnims() {
    final ctrl = _entranceCtrl;
    if (ctrl == null) return;
    Animation<double> s(double b, double e) => CurvedAnimation(
      parent: ctrl,
      curve: Interval(b, e, curve: Curves.easeOut),
    );
    _headerAnim = s(0.00, 0.50);
    _streakAnim = s(0.14, 0.64);
    _statsAnim = s(0.26, 0.76);
    _continueAnim = s(0.36, 0.86);
    _quizAnim = s(0.44, 1.00);
  }

  @override
  void dispose() {
    _entranceCtrl?.dispose();
    super.dispose();
  }

  late final List<Widget> _screens = [
    const SizedBox.shrink(),
    const SizedBox.shrink(),
    const PaperSelectionScreen(),
    const ProfileScreen(),
  ];

  String _simpleGreeting(String firstName) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good Morning, $firstName 👋';
    if (h >= 12 && h < 17) return 'Back at it, $firstName 💪';
    if (h >= 17 && h < 21) return 'Evening grind, $firstName 🌙';
    return 'Still up, $firstName ☕';
  }

  String _firstName() {
    final name = ref.watch(currentUserProvider);
    if (name == null || name.trim().isEmpty) return 'Student';
    return name.trim().split(' ').first;
  }

  String _initials() {
    final name = ref.watch(currentUserProvider);
    if (name == null || name.trim().isEmpty) return 'ST';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _openQuiz(
    String exam,
    String section, {
    int initialIndex = 0,
    String? topic,
    int limit = 10,
    bool isWeakTopicPractice = false, // ← Bug 2 flag
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => QuizScreen(
          exam: exam,
          section: section,
          initialIndex: initialIndex,
          topic: topic,
          limit: limit,
          isWeakTopicPractice: isWeakTopicPractice, // ← pass it
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    ).then((_) => setState(() => _selectedNav = 0));
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _dateString(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _writeWeakTopicShownDate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'lastWeakTopicShownDate': _todayString(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _writeBrokenStreakShownDate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'lastBrokenStreakShownDate': _todayString(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _showBrokenStreakOverlay(String name) {
    _writeBrokenStreakShownDate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UstuOverlays.showBrokenStreak(context, name: name);
    });
  }

  void _showWeakTopicOverlay({
    required String topTopic,
    required int topCount,
    required String exam,
    required String section,
  }) {
    _writeWeakTopicShownDate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UstuOverlays.showWeakTopicOverlay(
          context,
          topic: topTopic,
          wrongCount: topCount,
          exam: exam,
          section: section,
          onPracticeNow: () => _openQuiz(
            exam,
            section,
            topic: topTopic,
            limit: 4,
            isWeakTopicPractice: true, // ← Bug 2 flag
          ),
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(userProgressProvider);
    final isWeb = MediaQuery.of(context).size.width > 600;

    return progressAsync.when(
      loading: () => Scaffold(
        backgroundColor: UstaadColors.background1,
        body: Center(child: _UstuLoader()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: UstaadColors.background1,
        body: NoInternetWidget(
          onRetry: () async {
            final isOnline = await ConnectivityService().isOnline();
            if (isOnline) ref.invalidate(userProgressProvider);
          },
        ),
      ),
      data: (progressData) {
        final int streak = progressData?['streak'] as int? ?? 0;
        final String lastActiveDate =
            progressData?['lastActiveDate'] as String? ?? '';
        final int solvedToday = progressData?['solvedToday'] as int? ?? 0;
        final double accuracy =
            (progressData?['accuracy'] as num?)?.toDouble() ?? 0.0;
        final bool isNewUser = progressData == null;
        final Map<String, dynamic> sectionMap =
            progressData?['progress'] as Map<String, dynamic>? ?? {};
        final incompleteSession =
            progressData?['incompleteSession'] as Map<String, dynamic>?;

        // ── Weak topics ──────────────────────────────────────────────────
        final weakTopics = progressData?['weakTopics'] as Map<String, dynamic>?;
        final weakTopicExam = progressData?['weakTopicExam'] as String? ?? '';
        final weakTopicSection =
            progressData?['weakTopicSection'] as String? ?? '';
        // Per-topic section map written by saveWeakTopics() in firestore_service.
        // e.g. { "Trigonometry": "Advanced Maths", "Grammar": "English" }
        // This is the source of truth — prevents section/topic mismatch.
        final weakTopicSections =
            progressData?['weakTopicSections'] as Map<String, dynamic>? ?? {};

        if (!_weakTopicShown &&
            weakTopics != null &&
            weakTopics.isNotEmpty &&
            weakTopicExam.isNotEmpty) {
          final today = _todayString();
          final lastShown =
              progressData?['lastWeakTopicShownDate'] as String? ?? '';
          if (lastShown != today) {
            _weakTopicShown = true;
            final topEntry = weakTopics.entries.reduce(
              (a, b) => (a.value as num) >= (b.value as num) ? a : b,
            );

            // Priority order for section resolution:
            // 1. Per-topic section from weakTopicSections (most accurate)
            // 2. Static _topicSectionMap lookup (hardcoded fallback)
            // 3. weakTopicSection (last-session fallback, may be wrong)
            final perTopicSection =
                weakTopicSections[topEntry.key] as String? ?? '';
            final lookedUpSection = _getSectionForTopic(
              weakTopicExam,
              topEntry.key,
            );
            final correctSection = perTopicSection.isNotEmpty
                ? perTopicSection
                : lookedUpSection.isNotEmpty
                ? lookedUpSection
                : weakTopicSection;

            if (correctSection.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted)
                  _showWeakTopicOverlay(
                    topTopic: topEntry.key,
                    topCount: (topEntry.value as num).toInt(),
                    exam: weakTopicExam,
                    section: correctSection,
                  );
              });
            }
          } else {
            _weakTopicShown = true;
          }
        }

        // ── Broken streak ────────────────────────────────────────────────
        if (!_brokenStreakShown) {
          final today = _todayString();
          final yesterday = _dateString(
            DateTime.now().subtract(const Duration(days: 1)),
          );
          final bool broken =
              streak == 0 &&
              lastActiveDate.isNotEmpty &&
              lastActiveDate != today &&
              lastActiveDate != yesterday;
          final lastShownBroken =
              progressData?['lastBrokenStreakShownDate'] as String? ?? '';
          if (broken && lastShownBroken != today) {
            _brokenStreakShown = true;
            _showBrokenStreakOverlay(_firstName());
          } else {
            _brokenStreakShown = true;
          }
        }

        final name = _firstName();
        if (_cachedGreeting == null || name != 'Student') {
          _cachedGreeting ??= getGreeting(name);
        }

        if (!_entrancePlayed) {
          _entrancePlayed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _entranceCtrl?.forward();
          });
        }

        // ════════════════════════════════════════════════════════════════
        // WEB LAYOUT — Sidebar + Main content
        // ════════════════════════════════════════════════════════════════
        if (isWeb) {
          return Scaffold(
            backgroundColor: UstaadColors.background1,
            body: Stack(
              children: [
                _buildGradient(),
                Row(
                  children: [
                    _buildWebSidebar(),
                    Container(width: 1, color: Colors.white.withOpacity(0.06)),
                    Expanded(
                      child: _selectedNav == 0
                          ? SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                36,
                                32,
                                36,
                                40,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FadeSlide(
                                    animation: _headerAnim ?? _noAnim,
                                    slideDown: true,
                                    child: _buildWebHeader(),
                                  ),
                                  const SizedBox(height: 20),
                                  _FadeSlide(
                                    animation: _streakAnim ?? _noAnim,
                                    child: _buildWebStatsBar(
                                      streak,
                                      lastActiveDate,
                                      solvedToday,
                                      accuracy,
                                      isNewUser,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (incompleteSession != null) ...[
                                    _FadeSlide(
                                      animation: _continueAnim ?? _noAnim,
                                      child: _buildContinueCard(
                                        incompleteSession,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  _FadeSlide(
                                    animation: _quizAnim ?? _noAnim,
                                    child: _buildQuizSection(sectionMap),
                                  ),
                                ],
                              ),
                            )
                          : IndexedStack(
                              index: _selectedNav,
                              children: _screens,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // ════════════════════════════════════════════════════════════════
        // MOBILE LAYOUT
        // ════════════════════════════════════════════════════════════════
        return Scaffold(
          backgroundColor: UstaadColors.background1,
          body: _selectedNav == 0
              ? Stack(
                  children: [
                    _buildGradient(),
                    SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 96),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FadeSlide(
                              animation: _headerAnim ?? _noAnim,
                              slideDown: true,
                              child: _buildHeader(),
                            ),
                            const SizedBox(height: 24),
                            _FadeSlide(
                              animation: _streakAnim ?? _noAnim,
                              child: _buildStreakBar(
                                streak,
                                lastActiveDate,
                                isNewUser,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _FadeSlide(
                              animation: _statsAnim ?? _noAnim,
                              child: _buildStatsRow(
                                solvedToday,
                                accuracy,
                                isNewUser,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (incompleteSession != null) ...[
                              _FadeSlide(
                                animation: _continueAnim ?? _noAnim,
                                child: _buildContinueCard(incompleteSession),
                              ),
                              const SizedBox(height: 20),
                            ],
                            _FadeSlide(
                              animation: _quizAnim ?? _noAnim,
                              child: _buildQuizSection(sectionMap),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomNav(context),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    _buildGradient(),
                    IndexedStack(index: _selectedNav, children: _screens),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomNav(context),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WEB-ONLY WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  // ── Sidebar ───────────────────────────────────────────────────────────────
  Widget _buildWebSidebar() {
    return Container(
      width: 240,
      color: Colors.black.withOpacity(0.30),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
              child: Row(
                children: [
                  const Text('🦉', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ustaad',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'APNA USTAAD',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.50),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Section label
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'MENU',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.40),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            // Nav items
            _buildSidebarNavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              onTap: () => setState(() => _selectedNav = 0),
            ),
            _buildSidebarNavItem(
              icon: Icons.quiz_rounded,
              label: 'Practice Quiz',
              index: 1,
              onTap: _showQuizPicker,
            ),
            _buildSidebarNavItem(
              icon: Icons.description_rounded,
              label: 'Past Papers',
              index: 2,
              onTap: () => setState(() => _selectedNav = 2),
            ),
            _buildSidebarNavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              index: 3,
              onTap: () => setState(() => _selectedNav = 3),
            ),

            const Spacer(),

            // Start Quiz CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GestureDetector(
                onTap: _showQuizPicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: UstaadColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: UstaadColors.primary.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '⚡  Start Quiz',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final bool isActive = _selectedNav == index;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isActive
              ? UstaadColors.primary.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: UstaadColors.primary.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.55),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: isActive ? Colors.white : Colors.white.withOpacity(0.55),
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Web header ────────────────────────────────────────────────────────────
  Widget _buildWebHeader() {
    final firstName = _firstName();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _simpleGreeting(firstName),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 28.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _cachedGreeting ?? 'Your Ustaad is ready 📚',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  height: 1.43,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [UstaadColors.primary, UstaadColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(),
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── Web unified stats bar ─────────────────────────────────────────────────
  // All three stats (streak + goal + accuracy) in one clean horizontal bar.
  Widget _buildWebStatsBar(
    int streak,
    String lastActiveDate,
    int solvedToday,
    double accuracy,
    bool isNewUser,
  ) {
    final msg = streakMessage(
      isNewUser ? 0 : streak,
      isNewUser ? '' : lastActiveDate,
    );
    final streakColor = msg.isRoast ? UstaadColors.accent : UstaadColors.gold;

    final double goalProgress = isNewUser
        ? 0.0
        : (solvedToday / kDailyGoal).clamp(0.0, 1.0);
    final bool goalDone = solvedToday >= kDailyGoal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // ── Streak ──────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                Text(
                  msg.isRoast ? '💀' : '🔥',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          streak.toString(),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: streakColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'day streak',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: streakColor.withOpacity(0.55),
                            fontSize: 9.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${msg.emoji} ${msg.text}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: streakColor.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.08),
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),

          // ── Today's goal ─────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Today's Goal",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            '${isNewUser ? 0 : solvedToday}/$kDailyGoal',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: goalDone
                                  ? UstaadColors.success
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: goalProgress,
                          minHeight: 7,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goalDone
                                ? UstaadColors.success
                                : UstaadColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goalDone
                            ? '🎉 Goal smashed today!'
                            : isNewUser
                            ? 'Start your first quiz!'
                            : solvedToday == 0
                            ? 'Aaj kuch nahi kiya 👀'
                            : '${kDailyGoal - solvedToday} more to go 💪',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: goalDone
                              ? UstaadColors.success
                              : Colors.white.withOpacity(0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.08),
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),

          // ── Accuracy ─────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 23)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNewUser ? '—' : '${accuracy.round()}%',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Overall accuracy',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isNewUser ? 'No data yet' : '↑ improving',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isNewUser
                            ? Colors.white30
                            : const Color(0xFF9B94FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED / MOBILE WIDGETS — ALL UNCHANGED
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            UstaadColors.background1,
            UstaadColors.background2,
            UstaadColors.background3,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final firstName = _firstName();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _simpleGreeting(firstName),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _cachedGreeting ?? 'Your Ustaad is ready 📚',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [UstaadColors.primary, UstaadColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(),
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBar(int streak, String lastActiveDate, bool isNewUser) {
    final msg = streakMessage(
      isNewUser ? 0 : streak,
      isNewUser ? '' : lastActiveDate,
    );
    final Color msgColor = msg.isRoast
        ? UstaadColors.accent
        : UstaadColors.gold;
    final Color cardColor = msg.isRoast
        ? UstaadColors.accent.withOpacity(0.10)
        : UstaadColors.gold.withOpacity(0.12);
    final Color borderColor = msg.isRoast
        ? UstaadColors.accent.withOpacity(0.30)
        : UstaadColors.gold.withOpacity(0.28);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Text(
              msg.isRoast ? '💀' : '🔥',
              style: const TextStyle(fontSize: 28),
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
                      Text(
                        streak.toString(),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: msgColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'day streak',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: msgColor.withOpacity(0.55),
                          fontSize: 10,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${msg.emoji}  ${msg.text}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: msgColor.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int solvedToday, double accuracy, bool isNewUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(child: _goalCard(solvedToday, isNewUser)),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              number: isNewUser ? '—' : '${accuracy.round()}%',
              label: 'Overall accuracy',
              sub: isNewUser ? 'No data yet' : '↑ improving',
              subColor: isNewUser ? Colors.white30 : const Color(0xFF9B94FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(int solvedToday, bool isNewUser) {
    final double progress = isNewUser
        ? 0.0
        : (solvedToday / kDailyGoal).clamp(0.0, 1.0);
    final bool goalDone = solvedToday >= kDailyGoal;
    final int remaining = isNewUser
        ? kDailyGoal
        : (kDailyGoal - solvedToday).clamp(0, kDailyGoal);

    final String subText;
    final Color subColor;
    if (isNewUser) {
      subText = 'Start your first quiz!';
      subColor = UstaadColors.primary.withOpacity(0.8);
    } else if (goalDone) {
      subText = '🎯 Goal smashed today!';
      subColor = UstaadColors.success;
    } else if (solvedToday == 0) {
      subText = 'Aaj kuch nahi kiya 👀';
      subColor = UstaadColors.accent.withOpacity(0.8);
    } else if (remaining <= 5) {
      subText = '⚡ Bas $remaining aur — itna toh hoga!';
      subColor = UstaadColors.gold;
    } else {
      subText = '$remaining more to go 💪';
      subColor = UstaadColors.primary.withOpacity(0.85);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Goal",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
              Text(
                '${isNewUser ? 0 : solvedToday}/$kDailyGoal',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: goalDone ? UstaadColors.success : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                goalDone ? UstaadColors.success : UstaadColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subText,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: subColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String number,
    required String label,
    required String sub,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: subColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueCard(Map<String, dynamic> session) {
    final String exam = session['exam'] as String? ?? '';
    final String section = session['section'] as String? ?? '';
    final int currentIndex = session['currentIndex'] as int? ?? 0;
    final int total = session['totalQuestions'] as int? ?? 10;
    final int displayQ = (currentIndex + 1).clamp(1, total);
    final double progress = currentIndex / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: GestureDetector(
        onTap: () => _openQuiz(exam, section, initialIndex: currentIndex),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: UstaadColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: UstaadColors.primary.withOpacity(0.55),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: UstaadColors.primary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continue where you left off',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$section · $exam',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          UstaadColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Q$displayQ of $total  ·  ${(progress * 100).round()}% complete',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white30,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizSection(Map<String, dynamic> sectionMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: const Text(
            'Practice Quiz',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: _examTabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final selected = i == _selectedExam;
              return GestureDetector(
                onTap: () => setState(() => _selectedExam = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? UstaadColors.primary : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF8B84FF).withOpacity(0.6)
                          : Colors.white10,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _examTabs[i].label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: selected ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildQuizGrid(
              _examTabs[_selectedExam].label,
              _examTabs[_selectedExam].sections,
              sectionMap,
              key: ValueKey(_selectedExam),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizGrid(
    String examLabel,
    List<QuizSection> sections,
    Map<String, dynamic> sectionMap, {
    Key? key,
  }) {
    final rows = <Widget>[];
    for (int i = 0; i < sections.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _quizCard(examLabel, sections[i], sectionMap)),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < sections.length
                  ? _quizCard(examLabel, sections[i + 1], sectionMap)
                  : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < sections.length) rows.add(const SizedBox(height: 12));
    }
    return Column(key: key, children: rows);
  }

  Widget _quizCard(
    String examLabel,
    QuizSection s,
    Map<String, dynamic> sectionMap,
  ) {
    String searchExam = examLabel == "NTS-NAT" ? "NTS" : examLabel;
    final firestoreKey = '${searchExam}_${s.dbSection}';
    final sectionData = sectionMap[firestoreKey] as Map<String, dynamic>?;
    final double realProgress = sectionData != null
        ? (sectionData['percent'] as num? ?? 0.0).toDouble()
        : 0.0;
    final bool notStarted = realProgress == 0.0;
    final String pctText = notStarted
        ? 'NOT STARTED'
        : '${(realProgress * 100).round()}% DONE';

    return GestureDetector(
      onTap: () => _openQuiz(searchExam, s.dbSection),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 10),
                Text(
                  s.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s.weightLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: realProgress,
                    minHeight: 5,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(s.barColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pctText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            if (notStarted)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF4CAF50),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 72 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
        left: 6,
        right: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF08092A).withOpacity(0.97),
        border: Border(
          top: BorderSide(color: UstaadColors.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (i) {
          final selected = i == _selectedNav;
          return GestureDetector(
            onTap: () {
              HapticService.prominent();
              if (i == 1) {
                _showQuizPicker();
              } else {
                setState(() => _selectedNav = i);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? UstaadColors.primary.withOpacity(0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _navItems[i].icon,
                    size: 20,
                    color: selected ? UstaadColors.primary : Colors.white30,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _navItems[i].label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: selected ? UstaadColors.primary : Colors.white30,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
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

  void _showQuizPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF12174A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pick a Quiz',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    itemCount: _examTabs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final selected = i == _selectedExam;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedExam = i);
                          setState(() => _selectedExam = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? UstaadColors.primary
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF8B84FF).withOpacity(0.6)
                                  : Colors.white10,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            _examTabs[i].label,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: selected ? Colors.white : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    itemCount: _examTabs[_selectedExam].sections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = _examTabs[_selectedExam].sections[i];
                      final examLabel = _examTabs[_selectedExam].label;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          String searchExam = examLabel == "NTS-NAT"
                              ? "NTS"
                              : examLabel;
                          _openQuiz(searchExam, s.dbSection);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Text(
                                s.emoji,
                                style: const TextStyle(fontSize: 20),
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      s.weightLabel,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white30,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── _FadeSlide ───────────────────────────────────────────────────────────────
class _FadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final bool slideDown;
  const _FadeSlide({
    required this.animation,
    required this.child,
    this.slideDown = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(
            0,
            slideDown
                ? -18 * (1 - animation.value)
                : 28 * (1 - animation.value),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── _UstuLoader ──────────────────────────────────────────────────────────────
class _UstuLoader extends StatefulWidget {
  const _UstuLoader();
  @override
  State<_UstuLoader> createState() => _UstuLoaderState();
}

class _UstuLoaderState extends State<_UstuLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scale,
          child: FadeTransition(
            opacity: _opacity,
            child: SvgPicture.asset(
              'assets/images/loadingg.svg',
              height: 120,
              width: 120,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _DotsIndicator(),
      ],
    );
  }
}

// ─── _DotsIndicator ───────────────────────────────────────────────────────────
class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();
  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i / 3;
          final progress = ((_ctrl.value - delay) % 1.0).abs();
          final opacity = progress < 0.5
              ? 0.3 + (progress * 1.4)
              : 1.0 - ((progress - 0.5) * 1.4);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF6C63FF,
              ).withOpacity(opacity.clamp(0.3, 1.0)),
            ),
          );
        }),
      ),
    );
  }
}

// ─── NoInternetWidget ─────────────────────────────────────────────────────────
class NoInternetWidget extends StatefulWidget {
  final VoidCallback onRetry;
  final VoidCallback? onBack;
  const NoInternetWidget({super.key, required this.onRetry, this.onBack});
  @override
  State<NoInternetWidget> createState() => _NoInternetWidgetState();
}

class _NoInternetWidgetState extends State<NoInternetWidget>
    with TickerProviderStateMixin {
  static const _lines = [
    'Lagta hai Abba jee ne internet ke paise\nnahi jama krwaye iss mahiney 😬',
    'Reels ke liye internet full taiz chalta hai\ntumhara! 📱',
    'Bhai WiFi ka password phir badal diya\nkya ghar walon ne? 🔐',
    'Ustu bhi offline ho gaya... aur wo toh\nowl hai! 🦉',
    'PTCL walo ne phir scene kar diya\nlagta hai ☎️',
    'Internet nahi toh padhai nahi?\nYe wali excuse nahi chalegi! 📚',
  ];

  late String _currentLine;
  late final AnimationController _typingCtrl;
  late Animation<int> _typingAnim;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;
  String _displayedText = '';

  @override
  void initState() {
    super.initState();
    _currentLine = (_lines.toList()..shuffle()).first;
    _typingCtrl = AnimationController(
      duration: Duration(milliseconds: _currentLine.length * 30),
      vsync: this,
    );
    _typingAnim = IntTween(
      begin: 0,
      end: _currentLine.length,
    ).animate(CurvedAnimation(parent: _typingCtrl, curve: Curves.easeOut));
    _typingAnim.addListener(_updateDisplayedText);
    _typingCtrl.forward();
    _floatCtrl = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(
      begin: -6,
      end: 6,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  void _updateDisplayedText() {
    setState(
      () => _displayedText = _currentLine.substring(0, _typingAnim.value),
    );
  }

  void _restartTyping() {
    _typingCtrl.stop();
    _typingCtrl.reset();
    setState(() => _currentLine = (_lines.toList()..shuffle()).first);
    _typingAnim = IntTween(
      begin: 0,
      end: _currentLine.length,
    ).animate(CurvedAnimation(parent: _typingCtrl, curve: Curves.easeOut));
    _typingAnim.removeListener(_updateDisplayedText);
    _typingAnim.addListener(_updateDisplayedText);
    _typingCtrl.forward();
  }

  @override
  void dispose() {
    _typingCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: child,
              ),
              child: SvgPicture.asset(
                'assets/images/ustu_no_internet.svg',
                height: 180,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  _displayedText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () {
                _restartTyping();
                widget.onRetry();
              },
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6C63FF)),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
            if (widget.onBack != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onBack,
                child: Text(
                  'Go Back',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
