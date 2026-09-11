import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ustaad/core/analytics/analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PlansScreen: the Ustaad Pro paywall
//
//  The rest of the app lives in indigo and violet. Pro should feel like a step
//  up from that rather than more of it, so this screen switches to the colour
//  opposite: a warm midnight ground lit in champagne and amber, the gold of
//  Ustu's crown. Indigo stays only as a faint glow at the top edge, so the
//  screen still belongs to the same app.
// ─────────────────────────────────────────────────────────────────────────────

/// The Pro palette. Used on this screen only.
abstract final class _Pro {
  static const ink = Color(0xFF0C0A18);
  static const dusk = Color(0xFF1F1533);
  static const champagne = Color(0xFFF2D59B);
  static const paleGold = Color(0xFFF8E4B6);
  static const amber = Color(0xFFDDA24F);
  static const cream = Color(0xFFFFF6E6);
  static const coral = Color(0xFFFF8A6B);
  static const mist = Color(0xFFB4AEC8);
}

enum _Plan { monthly, credits }

class _PlanInfo {
  final String tag;
  final String title;
  final String price;
  final String detail;
  final String cta;
  final String finePrint;

  const _PlanInfo({
    required this.tag,
    required this.title,
    required this.price,
    required this.detail,
    required this.cta,
    required this.finePrint,
  });
}

const _plans = {
  _Plan.monthly: _PlanInfo(
    tag: 'UNLIMITED',
    title: 'Pro Monthly',
    price: 'PKR 399',
    detail: 'a month, about PKR 13 a day',
    cta: 'Get Pro',
    finePrint: 'Cancel anytime.',
  ),
  _Plan.credits: _PlanInfo(
    tag: 'NO EXPIRY',
    title: 'Credit Pack',
    price: 'PKR 249',
    detail: '50 credits, pay once',
    cta: 'Get 50 credits',
    finePrint: 'Spend credits on explanations, quizzes and papers.',
  ),
};

class _Benefit {
  final IconData icon;
  final String title;
  final String detail;

  /// What the free plan gets instead, shown struck through.
  final String free;

  const _Benefit(this.icon, this.title, this.detail, this.free);
}

const _benefits = [
  _Benefit(
    Icons.auto_awesome_rounded,
    'Unlimited explanations',
    'English and Urdu, at priority speed',
    '5 a day',
  ),
  _Benefit(
    Icons.bolt_rounded,
    'Unlimited quizzes',
    'Any section, as often as you like',
    '10 a day',
  ),
  _Benefit(
    Icons.article_outlined,
    'Every full past paper',
    'Complete papers, not just sections',
    '2 a month',
  ),
  _Benefit(
    Icons.track_changes_rounded,
    'Custom tests on weak topics',
    'Detailed analytics on what costs you marks',
    'Basic',
  ),
];

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen>
    with TickerProviderStateMixin {
  _Plan _selected = _Plan.monthly;

  /// One entrance for the whole screen, each part on its own slice of it.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  /// Ustu's slow float and the glow behind him.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  late final Animation<double> _heroIn = _phase(0.0, 0.55);
  late final Animation<double> _titleIn = _phase(0.12, 0.6);
  late final Animation<double> _plansIn = _phase(0.3, 0.75);
  late final List<Animation<double>> _benefitsIn = [
    for (var i = 0; i < _benefits.length; i++)
      _phase(0.42 + i * 0.06, 0.78 + i * 0.06),
  ];
  late final Animation<double> _ctaIn = _phase(0.5, 0.95);

  bool _started = false;

  Animation<double> _phase(double begin, double end) => CurvedAnimation(
    parent: _entrance,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    // Counts how many people reach the paywall at all. Against quiz_finished
    // it says whether nobody wants to pay, or nobody is getting this far —
    // two very different problems with two very different fixes.
    Analytics.instance.paywallViewed(source: 'plans_screen');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
      _ambient.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _select(_Plan plan) {
    if (plan == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = plan);
  }

  void _continue() {
    // TODO: wire to RevenueCat purchase flow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Payment coming soon! 🚀',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: _Pro.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _Pro.champagne,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plans[_selected]!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _Pro.ink,
        body: Stack(
          children: [
            const Positioned.fill(child: _Backdrop()),
            SafeArea(
              child: Column(
                children: [
                  const _TopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                      child: _Column(
                        children: [
                          _Reveal(
                            animation: _heroIn,
                            lift: 0,
                            scaleFrom: 0.9,
                            child: _Hero(ambient: _ambient),
                          ),
                          const SizedBox(height: 4),
                          _Reveal(animation: _titleIn, child: const _Headline()),
                          const SizedBox(height: 24),
                          // Plans before benefits, so both options and their
                          // prices are on the first screen of a normal phone.
                          _Reveal(
                            animation: _plansIn,
                            child: _PlanPicker(
                              selected: _selected,
                              onSelect: _select,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _BenefitList(rows: _benefitsIn),
                        ],
                      ),
                    ),
                  ),
                  _Reveal(
                    animation: _ctaIn,
                    child: _BottomPanel(plan: plan, onContinue: _continue),
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

/// Centres content and keeps it phone-width on tablets and the web.
class _Column extends StatelessWidget {
  final List<Widget> children;
  const _Column({required this.children});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double lift;
  final double scaleFrom;

  const _Reveal({
    required this.animation,
    required this.child,
    this.lift = 18,
    this.scaleFrom = 1,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final t = animation.value;
        Widget moved = Transform.translate(
          offset: Offset(0, lift * (1 - t)),
          child: child,
        );
        if (scaleFrom != 1) {
          moved = Transform.scale(
            scale: scaleFrom + (1 - scaleFrom) * t,
            child: moved,
          );
        }
        return Opacity(opacity: t.clamp(0.0, 1.0), child: moved);
      },
    );
  }
}

// ── Backdrop ────────────────────────────────────────────────────────────────

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Pro.dusk, _Pro.ink],
          stops: [0, 0.6],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // The app's indigo, kept as a trace at the top edge.
          Positioned(
            top: -170,
            left: -140,
            child: _Glow(color: Color(0x4D6C63FF), size: 400),
          ),
          Positioned(
            top: 30,
            right: -190,
            child: _Glow(color: Color(0x2EDDA24F), size: 420),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Semantics(
          button: true,
          label: 'Close',
          child: GestureDetector(
            key: const Key('plans-close'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.maybePop(context),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _Pro.cream.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero ────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final Animation<double> ambient;
  const _Hero({required this.ambient});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: ambient,
            builder: (_, child) => Transform.scale(
              scale: 0.94 + 0.08 * Curves.easeInOut.transform(ambient.value),
              child: child,
            ),
            child: const _Glow(color: Color(0x4DF2D59B), size: 250),
          ),
          AnimatedBuilder(
            animation: ambient,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, 4 - 8 * Curves.easeInOut.transform(ambient.value)),
              child: child,
            ),
            child: RepaintBoundary(
              child: SvgPicture.asset(
                'assets/images/plans_ustu.svg',
                height: 186,
                width: 186,
                excludeFromSemantics: true,
                placeholderBuilder: (_) =>
                    const SizedBox(width: 186, height: 186),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Headline ────────────────────────────────────────────────────────────────

class _Headline extends StatelessWidget {
  const _Headline();

  static const _title = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.12,
    letterSpacing: -0.8,
    color: _Pro.cream,
  );

  @override
  Widget build(BuildContext context) {
    final rule = Container(
      width: 22,
      height: 1,
      color: _Pro.champagne.withValues(alpha: 0.5),
    );

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            rule,
            const SizedBox(width: 10),
            const Text(
              'USTAAD PRO',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
                color: _Pro.champagne,
              ),
            ),
            const SizedBox(width: 10),
            rule,
          ],
        ),
        const SizedBox(height: 14),
        const Text('Limit khatam.', textAlign: TextAlign.center, style: _title),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_Pro.paleGold, _Pro.amber],
          ).createShader(bounds),
          child: const Text(
            'Tayyari shuru.',
            textAlign: TextAlign.center,
            style: _title,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '5,200+ real past paper questions.\nPractise them without a daily cap.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            height: 1.55,
            color: _Pro.mist.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

// ── Benefits ────────────────────────────────────────────────────────────────

class _BenefitList extends StatelessWidget {
  final List<Animation<double>> rows;
  const _BenefitList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Pro.champagne.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _benefits.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: 70, right: 16),
                color: Colors.white.withValues(alpha: 0.05),
              ),
            _Reveal(
              animation: rows[i],
              lift: 10,
              child: _BenefitRow(benefit: _benefits[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final _Benefit benefit;
  const _BenefitRow({required this.benefit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _Pro.champagne.withValues(alpha: 0.18),
                  _Pro.amber.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: _Pro.champagne.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(benefit.icon, size: 20, color: _Pro.champagne),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _Pro.cream,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  benefit.detail,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: _Pro.mist.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'FREE',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: _Pro.mist.withValues(alpha: 0.5),
                ),
              ),
              Text(
                benefit.free,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: _Pro.mist.withValues(alpha: 0.7),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _Pro.coral.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Plans ───────────────────────────────────────────────────────────────────

class _PlanPicker extends StatelessWidget {
  final _Plan selected;
  final ValueChanged<_Plan> onSelect;
  const _PlanPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final plan in _Plan.values) ...[
            if (plan != _Plan.values.first) const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                plan: plan,
                selected: plan == selected,
                onTap: () => onSelect(plan),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = _plans[plan]!;
    final fg = selected ? _Pro.ink : _Pro.cream;
    final soft = selected
        ? _Pro.ink.withValues(alpha: 0.62)
        : _Pro.mist.withValues(alpha: 0.85);

    return Semantics(
      button: true,
      selected: selected,
      label: '${info.title}, ${info.price}, ${info.detail}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('plan-${plan.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 16),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_Pro.cream, _Pro.champagne],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? _Pro.amber
                  : _Pro.champagne.withValues(alpha: 0.16),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _Pro.amber.withValues(alpha: selected ? 0.28 : 0),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? _Pro.ink
                              : _Pro.coral.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          info.tag,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: selected ? _Pro.champagne : _Pro.coral,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _Check(selected: selected),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                info.title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  info.price,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.2,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                info.detail,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  height: 1.35,
                  color: soft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool selected;
  const _Check({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _Pro.ink : Colors.transparent,
        border: Border.all(
          color: selected ? _Pro.ink : _Pro.mist.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: selected ? 1 : 0,
        child: const Icon(Icons.check_rounded, size: 14, color: _Pro.champagne),
      ),
    );
  }
}

// ── Bottom panel ────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final _PlanInfo plan;
  final VoidCallback onContinue;
  const _BottomPanel({required this.plan, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _Pro.ink.withValues(alpha: 0.88),
        border: Border(
          top: BorderSide(color: _Pro.champagne.withValues(alpha: 0.08)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
        child: _Column(
          children: [
            _ProButton(
              key: const Key('plans-cta'),
              label: '${plan.cta}  ·  ${plan.price}',
              onTap: onContinue,
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                plan.finePrint,
                key: ValueKey(plan.finePrint),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: _Pro.mist.withValues(alpha: 0.8),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              style: TextButton.styleFrom(
                foregroundColor: _Pro.mist,
                minimumSize: const Size(120, 40),
              ),
              child: Text(
                'Maybe later',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _Pro.mist.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gold button. A light catches across it every few seconds, and it gives
/// under the finger when pressed.
class _ProButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _ProButton({super.key, required this.label, required this.onTap});

  @override
  State<_ProButton> createState() => _ProButtonState();
}

class _ProButtonState extends State<_ProButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shine.stop();
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_Pro.paleGold, _Pro.champagne, _Pro.amber],
                stops: [0, 0.45, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: _Pro.amber.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _shine,
                        builder: (_, child) {
                          // Sweeps across in the first third, then rests.
                          final t = Curves.easeInOut.transform(
                            (_shine.value / 0.32).clamp(0.0, 1.0),
                          );
                          return FractionalTranslation(
                            translation: Offset(-1.2 + 2.4 * t, 0),
                            child: child,
                          );
                        },
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1, -0.4),
                              end: Alignment(1, 0.4),
                              colors: [
                                Color(0x00FFFFFF),
                                Color(0x73FFFFFF),
                                Color(0x00FFFFFF),
                              ],
                              stops: [0.3, 0.5, 0.7],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _Pro.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: _Pro.ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
