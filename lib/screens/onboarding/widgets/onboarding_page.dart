import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class OnboardingPage extends StatelessWidget {
  final String lottieAsset;
  final String title;
  final String subtitle;

  const OnboardingPage({
    super.key,
    required this.lottieAsset,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Lottie Animation
          Lottie.asset(lottieAsset, height: 280, width: 280),

          const SizedBox(height: 40),

          // Title — white on dark background
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white, // ← white
              height: 1.3,
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle — white70 on dark background
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white70, // ← white70
              height: 1.6,
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
