import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/providers/credits_provider.dart';
import 'package:ustaad/screens/plans/plans_screen.dart';

// ─── Inline colors ────────────────────────────────────────────────────────────
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
// Changes vs previous version:
//   • _GlowingOwl     — pulsing purple aura on the owl while Gemini is loading
//   • "Ustu is thinking" text shimmers left-to-right like a glisten sweep
//   • _TypingText      — character-by-character reveal when explanation arrives
//   • Tap explanation area to skip the typing animation instantly
// ─────────────────────────────────────────────────────────────────────────────

class ExplanationSheet extends ConsumerStatefulWidget {
  final Question question;
  const ExplanationSheet({super.key, required this.question});

  @override
  ConsumerState<ExplanationSheet> createState() => _ExplanationSheetState();
}

class _ExplanationSheetState extends ConsumerState<ExplanationSheet>
    with SingleTickerProviderStateMixin {
  bool _isUrdu = false;
  bool _loading = true;
  bool _isLocked = false; // true when user is out of credits
  String _explanation = '';

  // Stagger animations for sheet content
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
    // Credit check runs once on open. Language toggle never re-charges.
    _checkAndConsumeCredit();
  }

  void _setupAnimations() {
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    Animation<double> s(double b, double e) => CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(b, e, curve: Curves.easeOut),
    );
    _headerAnim = s(0.00, 0.45);
    _toggleAnim = s(0.10, 0.55);
    _recapAnim = s(0.18, 0.63);
    _correctAnim = s(0.26, 0.71);
    _explanationAnim = s(0.34, 0.79);
    _buttonAnim = s(0.55, 1.00);
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  // ── Credit gate — runs once when sheet opens ──────────────────────────────
  // THE BUG WAS HERE: ref.read(creditsProvider).value is NULL in initState
  // because the Firestore stream hasn't fired its first event yet.
  // Fix: await ref.read(creditsProvider.future) — this waits for the first
  // Firestore emission before checking. StreamProvider exposes .future for this.
  Future<void> _checkAndConsumeCredit() async {
    if (!mounted) return;

    UserCredits credits;
    try {
      // .future waits for the first stream emission — NOT null-safe to skip this
      credits = await ref.read(creditsProvider.future);
    } catch (_) {
      // Provider errored — fail open, never block user due to our own error
      _fetchExplanation();
      return;
    }

    if (!mounted) return;

    if (credits.canUseAI) {
      try {
        final service = ref.read(creditServiceProvider);
        await service.consumeForAI(credits);
      } catch (_) {
        // Write failed — still show explanation, fix silently
      }
      if (!mounted) return;
      _fetchExplanation();
    } else {
      // Out of free uses and no credits → show locked state
      setState(() {
        _loading = false;
        _isLocked = true;
      });
    }
  }

  Future<void> _fetchExplanation() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _explanation = '';
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final raw = _isUrdu
        ? widget.question.explanationUr
        : widget.question.explanationEn;

    setState(() {
      _explanation = raw.isNotEmpty ? raw : 'Explanation coming soon.';
      _loading = false;
    });
  }

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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF12174A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Flexible(
            child: _isLocked
                ? _buildLockedState()
                : SingleChildScrollView(
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

  // ─── Locked state — shown when user is out of free uses + credits ─────────
  Widget _buildLockedState() {
    final credits = ref.watch(creditsProvider).value;
    final remaining = credits?.credits ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),

          // ── Locked owl ──────────────────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _C.primary.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('🦉', style: TextStyle(fontSize: 32)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1464),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFFFD700),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Title ───────────────────────────────────────────────────────
          const Text(
            "You've used today's free\nAI explanations",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 10),

          // ── Subtitle ────────────────────────────────────────────────────
          Text(
            remaining > 0
                ? 'You have $remaining credit${remaining == 1 ? '' : 's'}. '
                      'Spend ${CreditCosts.aiPerCredit} to unlock this explanation.'
                : 'Free limit: ${CreditCosts.aiFreePerDay}/day. '
                      'Get credits or upgrade to Pro for unlimited access.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.white.withOpacity(0.50),
              height: 1.6,
            ),
          ),

          const SizedBox(height: 28),

          // ── Primary CTA ─────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlansScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C8DFF), Color(0xFF6C63FF)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _C.primary.withOpacity(0.40),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                remaining > 0
                    ? '⚡  Use ${CreditCosts.aiPerCredit} Credit'
                    : '✨  Get Credits or Go Pro',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Secondary — close ────────────────────────────────────────────
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe later',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header — owl glows when loading ─────────────────────────────────────
  Widget _buildHeader() {
    return _fadeUp(
      animation: _headerAnim,
      child: Row(
        children: [
          // Swap between glowing owl (loading) and static owl (done)
          _loading ? const _GlowingOwl() : _staticOwl(),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ustu's Explanation",
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

  Widget _staticOwl() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.25),
        shape: BoxShape.circle,
        border: Border.all(color: _C.primary.withOpacity(0.45), width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text('🦉', style: TextStyle(fontSize: 24)),
    );
  }

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
            fontSize: _isUrdu ? 16 : 12, // CHANGED
            height: _isUrdu ? 2.0 : 1.55,
          ),
        ),
      ),
    );
  }

  Widget _buildCorrectAnswerBadge() {
    final correctOption = widget.question.options[widget.question.correctIndex];
    final letter = ['A', 'B', 'C', 'D'][widget.question.correctIndex];
    return _fadeUp(
      animation: _correctAnim,
      child: Row(
        children: [
          // CHANGED — in _buildCorrectAnswerBadge(), replace the inner Row child
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _C.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.success.withOpacity(0.35)),
            ),
            // CHANGED: constrain width so long answers don't overflow
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 44,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min, // CHANGED
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
                Flexible(
                  // CHANGED: was plain Text
                  child: Text(
                    'Correct: $correctOption',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: _C.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis, // CHANGED
                    maxLines: 2, // CHANGED
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Explanation body ─────────────────────────────────────────────────────
  // Loading  → shimmer bars + glisten "Ustu is thinking..." text
  // Loaded   → _TypingText character-by-character reveal
  //            Tap anywhere on the text to skip and reveal instantly.
  Widget _buildExplanationBody() {
    return _fadeUp(
      animation: _explanationAnim,
      child: _loading ? _buildThinkingState() : _buildTypingText(),
    );
  }

  Widget _buildThinkingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Glisten "Ustu is thinking..." label ───────────────────────────
        const _GlistenText(text: '🦉  Ustu is thinking...'),
        const SizedBox(height: 14),
        // ── Shimmer lines ─────────────────────────────────────────────────
        ...List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShimmerBar(
              width: i == 3 ? 140.0 : double.infinity,
              delay: Duration(milliseconds: i * 120),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingText() {
    return _TypingText(
      text: _explanation,
      isUrdu: _isUrdu,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white.withOpacity(0.82),
        fontSize: _isUrdu ? 18 : 13, // CHANGED — bigger for Urdu
        height: _isUrdu ? 2.2 : 1.75,
      ),
    );
  }

  Widget _buildGotItButton() {
    final label = _isUrdu ? 'سمجھ گیا، اُستاد!' : 'Got it, thanks Ustu!';
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
            label,
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
// _GlowingOwl
// Pulsing concentric aura rings around the 🦉 avatar while the explanation
// is being fetched. The outer ring pulses in opacity; the inner ring pulses
// slightly in scale. Together they create a "thinking / transmitting" feel.
// ─────────────────────────────────────────────────────────────────────────────

class _GlowingOwl extends StatefulWidget {
  const _GlowingOwl();

  @override
  State<_GlowingOwl> createState() => _GlowingOwlState();
}

class _GlowingOwlState extends State<_GlowingOwl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final glow = _pulseAnim.value;
        return SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Outer glow ring ──────────────────────────────────────
              Transform.scale(
                scale: _scaleAnim.value * 1.15,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(glow * 0.55),
                        blurRadius: 18 + glow * 8,
                        spreadRadius: 2 + glow * 4,
                      ),
                    ],
                    border: Border.all(
                      color: const Color(
                        0xFF6C63FF,
                      ).withOpacity(0.15 + glow * 0.25),
                      width: 1.5,
                    ),
                    color: Colors.transparent,
                  ),
                ),
              ),
              // ── Inner avatar ─────────────────────────────────────────
              Transform.scale(
                scale: _scaleAnim.value,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF6C63FF,
                    ).withOpacity(0.22 + glow * 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(
                        0xFF6C63FF,
                      ).withOpacity(0.4 + glow * 0.25),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🦉', style: TextStyle(fontSize: 24)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GlistenText
// A left-to-right shimmer sweep over text — the "thinking" label.
// Uses a shader mask that slides a gradient across the text repeatedly.
// ─────────────────────────────────────────────────────────────────────────────

class _GlistenText extends StatefulWidget {
  final String text;
  const _GlistenText({required this.text});

  @override
  State<_GlistenText> createState() => _GlistenTextState();
}

class _GlistenTextState extends State<_GlistenText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
      builder: (_, __) {
        // Sweep position goes from -0.3 to 1.3 so the glisten enters and
        // exits fully rather than starting/ending at the edge.
        final sweepPos = -0.3 + (_anim.value * 1.6);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (sweepPos - 0.25).clamp(0.0, 1.0),
              sweepPos.clamp(0.0, 1.0),
              (sweepPos + 0.25).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFFFFD700), // gold base
              Color(0xFFFFFFFF), // bright white peak
              Color(0xFFFFD700), // gold tail
            ],
          ).createShader(bounds),
          child: Text(
            widget.text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white, // required for ShaderMask
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TypingText
// Reveals text character by character at a natural reading speed.
// Speed adapts to explanation length so it always finishes in ~2.5s max.
// Tap anywhere on the text to skip and reveal the full explanation instantly.
// ─────────────────────────────────────────────────────────────────────────────

class _TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isUrdu;

  const _TypingText({
    required this.text,
    required this.style,
    required this.isUrdu,
  });

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText> {
  int _visibleChars = 0;
  Timer? _timer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    final len = widget.text.length;
    // Aim to complete in ~2.2 seconds; minimum 10ms per char.
    final msPerChar = (2200 / len).clamp(10.0, 22.0).toInt();

    _timer = Timer.periodic(Duration(milliseconds: msPerChar), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      if (_visibleChars < len) {
        setState(() => _visibleChars++);
      } else {
        _timer?.cancel();
        _completed = true;
      }
    });
  }

  void _skipToEnd() {
    if (_completed) return;
    _timer?.cancel();
    setState(() {
      _visibleChars = widget.text.length;
      _completed = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(0, _visibleChars);
    return GestureDetector(
      onTap: _skipToEnd,
      behavior: HitTestBehavior.translucent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            visible,
            textDirection: widget.isUrdu
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: widget.style,
          ),
          // Blinking cursor while typing
          if (!_completed) ...[const SizedBox(height: 4), _BlinkingCursor()],
          // Skip hint — fades out once done
          if (!_completed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tap to skip →',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.22),
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlinkingCursor — typewriter-style blinking line
// ─────────────────────────────────────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _ctrl.value,
        child: Container(
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShimmerBar — kept private, used in thinking state
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
