import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/screens/explanation/explanation_screen.dart';
import 'package:ustaad/services/firestore_service.dart';
// Import the result screen
import 'result_screen.dart';

class UstaadColors {
  static const Color background1 = Color(0xFF0A0E2E);
  static const Color background2 = Color(0xFF1A1464);
  static const Color background3 = Color(0xFF6C63FF);
  static const Color primary = Color(0xFF6C63FF);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4CAF50);
  static const Color gold = Color(0xFFFFD700);
}

class QuizScreen extends StatefulWidget {
  final String exam;
  final String section;

  const QuizScreen({super.key, required this.exam, required this.section});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // ── Quiz state ─────────────────────────────────────────────────────────────
  List<Question> _questions = [];
  List<int?> _userAnswers = []; // TRACKS SELECTED ANSWERS
  bool _loadingQuestions = true;
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _answered = false;
  DateTime? _lastUstuTap;

  Question get _current => _questions[_currentIndex];

  // ── Entrance animation controller ─────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _headerAnim;
  late final Animation<double> _progressAnim;
  late final Animation<double> _badgeAnim;
  late final Animation<double> _questionAnim;
  late final Animation<double> _opt0Anim;
  late final Animation<double> _opt1Anim;
  late final Animation<double> _opt2Anim;
  late final Animation<double> _opt3Anim;
  late final Animation<double> _bottomAnim;

  // ── Feedback toast animation ───────────────────────────────────────────────
  late final AnimationController _toastCtrl;
  late final Animation<double> _toastAnim;

  final GlobalKey _ustuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _setupEntranceAnimations();
    _setupToastAnimation();
    _entranceCtrl.forward();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    // ─── DEBUG DIAGNOSTICS ──────────────────────────────────────────
    // This will print to your terminal to verify database connectivity
    print('\n🧪 --- RUNNING DB DIAGNOSTICS ---');
    await FirestoreService().debugRawQuery();
    print('🧪 --- END DB DIAGNOSTICS ---\n');

    // This prints exactly what the UI is sending to the database
    print(
      '📱 UI is requesting -> Exam: "${widget.exam}" | Section: "${widget.section}"',
    );
    // ────────────────────────────────────────────────────────────────

    final questions = await FirestoreService().fetchQuestions(
      exam: widget.exam,
      section: widget.section,
    );

    setState(() {
      _questions = questions;
      // Initialize answers list with nulls
      _userAnswers = List.filled(questions.length, null);
      _loadingQuestions = false;
    });

    _entranceCtrl.forward();
  }

  void _setupEntranceAnimations() {
    _entranceCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _headerAnim = _stagger(0.00, 0.50);
    _progressAnim = _stagger(0.06, 0.56);
    _badgeAnim = _stagger(0.12, 0.62);
    _questionAnim = _stagger(0.18, 0.68);
    _opt0Anim = _stagger(0.28, 0.78);
    _opt1Anim = _stagger(0.36, 0.86);
    _opt2Anim = _stagger(0.44, 0.94);
    _opt3Anim = _stagger(0.52, 1.00);
    _bottomAnim = _stagger(0.56, 1.00);
  }

  Animation<double> _stagger(double begin, double end) => CurvedAnimation(
    parent: _entranceCtrl,
    curve: Interval(begin, end, curve: Curves.easeOut),
  );

  void _setupToastAnimation() {
    _toastCtrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _toastAnim = CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _toastCtrl.dispose();
    super.dispose();
  }

  void _goNextQuestion() {
    // Check if we are at the end of the quiz
    if (_currentIndex + 1 >= _questions.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            questions: _questions,
            selectedAnswers: _userAnswers,
            exam: widget.exam,
            section: widget.section,
          ),
        ),
      );
      return;
    }

    _toastCtrl.reverse();
    _entranceCtrl.reverse().then((_) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _answered = false;
      });
      _entranceCtrl.forward();
    });
  }

  void _onOptionTapped(int index) {
    if (_answered) return;
    setState(() => _selectedIndex = index);
  }

  void _confirmAnswer() {
    if (_selectedIndex == null || _answered) return;
    HapticFeedback.lightImpact();

    // Save the selection before moving forward
    _userAnswers[_currentIndex] = _selectedIndex;

    setState(() => _answered = true);
    _toastCtrl.forward();
  }

  Future<void> _onUstuTapped() async {
    final now = DateTime.now();
    if (_lastUstuTap != null && now.difference(_lastUstuTap!).inSeconds < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ustu is thinking... wait a moment',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: UstaadColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _lastUstuTap = now;
    final renderBox = _ustuKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final startPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _FlyingOwlOverlay(
        startPosition: startPosition,
        buttonSize: buttonSize,
        onComplete: () {
          entry.remove();
          _showExplanationSheet();
        },
      ),
    );

    overlayState.insert(entry);
  }

  void _showExplanationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (_) => ExplanationSheet(question: _current),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingQuestions) {
      return Scaffold(
        backgroundColor: UstaadColors.background1,
        body: const Center(
          child: CircularProgressIndicator(color: UstaadColors.primary),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: UstaadColors.background1,
        body: Center(
          child: Text(
            'No questions found.\nCheck your Firestore data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontFamily: 'Poppins',
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: UstaadColors.background1,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  UstaadColors.background1,
                  UstaadColors.background2,
                  UstaadColors.background3,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // AFTER
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fixed top section ──────────────────────────
                _buildTopBar(),
                const SizedBox(height: 14),
                _buildProgressRow(),
                const SizedBox(height: 16),
                _buildSectionBadge(),
                const SizedBox(height: 14),

                // ── Scrollable middle (question + options) ─────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuestionCard(),
                          const SizedBox(height: 14),
                          _buildOptions(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Fixed bottom section ───────────────────────
                _buildFeedbackToast(),
                const SizedBox(height: 12),
                _buildBottomRow(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return _slideDown(
      animation: _headerAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _current.section,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showQuitDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: UstaadColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: UstaadColors.accent.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  'Quit',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: UstaadColors.accent.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow() {
    final progress = (_currentIndex + 1) / _questions.length;
    return _slideDown(
      animation: _progressAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Q ${_currentIndex + 1} of ${_questions.length}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: progress),
                duration: const Duration(milliseconds: 700),
                curve: const ElasticOutCurve(0.8),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    UstaadColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBadge() {
    return _slideDown(
      animation: _badgeAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: UstaadColors.primary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: UstaadColors.primary.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(),
              const SizedBox(width: 7),
              Text(
                '${widget.section} · ${widget.exam}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFFC8C4FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    return _slideDown(
      animation: _questionAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUESTION ${(_currentIndex + 1).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _current.text,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptions() {
    final anims = [_opt0Anim, _opt1Anim, _opt2Anim, _opt3Anim];
    final letters = ['A', 'B', 'C', 'D'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: List.generate(_current.options.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _slideUp(
              animation: anims[i],
              child: _OptionTile(
                letter: letters[i],
                text: _current.options[i],
                state: _optionState(i),
                onTap: () => _onOptionTapped(i),
              ),
            ),
          );
        }),
      ),
    );
  }

  _OptionState _optionState(int index) {
    if (!_answered)
      return index == _selectedIndex
          ? _OptionState.selected
          : _OptionState.idle;
    if (index == _current.correctIndex) return _OptionState.correct;
    if (index == _selectedIndex) return _OptionState.wrong;
    return _OptionState.idle;
  }

  Widget _buildFeedbackToast() {
    final isCorrect = _selectedIndex == _current.correctIndex;
    return AnimatedBuilder(
      animation: _toastAnim,
      builder: (_, __) => Opacity(
        opacity: _toastAnim.value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - _toastAnim.value)),
          child: !_answered
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? UstaadColors.success.withOpacity(0.15)
                          : UstaadColors.accent.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCorrect
                            ? UstaadColors.success.withOpacity(0.35)
                            : UstaadColors.accent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          isCorrect ? '✅' : '❌',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCorrect
                                    ? 'Correct! Well done.'
                                    : 'Not quite — review this one.',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCorrect
                                    ? 'Great work on this question.'
                                    : 'Correct answer: ${_current.options[_current.correctIndex]}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ],
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

  Widget _buildBottomRow() {
    return _slideUp(
      animation: _bottomAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            GestureDetector(
              key: _ustuKey,
              onTap: _onUstuTapped,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: UstaadColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: UstaadColors.primary.withOpacity(0.4),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('🦉', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _selectedIndex != null ? 1.0 : 0.45,
                child: GestureDetector(
                  onTap: _selectedIndex == null
                      ? null
                      : _answered
                      ? _goNextQuestion
                      : _confirmAnswer,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: UstaadColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedIndex == null
                              ? 'Select an answer'
                              : _answered
                              ? (_currentIndex == _questions.length - 1
                                    ? 'Show Results'
                                    : 'Next question')
                              : 'Confirm answer',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slideDown({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, -20 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }

  Widget _slideUp({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }

  void _showQuitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Quit quiz?',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          "Your progress on this session won't be saved.",
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep going',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Quit',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: UstaadColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (
      bg,
      border,
      letterBg,
      letterBorder,
      letterColor,
      textColor,
    ) = switch (state) {
      _OptionState.idle => (
        Colors.white.withOpacity(0.07),
        Colors.white.withOpacity(0.1),
        const Color(0xFF6C63FF).withOpacity(0.18),
        const Color(0xFF6C63FF).withOpacity(0.3),
        const Color(0xFFC8C4FF),
        Colors.white.withOpacity(0.85),
      ),
      _OptionState.selected => (
        const Color(0xFF6C63FF).withOpacity(0.22),
        const Color(0xFF6C63FF).withOpacity(0.55),
        const Color(0xFF6C63FF),
        const Color(0xFF6C63FF),
        Colors.white,
        Colors.white,
      ),
      _OptionState.correct => (
        const Color(0xFF4CAF50).withOpacity(0.18),
        const Color(0xFF4CAF50).withOpacity(0.45),
        const Color(0xFF4CAF50),
        const Color(0xFF4CAF50),
        Colors.white,
        Colors.white,
      ),
      _OptionState.wrong => (
        const Color(0xFFFF6B6B).withOpacity(0.15),
        const Color(0xFFFF6B6B).withOpacity(0.4),
        const Color(0xFFFF6B6B),
        const Color(0xFFFF6B6B),
        Colors.white,
        Colors.white.withOpacity(0.7),
      ),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: letterBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: letterBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: letterColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                child: Text(text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
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
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Color.lerp(
            UstaadColors.primary,
            const Color(0xFF9B94FF),
            _anim.value,
          ),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _FlyingOwlOverlay extends StatefulWidget {
  final Offset startPosition;
  final Size buttonSize;
  final VoidCallback onComplete;

  const _FlyingOwlOverlay({
    required this.startPosition,
    required this.buttonSize,
    required this.onComplete,
  });

  @override
  State<_FlyingOwlOverlay> createState() => _FlyingOwlOverlayState();
}

class _FlyingOwlOverlayState extends State<_FlyingOwlOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _yAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _wobbleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 620),
      vsync: this,
    );

    _yAnim = Tween<double>(
      begin: widget.startPosition.dy,
      end: -90.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));

    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.5), weight: 80),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));

    _fadeAnim = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.7, 1.0)));

    _wobbleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _ctrl.forward().then((_) => widget.onComplete());
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
      builder: (_, __) => Positioned(
        left:
            widget.startPosition.dx +
            (widget.buttonSize.width / 2) -
            16 +
            _wobbleAnim.value,
        top: _yAnim.value + (widget.buttonSize.height / 2) - 16,
        child: Opacity(
          opacity: _fadeAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: const Text('🦉', style: TextStyle(fontSize: 32)),
          ),
        ),
      ),
    );
  }
}
