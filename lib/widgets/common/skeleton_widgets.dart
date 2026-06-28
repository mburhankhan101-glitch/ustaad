// lib/widgets/common/skeleton_widgets.dart
//
// Reusable shimmer/skeleton widgets used across QuizScreen and PaperScreen.
// Import this file wherever you need a loading skeleton.

import 'package:flutter/material.dart';

const _bg1 = Color(0xFF0A0E2E);
const _bg2 = Color(0xFF1A1464);
const _bg3 = Color(0xFF6C63FF);

// ─── Base shimmer box ─────────────────────────────────────────────────────────
// Drop-in animated placeholder for any rect.
// width: null → expands to fill parent (use inside Row with Expanded or
//               set explicit constraints on the parent).
// delay: staggers each box so they don't all pulse in sync.

class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  final Duration delay;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
    this.delay = Duration.zero,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 950),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.15),
            _anim.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ─── Gradient background ──────────────────────────────────────────────────────

Widget _skeletonGradient() => Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_bg1, _bg2, _bg3],
      stops: [0.0, 0.55, 1.0],
    ),
  ),
);

// ─── Quiz loading skeleton ────────────────────────────────────────────────────
// Mimics the exact QuizScreen layout so the visual jump on load is near-zero.
// Placed directly in quiz_screen.dart's build() when _loadingQuestions == true.

class QuizLoadingSkeleton extends StatelessWidget {
  const QuizLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg1,
      body: Stack(
        children: [
          _skeletonGradient(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                  child: Row(
                    children: [
                      const ShimmerBox(width: 38, height: 38, radius: 12),
                      const Spacer(),
                      const ShimmerBox(
                        width: 130,
                        height: 12,
                        delay: Duration(milliseconds: 80),
                      ),
                      const Spacer(),
                      const ShimmerBox(
                        width: 52,
                        height: 32,
                        radius: 20,
                        delay: Duration(milliseconds: 160),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                // ── Progress bar ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          ShimmerBox(
                            width: 60,
                            height: 10,
                            delay: Duration(milliseconds: 60),
                          ),
                          ShimmerBox(
                            width: 72,
                            height: 10,
                            delay: Duration(milliseconds: 120),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const ShimmerBox(
                        width: double.infinity,
                        height: 6,
                        delay: Duration(milliseconds: 90),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // ── Section badge ──────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: ShimmerBox(
                    width: 190,
                    height: 34,
                    radius: 20,
                    delay: Duration(milliseconds: 130),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Question card ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(
                          width: 90,
                          height: 10,
                          delay: Duration(milliseconds: 60),
                        ),
                        SizedBox(height: 14),
                        ShimmerBox(
                          width: double.infinity,
                          height: 13,
                          delay: Duration(milliseconds: 80),
                        ),
                        SizedBox(height: 9),
                        ShimmerBox(
                          width: double.infinity,
                          height: 13,
                          delay: Duration(milliseconds: 100),
                        ),
                        SizedBox(height: 9),
                        ShimmerBox(
                          width: 200,
                          height: 13,
                          delay: Duration(milliseconds: 120),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Option tiles ───────────────────────────────────────────
                ...List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                    child: ShimmerBox(
                      width: double.infinity,
                      height: 56,
                      radius: 16,
                      delay: Duration(milliseconds: 70 * (i + 1)),
                    ),
                  ),
                ),
                const Spacer(),
                // ── Bottom row ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  child: Row(
                    children: const [
                      ShimmerBox(
                        width: 52,
                        height: 52,
                        radius: 16,
                        delay: Duration(milliseconds: 100),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ShimmerBox(
                          height: 52,
                          radius: 16,
                          delay: Duration(milliseconds: 150),
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
    );
  }
}

// ─── Paper loading skeleton ───────────────────────────────────────────────────
// Mimics the paper screen: top bar, timer chip, question card, 4 options,
// prev/confirm/next nav bar.
// Use this inside your paper screen when paperSessionProvider is AsyncLoading.
//
// Usage:
//   ref.watch(paperSessionProvider).when(
//     loading: () => const PaperLoadingSkeleton(),
//     ...
//   )

class PaperLoadingSkeleton extends StatelessWidget {
  const PaperLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg1,
      body: Stack(
        children: [
          _skeletonGradient(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                  child: Row(
                    children: const [
                      ShimmerBox(width: 38, height: 38, radius: 12),
                      Spacer(),
                      ShimmerBox(
                        width: 140,
                        height: 13,
                        delay: Duration(milliseconds: 80),
                      ),
                      Spacer(),
                      ShimmerBox(
                        width: 38,
                        height: 38,
                        radius: 12,
                        delay: Duration(milliseconds: 160),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Timer + section label row ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: const [
                      ShimmerBox(
                        width: 100,
                        height: 36,
                        radius: 12,
                        delay: Duration(milliseconds: 60),
                      ),
                      Spacer(),
                      ShimmerBox(
                        width: 140,
                        height: 36,
                        radius: 12,
                        delay: Duration(milliseconds: 120),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── Question number + card ─────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: ShimmerBox(
                    width: 80,
                    height: 10,
                    delay: Duration(milliseconds: 70),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(
                          width: double.infinity,
                          height: 13,
                          delay: Duration(milliseconds: 80),
                        ),
                        SizedBox(height: 9),
                        ShimmerBox(
                          width: double.infinity,
                          height: 13,
                          delay: Duration(milliseconds: 100),
                        ),
                        SizedBox(height: 9),
                        ShimmerBox(
                          width: 220,
                          height: 13,
                          delay: Duration(milliseconds: 120),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // ── Option tiles ───────────────────────────────────────────
                ...List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                    child: ShimmerBox(
                      width: double.infinity,
                      height: 54,
                      radius: 16,
                      delay: Duration(milliseconds: 70 * (i + 1)),
                    ),
                  ),
                ),
                const Spacer(),
                // ── Navigation bar ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  child: Row(
                    children: const [
                      ShimmerBox(
                        width: 48,
                        height: 48,
                        radius: 14,
                        delay: Duration(milliseconds: 80),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ShimmerBox(
                          height: 48,
                          radius: 14,
                          delay: Duration(milliseconds: 120),
                        ),
                      ),
                      SizedBox(width: 12),
                      ShimmerBox(
                        width: 48,
                        height: 48,
                        radius: 14,
                        delay: Duration(milliseconds: 160),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
