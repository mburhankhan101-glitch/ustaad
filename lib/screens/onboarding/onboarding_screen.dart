import 'package:flutter/material.dart';
import 'widgets/onboarding_page.dart';
import 'widgets/onboarding_dots.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Each slide has its own gradient colors
  final List<List<Color>> _gradients = [
    // Slide 1 — deep blue to teal
    [const Color(0xFF0A0E2E), const Color(0xFF1A1464), const Color(0xFF6C63FF)],
    // Slide 2 — deep navy to indigo
    [const Color(0xFF0D1B4B), const Color(0xFF1B2A8F), const Color(0xFF7B6FF5)],
    // Slide 3 — deep purple to violet
    [const Color(0xFF1A0A2E), const Color(0xFF3D1F8F), const Color(0xFF9C63FF)],
  ];

  final List<Map<String, String>> _pages = [
    {
      "lottie": "assets/images/study_stress.json",
      "title": "Exam aa raha hai?\nTension mat lo!",
      "subtitle":
          "Fast NU, NET aur NTS ki preparation ab smart tarike se karo — jahan bhi, jab bhi",
    },
    {
      "lottie": "assets/images/past_papers.json",
      "title": "Past Papers\nSolve Karo",
      "subtitle":
          "Solve real past papers in a full exam environment\nTimed sections, negative marking, real exam pressure",
    },
    {
      "lottie": "assets/images/ustu_owl.json",
      "title": "Ustaad Se\nSeekho 🦉",
      "subtitle":
          "Galat jawab diya? Koi baat nahi!\nUstaad explain karega English ya Urdu mein",
    },
  ];

  void _onNext() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradients[_currentIndex], // changes per slide
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Decorative Circles ────────────────────
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
              top: screenHeight * 0.4,
              right: -40,
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),

            // ── Main Content ──────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton(
                        onPressed: _navigateToLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Page View
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return OnboardingPage(
                          lottieAsset: _pages[index]["lottie"]!,
                          title: _pages[index]["title"]!,
                          subtitle: _pages[index]["subtitle"]!,
                        );
                      },
                    ),
                  ),

                  // Bottom section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                    child: Column(
                      children: [
                        // Dots
                        OnboardingDots(
                          currentIndex: _currentIndex,
                          totalDots: _pages.length,
                        ),

                        const SizedBox(height: 32),

                        // Next / Get Started button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF6C63FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentIndex == _pages.length - 1
                                      ? 'Get Started!'
                                      : 'Next',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentIndex == _pages.length - 1
                                      ? Icons.rocket_launch_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: const Color(0xFF6C63FF),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}
