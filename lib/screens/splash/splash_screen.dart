import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:ustaad/screens/onboarding/onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) {
            // Smooth fade transition instead of hard cut
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        // ── Gradient Background ─────────────────────
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E2E), // deep navy — top left
              Color(0xFF1A1464), // rich dark blue — middle
              Color(0xFF6C63FF), // purple — bottom right
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),

        child: Stack(
          children: [
            // ── Background Decorative Circles ────────
            // Top right circle
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                height: 250,
                width: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // Bottom left circle
            Positioned(
              bottom: -100,
              left: -60,
              child: Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // Middle decorative circle
            Positioned(
              top: screenHeight * 0.15,
              left: -40,
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),

            // ── Main Content ─────────────────────────
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Owl Lottie Animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Lottie.asset(
                    'assets/images/ustu_owl.json',
                    height: 200,
                    width: 200,
                  ),
                ),

                const SizedBox(height: 32),

                // App Name + Tagline
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // USTAAD text
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 190, 196, 220),
                              Color(0xFFB8B4FF),
                              // light purple-white
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Ustaad',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Tagline
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Text(
                            'Apna Ustaad 🦉',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.white70,
                              letterSpacing: 1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // AI Powered badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF6C63FF),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI Powered',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Loading bar at bottom
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 48,
                  ),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 3),
                        builder: (context, value, child) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.white.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                              minHeight: 3,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Preparing your experience...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
