import 'package:flutter/material.dart';

class OnboardingDots extends StatelessWidget {
  final int currentIndex;
  final int totalDots;

  const OnboardingDots({
    super.key,
    required this.currentIndex,
    required this.totalDots,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalDots,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: currentIndex == index ? 24 : 8,
          decoration: BoxDecoration(
            color: currentIndex == index
                ? Colors
                      .white // ← active dot white
                : Colors.white30, // ← inactive dot white30
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
