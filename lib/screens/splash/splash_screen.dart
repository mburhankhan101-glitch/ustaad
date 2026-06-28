import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // ✅ for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaad/screens/auth/login_screen.dart';
import 'package:ustaad/screens/auth/signup_screen.dart';
import 'package:ustaad/screens/auth/verify_email_screen.dart';
import 'package:ustaad/screens/home/home_screen.dart';
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

    // ─────────────────────────────────────────────────────────────────────────
    // ✅ WEB vs MOBILE ROUTING
    //
    // On WEB  → skip splash animation + skip onboarding entirely.
    //           Navigate immediately after a single frame so the gradient
    //           background still paints (avoids a white flash).
    //
    // On MOBILE → run the full 2.5s branded splash, then check onboarding.
    // ─────────────────────────────────────────────────────────────────────────
    if (kIsWeb) {
      // Start the animation anyway so the screen isn't blank on that one frame
      _controller.forward();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromSplash();
      });
    } else {
      _controller.forward();

      Future.delayed(const Duration(milliseconds: 2500), () {
        _navigateFromSplash();
      });
    }
  }

  /// Central navigation logic — called by both web (immediately) and mobile (after delay).
  Future<void> _navigateFromSplash() async {
    if (!mounted) return;

    final Widget destination = await _resolveDestination();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        // ✅ Faster fade on web (no theatrical transition needed)
        transitionDuration: Duration(milliseconds: kIsWeb ? 200 : 500),
      ),
    );
  }

  Future<Widget> _resolveDestination() async {
    // ── Step 1: Check Firebase auth ─────────────────────────────────────────
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase not initialized or offline — fall through to login
      user = null;
    }

    if (user != null) {
      if (user.emailVerified) {
        return const HomeScreen();
      } else {
        // Logged in but email not verified yet
        return const VerifyEmailScreen();
      }
    }

    // ── Step 2: Web path — skip onboarding, check for ?signup=true ──────────
    if (kIsWeb) {
      // ✅ Read URL query params passed from the landing page buttons
      // Hero.js sends "?signup=true" when the Register button is clicked
      final queryParams = Uri.base.queryParameters;
      if (queryParams['signup'] == 'true') {
        return const SignupScreen();
      }
      // All other cases on web → LoginScreen
      return const LoginScreen();
    }

    // ── Step 3: Mobile path — check onboarding flag ──────────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (hasSeenOnboarding) {
        return const LoginScreen();
      } else {
        await prefs.setBool('hasSeenOnboarding', true);
        return const OnboardingScreen();
      }
    } catch (_) {
      // SharedPreferences failed (shouldn't happen, but be safe)
      return const LoginScreen();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ On web, this screen is visible for ~1 frame.
    // On mobile, it shows for the full 2.5s.
    // Both get the same gradient — it just flashes briefly on web (intentional branding).

    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF6C63FF)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Background decorative circles ─────────────────────────────
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

            // ── Main content ──────────────────────────────────────────────
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Lottie.asset(
                    'assets/images/ustu_owl.json',
                    height: 200,
                    width: 200,
                  ),
                ),

                const SizedBox(height: 32),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 190, 196, 220),
                              Color(0xFFB8B4FF),
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

                // ✅ Only show progress bar on mobile — on web it's never visible
                if (!kIsWeb)
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
