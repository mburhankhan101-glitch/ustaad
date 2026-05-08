import 'package:flutter/material.dart';

import 'package:ustaad/models/question_model.dart';

// ─── Inline colors — swap with UstaadColors import ───────────────────────────
class _C {
  static const primary = Color(0xFF6C63FF);
  static const bg1 = Color(0xFF0A0E2E);
  static const bg2 = Color(0xFF1A1464);
  static const gold = Color(0xFFFFD700);
  static const success = Color(0xFF4CAF50);
  static const accent = Color(0xFFFF6B6B);
}

// ─────────────────────────────────────────────────────────────────────────────
// ExplanationSheet
//
// Shown via showModalBottomSheet after the Ustu fly animation completes.
// The sheet itself slides up from the bottom (Flutter's default modal
// transition). Inside, elements stagger in from the bottom for depth.
//
// Layout:
//   ┌─────────────────────────────────┐
//   │  drag handle                    │
//   │  🦉 Ustu header                 │
//   │  language toggle (EN | اردو)    │
//   │  question recap card            │
//   │  correct answer badge           │
//   │  AI explanation text            │
//   │  [ Got it ] button              │
//   └─────────────────────────────────┘
//
// TODO: wire _fetchExplanation() to your gemini_service.dart
// ─────────────────────────────────────────────────────────────────────────────

class ExplanationSheet extends StatefulWidget {
  final Question question;

  const ExplanationSheet({super.key, required this.question});

  @override
  State<ExplanationSheet> createState() => _ExplanationSheetState();
}

class _ExplanationSheetState extends State<ExplanationSheet>
    with SingleTickerProviderStateMixin {
  // ── Language toggle ────────────────────────────────────────────────────────
  bool _isUrdu = false;

  // ── AI explanation state ───────────────────────────────────────────────────
  bool _loading = true;
  String _explanation = '';

  // ── Stagger animation for sheet content ───────────────────────────────────
  late final AnimationController _staggerCtrl;
  late final Animation<double> _headerAnim;
  late final Animation<double> _toggleAnim;
  late final Animation<double> _recapAnim;
  late final Animation<double> _correctAnim;
  late final Animation<double> _explanationAnim;
  late final Animation<double> _buttonAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _staggerCtrl.forward();
    _fetchExplanation();
  }

  void _setupAnimations() {
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    Animation<double> _s(double begin, double end) => CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );

    _headerAnim = _s(0.00, 0.45);
    _toggleAnim = _s(0.10, 0.55);
    _recapAnim = _s(0.18, 0.63);
    _correctAnim = _s(0.26, 0.71);
    _explanationAnim = _s(0.34, 0.79);
    _buttonAnim = _s(0.55, 1.00);
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  // ── Fetch explanation from Gemini ──────────────────────────────────────────
  Future<void> _fetchExplanation() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _explanation = '';
    });

    // Simulate Ustu "thinking" for 2 seconds as you described
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final explanation = _isUrdu
        ? widget.question.explanationUr
        : widget.question.explanationEn;

    setState(() {
      _explanation = explanation.isNotEmpty
          ? explanation
          : 'Explanation coming soon for this question.';
      _loading = false;
    });
  }

  // Re-fetch when language is toggled
  void _onLanguageToggle(bool urdu) {
    setState(() {
      _isUrdu = urdu;
      _loading = true;
      _explanation = '';
    });
    _fetchExplanation();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Sheet takes up 80% of screen height — scrolls if content overflows
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        // Sheet has its own dark gradient so it feels like a floating panel
        color: Color(0xFF12174A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle — Flutter's native enableDrag handles swipe-down dismiss.
          // We only add onTap so tapping the handle also closes the sheet cleanly.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildLanguageToggle(),
                  const SizedBox(height: 18),
                  _buildQuestionRecap(),
                  const SizedBox(height: 12),
                  _buildCorrectAnswerBadge(),
                  const SizedBox(height: 16),
                  _buildExplanationBody(),
                  const SizedBox(height: 24),
                  _buildGotItButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ustu header ──────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return _fadeUp(
      animation: _headerAnim,
      child: Row(
        children: [
          // Owl avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.primary.withOpacity(0.45),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: const Text('🦉', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ustu\'s Explanation',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'AI-powered · ${widget.question.section}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Language toggle ──────────────────────────────────────────────────────
  Widget _buildLanguageToggle() {
    return _fadeUp(
      animation: _toggleAnim,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            _toggleOption('English', !_isUrdu, () => _onLanguageToggle(false)),
            _toggleOption('اردو', _isUrdu, () => _onLanguageToggle(true)),
          ],
        ),
      ),
    );
  }

  Widget _toggleOption(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? _C.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: active ? Colors.white : Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Question recap ───────────────────────────────────────────────────────
  Widget _buildQuestionRecap() {
    return _fadeUp(
      animation: _recapAnim,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          widget.question.text,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
            height: 1.55,
          ),
        ),
      ),
    );
  }

  // ─── Correct answer badge ─────────────────────────────────────────────────
  Widget _buildCorrectAnswerBadge() {
    final correctOption = widget.question.options[widget.question.correctIndex];
    final letter = ['A', 'B', 'C', 'D'][widget.question.correctIndex];

    return _fadeUp(
      animation: _correctAnim,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _C.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.success.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _C.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Correct: $correctOption',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: _C.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AI explanation body ──────────────────────────────────────────────────
  Widget _buildExplanationBody() {
    return _fadeUp(
      animation: _explanationAnim,
      child: _loading
          ? _buildShimmer()
          : Text(
              _explanation,
              textDirection: _isUrdu ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.82),
                fontSize: 13,
                height: 1.75,
              ),
            ),
    );
  }

  // Shimmer placeholder while Gemini is thinking
  Widget _buildShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🦉', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(
              'Ustu is thinking...',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _C.gold.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(4, (i) => _shimmerLine(i)),
      ],
    );
  }

  Widget _shimmerLine(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ShimmerBar(
        width: index == 3 ? 140.0 : double.infinity,
        delay: Duration(milliseconds: index * 120),
      ),
    );
  }

  // ─── Got it button ────────────────────────────────────────────────────────
  // Text switches language with the toggle.
  // Navigator.pop() closes the sheet and returns to QuizScreen on same question.
  Widget _buildGotItButton() {
    final buttonLabel = _isUrdu ? 'سمجھ گیا، اُستاد!' : 'Got it, thanks Ustu!';

    return _fadeUp(
      animation: _buttonAnim,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _C.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            buttonLabel,
            textDirection: _isUrdu ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Animation helper ─────────────────────────────────────────────────────
  Widget _fadeUp({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER BAR — animated loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBar extends StatefulWidget {
  final double width;
  final Duration delay;

  const _ShimmerBar({required this.width, required this.delay});

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 900),
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
        height: 12,
        decoration: BoxDecoration(
          color: Color.lerp(
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.13),
            _anim.value,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
