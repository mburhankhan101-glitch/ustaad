import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/screens/papers/paper_selection_screen.dart';
import 'package:ustaad/screens/quiz/quiz_screen.dart';
import 'package:ustaad/screens/profile/profile_screen.dart';

// ─── Real Imports ─────────────────────────────────────────────────────────────
import 'package:ustaad/providers/progress_provider.dart';
import 'package:ustaad/providers/auth_provider.dart';

// ── Inline colors ─────────────────────────────────────────────────────────────
class UstaadColors {
  static const Color background1 = Color(0xFF0A0E2E);
  static const Color background2 = Color(0xFF1A1464);
  static const Color background3 = Color(0xFF6C63FF);
  static const Color primary = Color(0xFF6C63FF);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4CAF50);
  static const Color gold = Color(0xFFFFD700);
}

// ─── Temporary stub provider ───────────────────────────────────────────────────
final currentUserProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).user?.displayName;
});

// ─── Quiz section model ───────────────────────────────────────────────────────
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

// ─── Static exam/section definitions ─────────────────────────────────────────
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

// ─── Nav items ────────────────────────────────────────────────────────────────
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

// ─── HomeScreen ───────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedExam = 0;
  int _selectedNav = 0;

  late final List<Widget> _screens = [
    const SizedBox.shrink(),
    const SizedBox.shrink(),
    const PaperSelectionScreen(),
    const ProfileScreen(),
  ];

  String _greeting(String firstName) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good Morning, $firstName 👋';
    if (h >= 12 && h < 21) return 'Back at it again, $firstName 💪';
    return "Coffee & Ustaad, that's Classic, $firstName ☕";
  }

  String _firstName() {
    final name = ref.watch(currentUserProvider);

    // Logic update: Ensure we check for both null AND empty/whitespace strings
    if (name == null || name.trim().isEmpty) {
      return 'Student';
    }

    return name.trim().split(' ').first;
  }

  String _initials() {
    final name = ref.watch(currentUserProvider);

    // Fallback to 'ST' (for Student) if name is missing
    if (name == null || name.trim().isEmpty) {
      return 'ST';
    }

    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();

    // Returns the first letter of the first and last name (e.g., "John Doe" -> "JD")
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // ── Navigate to QuizScreen passing exam + section ──────────────────────────
  void _openQuiz(String exam, String section) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            QuizScreen(exam: exam, section: section),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 420),
      ),
    ).then((_) => setState(() => _selectedNav = 0));
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(userProgressProvider);

    return progressAsync.when(
      loading: () => const Scaffold(
        backgroundColor: UstaadColors.background1,
        body: Center(
          child: CircularProgressIndicator(color: UstaadColors.primary),
        ),
      ),
      error: (err, stack) => const Scaffold(
        backgroundColor: UstaadColors.background1,
        body: Center(
          child: CircularProgressIndicator(color: UstaadColors.primary),
        ),
      ),
      data: (progressData) {
        final int streak = progressData?['streak'] as int? ?? 0;
        final String lastActiveDate =
            progressData?['lastActiveDate'] as String? ?? '';
        final int solved = progressData?['totalSolved'] as int? ?? 0;
        final int solvedToday = progressData?['solvedToday'] as int? ?? 0;
        final double accuracy =
            (progressData?['accuracy'] as num?)?.toDouble() ?? 0.0;
        final bool isNewUser = progressData == null;
        final Map<String, dynamic> sectionMap =
            progressData?['progress'] as Map<String, dynamic>? ?? {};

        return Scaffold(
          backgroundColor: UstaadColors.background1,
          body: _selectedNav == 0
              ? Stack(
                  children: [
                    Container(
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
                    ),
                    SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 96),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildStreakBar(streak, lastActiveDate, isNewUser),
                            const SizedBox(height: 20),
                            _buildStatsRow(
                              solved,
                              solvedToday,
                              accuracy,
                              isNewUser,
                            ),
                            const SizedBox(height: 32),
                            _buildQuizSection(sectionMap),
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
                    Container(
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
                    ),
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

  // ─────────────────────────────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
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
                  _greeting(_firstName()),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your Ustaad is ready 📚',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white54,
                    fontSize: 11,
                  ),
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
    // Get the personality message from our helper
    final msg = streakMessage(
      isNewUser ? 0 : streak,
      isNewUser ? '' : lastActiveDate,
    );

    // Roasts show in coral red, positive messages in gold
    final Color msgColor = msg.isRoast
        ? UstaadColors.accent
        : UstaadColors.gold;

    // Card border and background also shift colour on a roast
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: flame + streak number ──────────────────────────────
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
                  // ── The personality message lives here ──────────────────
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

  Widget _buildStatsRow(
    int solved,
    int solvedToday,
    double accuracy,
    bool isNewUser,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              number: solved.toString(),
              label: 'Questions solved',
              sub: isNewUser ? 'Start your first quiz!' : '+$solvedToday today',
              subColor: isNewUser
                  ? UstaadColors.primary.withOpacity(0.8)
                  : const Color(0xFF4CAF50),
            ),
          ),
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

  Widget _buildQuizSection(Map<String, dynamic> sectionMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Practice Quiz',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'See all',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: UstaadColors.primary.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
    // 1. Sanitize the exam label for standard cases
    String searchExam = examLabel == "NTS-NAT" ? "NTS" : examLabel;

    // 2. SPECIAL RULE: Redirect Analytical queries to NTS pool
    // Since your DB currently only tags Analytical questions with "NTS"[cite: 1]
    if (s.dbSection == "Analytical") {
      searchExam = "NTS";
    }

    // 3. Use the redirected searchExam and dbSection for the progress key
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
      // 4. Pass the redirected exam name so the QuizScreen finds the docs[cite: 1, 4]
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
              if (i == 1) {
                // Quiz tab — show a bottom sheet to pick exam + section
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

  // ── Quiz picker bottom sheet ───────────────────────────────────────────────
  // Shows when the user taps the Quiz tab in the bottom nav.
  // Lets them pick which exam + section to practice before entering QuizScreen.
  void _showQuizPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        // 1. WRAP YOUR CONTAINER IN A StatefulBuilder
        return StatefulBuilder(
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
                  // Drag handle
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
                  // Exam chips
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
                            // 2. USE setModalState TO REBUILD THE BOTTOM SHEET
                            setModalState(() => _selectedExam = i);

                            // 3. Keep the normal setState so the parent screen knows
                            // the value changed when the sheet eventually closes
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
                  // Section list
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
                            Navigator.pop(context); // close picker
                            _openQuiz(examLabel, s.title);
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
        );
      },
    );
  }
}
