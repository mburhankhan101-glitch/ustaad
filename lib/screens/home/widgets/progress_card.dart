import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/progress_provider.dart';
import 'package:ustaad/screens/home/home_screen.dart'; // To reuse UstaadColors

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(userProgressProvider);

    return Scaffold(
      backgroundColor: UstaadColors.background1,
      appBar: AppBar(
        title: const Text(
          'Your Progress',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (data) {
          if (data == null)
            return const Center(
              child: Text(
                'No progress yet. Start a quiz!',
                style: TextStyle(color: Colors.white),
              ),
            );

          final sections = data['progress'] as Map<String, dynamic>? ?? {};

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildDetailedStatCard(
                'Overall Accuracy',
                '${(data['accuracy'] ?? 0).round()}%',
                UstaadColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Section Breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...sections.entries.map((entry) {
                final sectionData = entry.value as Map<String, dynamic>;
                final name = entry.key.replaceAll('_', ' ');
                final progress = (sectionData['percent'] ?? 0.0) as double;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(
                          UstaadColors.primary,
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailedStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
