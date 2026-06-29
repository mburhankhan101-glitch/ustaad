import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PlansScreen — Redesigned Paywall
//  Inspired by: Duolingo (plan cards), Mondly (benefit chips), EWA (hero),
//               Quizlet (clear CTA hierarchy)
//  Brand: Ustaad — #0A0E2E → #1A1464 → #6C63FF gradient, Poppins, Gold #FFD700
// ─────────────────────────────────────────────────────────────────────────────

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen>
    with TickerProviderStateMixin {
  String _selected = 'monthly';

  // Glow behind Ustu owl — slow breathe in/out
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  // CTA button gentle pulse — draws the eye without being annoying
  late final AnimationController _ctaController;
  late final Animation<double> _ctaScaleAnim;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _ctaScaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.045,
    ).animate(CurvedAnimation(parent: _ctaController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ROOT BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF6C63FF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      _buildHero(),
                      const SizedBox(height: 16),
                      _buildSocialProof(),
                      const SizedBox(height: 20),
                      _buildBenefitChips(),
                      const SizedBox(height: 26),
                      _buildComparisonTable(),
                      const SizedBox(height: 26),
                      _buildToggle(),
                      const SizedBox(height: 14),
                      _buildPricingCard(),
                      const SizedBox(height: 10),
                      _buildMaybeLater(context),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 28,
                      ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Expanded(
            child: Text(
              'Choose Your Plan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 44), // balance back button
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HERO — Ustu with golden ring, PRO badge, sparkles, animated glow
  //  Inspired by EWA's large character hero section
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHero() {
    return Column(
      children: [
        Center(
          // Fixed-size container so Positioned sparkles are predictable
          child: SizedBox(
            width: 200,
            height: 130,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Animated glow blob behind owl ──────────────────────────
                Positioned(
                  left: 45,
                  top: 5,
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, __) => Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6C63FF,
                            ).withOpacity(_glowAnim.value),
                            blurRadius: 50,
                            spreadRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Golden ring border ──────────────────────────────────────
                Positioned(
                  left: 48,
                  top: 8,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2D27A8), Color(0xFF6C63FF)],
                        ),
                      ),
                      child: const Center(
                        child: Text('🦉', style: TextStyle(fontSize: 46)),
                      ),
                    ),
                  ),
                ),

                // ── PRO crown badge (top-right of owl) ─────────────────────
                Positioned(
                  top: 2,
                  right: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.55),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👑', style: TextStyle(fontSize: 10)),
                        SizedBox(width: 3),
                        Text(
                          'PRO',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Sparkles scattered around ───────────────────────────────
                const Positioned(
                  top: 4,
                  left: 22,
                  child: Text('✨', style: TextStyle(fontSize: 16)),
                ),
                const Positioned(
                  top: 0,
                  right: 6,
                  child: Text('⭐', style: TextStyle(fontSize: 12)),
                ),
                const Positioned(
                  bottom: 20,
                  left: 8,
                  child: Text('💫', style: TextStyle(fontSize: 14)),
                ),
                const Positioned(
                  bottom: 16,
                  right: 10,
                  child: Text('✨', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Headline
        const Text(
          'Unlock Your Full Potential',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 6),

        // Exam-specific subtitle — not generic, talks to the student's real fear
        Text(
          'Crack FAST-NU & NUST with AI by your side',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Colors.white.withOpacity(0.60),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SOCIAL PROOF — "X students are already Pro"
  //  Inspired by Duolingo's community feel
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSocialProof() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar stack (3 overlapping circles)
          SizedBox(
            width: 68,
            height: 28,
            child: Stack(
              children: [
                _avatarBubble('🧑', 0),
                _avatarBubble('👩', 22),
                _avatarBubble('👦', 44),
              ],
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: '2,847 ',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFD700),
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: 'students already Pro',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarBubble(String emoji, double left) {
    return Positioned(
      left: left,
      top: 0,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A1464),
          border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 13))),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BENEFIT CHIPS — 3 scannable value propositions before the table
  //  Law of Prägnanz: simple shapes > dense table for first impression
  //  Inspired by Mondly's icon-led feature highlights
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBenefitChips() {
    const chips = [
      _BenefitChip('🤖', 'Unlimited\nAI Explain', Color(0xFF8B7FFF)),
      _BenefitChip('📄', 'All Past\nPapers', Color(0xFF4CAF50)),
      _BenefitChip('📊', 'Weak Topic\nAnalytics', Color(0xFFFF6B6B)),
    ];

    return Row(
      children: chips
          .map(
            (chip) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: chip.color.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: chip.color.withOpacity(0.28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(chip.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 7),
                    Text(
                      chip.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  COMPARISON TABLE — PRO column gets a real gold badge header
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildComparisonTable() {
    const features = [
      _Feature('AI Explanations', '5 / day', 'Unlimited'),
      _Feature('Quiz Sessions', '10 / day', 'Unlimited'),
      _Feature('Full Papers', '2 / month', 'Unlimited'),
      _Feature('Custom Tests', '✗', '✓'),
      _Feature('Weak Topic Analytics', 'Basic', 'Detailed'),
      _Feature('Priority AI Speed', '✗', '✓'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Feature',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.45),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'FREE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.38),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // PRO header — now a real gold pill, not just text
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.30),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Feature rows ────────────────────────────────────────────────
          ...features.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            final isLast = i == features.length - 1;
            final freeIsX = f.freeValue == '✗';
            final proIsCheck = f.proValue == '✓';

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          f.name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            f.freeValue,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: freeIsX
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: freeIsX
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.white.withOpacity(0.48),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            f.proValue,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: proIsCheck
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFFD700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.06),
                    indent: 18,
                    endIndent: 18,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOGGLE — Pro Monthly / Credit Pack
  //  Active tab now uses a gradient fill instead of flat purple
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          _toggleTab('monthly', '✨  Pro Monthly'),
          _toggleTab('credits', '⚡  Credit Pack'),
        ],
      ),
    );
  }

  Widget _toggleTab(String value, String label) {
    final active = _selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selected = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8B7FFF), Color(0xFF6C63FF)],
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.40),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : Colors.white.withOpacity(0.40),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PRICING CARD — AnimatedSwitcher for smooth tab transition
  //  CTA button is now a pulsing gold gradient (no longer plain white)
  //  Inspired by Mondly's "Try it for free" golden button
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPricingCard() {
    final isMonthly = _selected == 'monthly';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(_selected),
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isMonthly
                ? [const Color(0xFF3D35B8), const Color(0xFF6C63FF)]
                : [const Color(0xFF1E2A4A), const Color(0xFF2D3A6B)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isMonthly
                ? const Color(0xFF9C8DFF).withOpacity(0.55)
                : const Color(0xFFFFD700).withOpacity(0.38),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isMonthly
                  ? const Color(0xFF6C63FF).withOpacity(0.45)
                  : const Color(0xFFFFD700).withOpacity(0.15),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ─────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  isMonthly ? '✨  Pro Plan' : '⚡  Credit Pack',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (isMonthly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.55),
                      ),
                    ),
                    child: const Text(
                      'Most Popular',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Price display ─────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFDDD8FF)],
                  ).createShader(bounds),
                  child: Text(
                    isMonthly ? 'PKR 399' : 'PKR 249',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    isMonthly ? '/ month' : '50 credits',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              isMonthly
                  ? 'Everything unlimited. Cancel anytime.'
                  : 'Use credits for AI, quizzes & papers. No expiry.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withOpacity(0.58),
              ),
            ),

            const SizedBox(height: 22),

            // ── CTA — Golden gradient with gentle pulse ────────────────────
            // Uses AnimatedBuilder only on the scale transform so only
            // the button geometry redraws, not the whole card.
            AnimatedBuilder(
              animation: _ctaScaleAnim,
              builder: (_, child) =>
                  Transform.scale(scale: _ctaScaleAnim.value, child: child),
              child: _GoldenButton(
                label: isMonthly ? 'Get Pro — PKR 399/mo' : 'Buy 50 Credits',
                onTap: () {
                  // TODO: wire to RevenueCat purchase flow
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Payment coming soon! 🚀',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                      backgroundColor: const Color(0xFF6C63FF),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MAYBE LATER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMaybeLater(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        'Maybe later',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: Colors.white.withOpacity(0.35),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GOLDEN CTA BUTTON — extracted widget for cleaner AnimatedBuilder usage.
//  Material + InkWell gives a proper ripple on top of the gradient.
// ─────────────────────────────────────────────────────────────────────────────
class _GoldenButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GoldenButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withOpacity(0.20),
        highlightColor: Colors.white.withOpacity(0.10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E), // dark text on gold — high contrast
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────
class _Feature {
  final String name;
  final String freeValue;
  final String proValue;
  const _Feature(this.name, this.freeValue, this.proValue);
}

class _BenefitChip {
  final String icon;
  final String label;
  final Color color;
  const _BenefitChip(this.icon, this.label, this.color);
}
