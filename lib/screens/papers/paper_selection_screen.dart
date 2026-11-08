// lib/screens/papers/paper_selection_screen.dart
// Style C: Full-width dashboard on web, stacked on mobile.
// Top navbar removed – content starts directly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/models/paper_model.dart';
import 'package:ustaad/providers/user_selection_provider.dart';
import 'package:ustaad/screens/home/home_screen.dart'; // UstaadColors
import 'package:ustaad/screens/papers/program/program_selection_screen.dart';

class PaperSelectionScreen extends ConsumerWidget {
  const PaperSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final selectedTestsAsync = ref.watch(selectedTestsProvider);
    final degree = ref.watch(targetDegreeProvider).valueOrNull;

    return Scaffold(
      // No backgroundColor needed – gradient covers everything
      body: Container(
        width: double.infinity,
        height: double.infinity, // ✅ Fills entire screen vertically
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              UstaadColors.background1,
              UstaadColors.background2,
              UstaadColors.background3,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: selectedTestsAsync.when(
          // Loading and error both fail open to the engineering/CS bucket —
          // it's the larger, more-built-out set, and a brief flash of the
          // "wrong" bucket for a split second beats a blank screen while
          // the one Firestore read resolves.
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
          error: (_, __) => _buildContent(context, isWeb, const [], null),
          data: (selectedTests) =>
              _buildContent(context, isWeb, selectedTests, degree),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isWeb,
    List<String> selectedTests,
    String? degree,
  ) {
    return isWeb
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: _buildWebContent(context, selectedTests, degree),
          )
        : SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              // Extra bottom padding (not just vertical: 8) because the
              // bottom nav bar sits as an overlay outside this screen's
              // own SafeArea — Flutter doesn't know to reserve space for
              // it, so without this the last card gets clipped and the
              // scroll view stops short of fully revealing it.
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
              child: _buildMobileContent(
                context,
                selectedTests,
                degree,
              ),
            ),
          );
  }

  // ── Mobile layout ────────────────────────────────────────────────────
  Widget _buildMobileContent(
    BuildContext context,
    List<String> selectedTests,
    String? degree,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 24, 22, 4),
          child: Text(
            'Mock Papers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          child: Text(
            'Full-length timed exams to test your endurance.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Builder(
          builder: (context) {
            final cards = _cardsFor(context, selectedTests, degree);
            if (cards.isEmpty) return _noPapers();
            return Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  _buildPaperCard(context, cards[i]),
                  SizedBox(height: i == cards.length - 1 ? 40 : 16),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Web content ──────────────────────────────────────────────────────
  Widget _buildWebContent(
    BuildContext context,
    List<String> selectedTests,
    String? degree,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mock Papers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Full-length timed exams to test your endurance.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 32),
        Builder(
          builder: (context) {
            final cards = _cardsFor(context, selectedTests, degree);
            if (cards.isEmpty) return _noPapers();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: _buildPaperCard(context, cards[i])),
                  if (i != cards.length - 1) const SizedBox(width: 20),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Factory methods for card data ─────────────────────────────────────
  /// One card per test the student picked, resolved through their degree.
  ///
  /// Papers used to list every exam the app supports and ask the student to
  /// choose again — including the three NET programmes they are not sitting.
  /// They answered both halves of this at sign-up, so the only honest list is
  /// the papers that belong to them.
  List<_PaperCardData> _cardsFor(
    BuildContext context,
    List<String> selectedTests,
    String? degree,
  ) {
    final out = <_PaperCardData>[];
    final seen = <UserProgram>{};
    for (final testId in selectedTests) {
      final program = PaperConfigs.programFor(testId, degree);
      if (program == null || !seen.add(program)) continue;
      final card = _cardForProgram(context, program);
      if (card != null) out.add(card);
    }
    return out;
  }

  _PaperCardData? _cardForProgram(BuildContext context, UserProgram program) {
    switch (program) {
      case UserProgram.fastCS:
        return fastPaperCard(context);
      case UserProgram.fastBusiness:
        return fastBusinessPaperCard(context);
      case UserProgram.nustEngineering:
        return nustPaperCard(context);
      case UserProgram.nustBusiness:
        return nustBusinessPaperCard(context);
      case UserProgram.nustAppliedSciences:
        return nustAppliedPaperCard(context);
      case UserProgram.nustArchitecture:
        return nustArchPaperCard(context);
      case UserProgram.ntsCS:
        return ntsPaperCard(context);
      case UserProgram.mdcatMedical:
        return mdcatPaperCard(context);
      case UserProgram.numsMedical:
        return numsPaperCard(context);
    }
  }

  /// Shown when the degree has not loaded or no paper matches. Says what to
  /// do rather than leaving a gap where cards should be.
  Widget _noPapers() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Text(
              'No papers for your selection yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check the test and degree on your profile.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12.5,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      );

  _PaperCardData fastPaperCard(BuildContext context) => _PaperCardData(
    title: 'FAST-NU Entrance',
    duration: '120 mins',
    marks: '100 marks',
    tags: const ['50 Adv Math', '20 Basic Math', '20 IQ', '30 English'],
    markingScheme: '+1 / −0.25 (Math, IQ)   ·   +0.344 / −0.0844 (English)',
    accentColor: const Color(0xFF6C63FF),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.fastNU,
          userProgram: UserProgram.fastCS,
        ),
      ),
    ),
  );

  _PaperCardData nustPaperCard(BuildContext context) => _PaperCardData(
    title: 'NUST NET (Engineering)',
    duration: '180 mins',
    marks: '200 marks',
    tags: const ['100 Math', '60 Physics', '40 English'],
    markingScheme: '+1   ·   No Negative Marking',
    accentColor: const Color(0xFF4CAF50),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.nustNET,
          userProgram: UserProgram.nustEngineering,
        ),
      ),
    ),
  );

  _PaperCardData fastBusinessPaperCard(BuildContext context) => _PaperCardData(
    title: 'FAST-NU (Business)',
    duration: '120 mins',
    marks: '120 marks',
    tags: const ['60 Basic Maths', '30 Analytical', '30 English'],
    markingScheme: '+1   ·   −0.25 Negative Marking',
    accentColor: const Color(0xFF6C63FF),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.fastNU,
          userProgram: UserProgram.fastBusiness,
        ),
      ),
    ),
  );

  _PaperCardData nustBusinessPaperCard(BuildContext context) => _PaperCardData(
    title: 'NUST NET (Business)',
    duration: '180 mins',
    marks: '200 marks',
    tags: const ['100 Quantitative', '100 English'],
    markingScheme: '+1   ·   No Negative Marking',
    accentColor: const Color(0xFF4CAF50),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.nustNET,
          userProgram: UserProgram.nustBusiness,
        ),
      ),
    ),
  );

  _PaperCardData nustAppliedPaperCard(BuildContext context) => _PaperCardData(
    title: 'NUST NET (Applied Sciences)',
    duration: '180 mins',
    marks: '200 marks',
    tags: const ['100 Biology', '60 Chemistry', '40 English'],
    markingScheme: '+1   ·   No Negative Marking',
    accentColor: const Color(0xFF4CAF50),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.nustNET,
          userProgram: UserProgram.nustAppliedSciences,
        ),
      ),
    ),
  );

  /// Maths and English only. Design Aptitude is half the real paper and is
  /// drawn by hand, so the card says so rather than letting a student think
  /// one of these is a full rehearsal.
  _PaperCardData nustArchPaperCard(BuildContext context) => _PaperCardData(
    title: 'NUST NET (Architecture)',
    duration: '90 mins',
    marks: '100 marks',
    tags: const ['60 Mathematics', '40 English', 'No Design Aptitude'],
    markingScheme: '+1   ·   No Negative Marking',
    accentColor: const Color(0xFF4CAF50),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.nustNET,
          userProgram: UserProgram.nustArchitecture,
        ),
      ),
    ),
  );

  _PaperCardData ntsPaperCard(BuildContext context) => _PaperCardData(
    title: 'NTS NAT (ICS/CS)',
    duration: '100 mins',
    marks: '90 marks',
    tags: const ['20 English', '20 Analytical', '20 Quantitative', '30 CS'],
    markingScheme: '+1   ·   No Negative Marking',
    accentColor: const Color(0xFFFF6B6B),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.nts,
          userProgram: UserProgram.ntsCS,
        ),
      ),
    ),
  );

  _PaperCardData mdcatPaperCard(BuildContext context) => _PaperCardData(
    title: 'MDCAT (Medical/Dental)',
    duration: '180 mins',
    marks: '180 marks',
    tags: const [
      '81 Biology',
      '45 Chemistry',
      '36 Physics',
      '9 English',
      '9 Logical Reasoning',
    ],
    markingScheme: '+1   ·   No Negative Marking',
    accentColor: const Color(0xFF00BFA5),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.mdcat,
          userProgram: UserProgram.mdcatMedical,
        ),
      ),
    ),
  );

  _PaperCardData numsPaperCard(BuildContext context) => _PaperCardData(
    title: 'NUMS MDCAT (Paper-I)',
    duration: '165 mins',
    marks: '150 marks',
    tags: const ['55 Biology', '40 Chemistry', '40 Physics', '15 English'],
    markingScheme: '+1   ·   No Negative Marking',
    accentColor: const Color(0xFF2196F3),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgramSelectionScreen(
          examType: ExamType.numsMdcat,
          userProgram: UserProgram.numsMedical,
        ),
      ),
    ),
  );

  Widget _buildPaperCard(BuildContext context, _PaperCardData data) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: data.accentColor.withOpacity(0.7),
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${data.duration}  •  ${data.marks}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data.tags.map((tag) => _buildTag(tag)).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: data.accentColor.withOpacity(0.08),
                border: Border.all(color: data.accentColor.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MARKING SCHEME',
                    style: TextStyle(
                      color: data.accentColor.withOpacity(0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.markingScheme,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      fontFamily: 'Poppins',
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

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 10,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

class _PaperCardData {
  final String title;
  final String duration;
  final String marks;
  final List<String> tags;
  final String markingScheme;
  final Color accentColor;
  final VoidCallback onTap;

  const _PaperCardData({
    required this.title,
    required this.duration,
    required this.marks,
    required this.tags,
    required this.markingScheme,
    required this.accentColor,
    required this.onTap,
  });
}
