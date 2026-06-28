import 'package:flutter/material.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  // Toggle between 'monthly' and 'credits'
  String _selected = 'monthly';

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
              // ── Top bar ────────────────────────────────────────────────
              _buildTopBar(context),

              // ── Scrollable body ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      _buildHeroSection(),
                      const SizedBox(height: 28),
                      _buildComparisonTable(),
                      const SizedBox(height: 28),
                      _buildToggle(),
                      const SizedBox(height: 16),
                      _buildPricingCard(),
                      const SizedBox(height: 12),
                      _buildMaybeLater(context),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 32,
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

  // ── Top bar ──────────────────────────────────────────────────────────────
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
          // Spacer to balance the back button
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // ── Hero section ─────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Column(
      children: [
        // Ustu owl icon placeholder (replace with your Lottie/Image widget)
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B7FFF), Color(0xFF6C63FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.55),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text('🦉', style: TextStyle(fontSize: 34)),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Unlock Your Full Potential',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Unlimited AI explanations, papers & more',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Colors.white.withOpacity(0.55),
          ),
        ),
      ],
    );
  }

  // ── Comparison table ─────────────────────────────────────────────────────
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
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Feature',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9C8DFF),
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
                          color: Colors.white.withOpacity(0.45),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
                        ).createShader(bounds),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Feature rows
          ...features.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            final isLast = i == features.length - 1;

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
                            fontSize: 13,
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
                              fontWeight: FontWeight.w500,
                              color: f.freeValue == '✗'
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.white.withOpacity(0.50),
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
                              fontWeight: FontWeight.w600,
                              color: f.proValue == '✓'
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

  // ── Toggle: Monthly / Credits ─────────────────────────────────────────────
  Widget _buildToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          _toggleTab('monthly', 'Pro Monthly'),
          _toggleTab('credits', 'Credit Pack'),
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
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.40),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.white.withOpacity(0.45),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pricing card ─────────────────────────────────────────────────────────
  Widget _buildPricingCard() {
    final isMonthly = _selected == 'monthly';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isMonthly
              ? [const Color(0xFF3D35B8), const Color(0xFF6C63FF)]
              : [const Color(0xFF1E2A4A), const Color(0xFF2D3A6B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMonthly
              ? const Color(0xFF9C8DFF).withOpacity(0.50)
              : const Color(0xFFFFD700).withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: isMonthly
                ? const Color(0xFF6C63FF).withOpacity(0.40)
                : const Color(0xFFFFD700).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
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
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.50),
                    ),
                  ),
                  child: const Text(
                    'Most Popular',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isMonthly ? 'PKR 399' : 'PKR 249',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
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
              color: Colors.white.withOpacity(0.60),
            ),
          ),

          const SizedBox(height: 20),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1464),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                isMonthly ? 'Get Pro — PKR 399/mo' : 'Buy 50 Credits',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Maybe later link ──────────────────────────────────────────────────────
  Widget _buildMaybeLater(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        'Maybe later',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: Colors.white.withOpacity(0.38),
        ),
      ),
    );
  }
}

// ── Feature model ─────────────────────────────────────────────────────────
class _Feature {
  final String name;
  final String freeValue;
  final String proValue;

  const _Feature(this.name, this.freeValue, this.proValue);
}
