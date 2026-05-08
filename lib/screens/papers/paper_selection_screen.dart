// lib/screens/papers/paper_selection_screen.dart
// FIX: Each card now navigates to ProgramSelectionScreen first,
// NOT directly to the paper screen.

import 'package:flutter/material.dart';
import 'package:ustaad/models/paper_model.dart';
import 'package:ustaad/screens/home/home_screen.dart'; // UstaadColors
import 'package:ustaad/screens/papers/program/program_selection_screen.dart';

class PaperSelectionScreen extends StatelessWidget {
  const PaperSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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

              // Scrollable Paper List
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      // ── FAST-NU ──────────────────────────────────────────
                      _buildPaperCard(
                        context,
                        title: 'FAST-NU Entrance',
                        duration: '120 mins',
                        marks: '100 marks',
                        tags: const [
                          '50 Adv Math',
                          '20 Basic Math',
                          '20 IQ',
                          '30 English',
                        ],
                        markingScheme:
                            '+1 / −0.25 (Math, IQ)   ·   +0.344 / −0.0844 (English)',
                        accentColor: const Color(0xFF6C63FF),
                        // ↓ Navigate to ProgramSelectionScreen, not FastPaperScreen
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProgramSelectionScreen(
                              examType: ExamType.fastNU,
                              userProgram: UserProgram.fastCS,
                              // TODO: Replace UserProgram.fastCS with the value
                              // stored from your TestSelectionScreen. For now
                              // FAST always defaults to CS track.
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── NUST-NET ─────────────────────────────────────────
                      _buildPaperCard(
                        context,
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
                      ),

                      const SizedBox(height: 16),

                      // ── NTS ──────────────────────────────────────────────
                      _buildPaperCard(
                        context,
                        title: 'NTS NAT (ICS/CS)',
                        duration: '100 mins',
                        marks: '90 marks',
                        tags: const [
                          '20 English',
                          '20 Analytical',
                          '20 Quantitative',
                          '30 CS',
                        ],
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
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaperCard(
    BuildContext context, {
    required String title,
    required String duration,
    required String marks,
    required List<String> tags,
    required String markingScheme,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                    title,
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
                  color: accentColor.withOpacity(0.7),
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$duration  •  $marks',
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
              children: tags.map((tag) => _buildTag(tag)).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                border: Border.all(color: accentColor.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MARKING SCHEME',
                    style: TextStyle(
                      color: accentColor.withOpacity(0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    markingScheme,
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
