import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/core/utils/connectivity_service.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/providers/credits_provider.dart';
import 'package:ustaad/screens/explanation/explanation_screen.dart';
import 'package:ustaad/screens/plans/plans_screen.dart';
import 'package:ustaad/services/firestore_service.dart';
import 'package:ustaad/services/haptic_service.dart';
import 'package:ustaad/widgets/common/skeleton_widgets.dart';
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

class QuizScreen extends ConsumerStatefulWidget {
  final String exam;
  final String section;
  final int initialIndex;
  final String? topic;
  final int limit;
  final bool isWeakTopicPractice;

  /// Set to TRUE when launching from the "Continue" card on HomeScreen.
  /// Skips the credit deduction — user already paid for this session.
  /// Set to FALSE (default) for every fresh quiz start.
  final bool isResumingSession;

  const QuizScreen({
    super.key,
    required this.exam,
    required this.section,
    this.initialIndex = 0,
    this.topic,
    this.limit = 10,
    this.isWeakTopicPractice = false,
    this.isResumingSession = false, // ← default: new session, check credits
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with TickerProviderStateMixin {
  List<Question> _questions = [];
  List<int?> _userAnswers = [];
  bool _loadingQuestions = true;
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _answered = false;
  DateTime? _lastUstuTap;
  StreamSubscription<bool>? _connectivitySub;
  bool _isOffline = false;
  bool _isNavigating = false;
  bool _loadOfflineError = false;
  bool _quizCompleted = false;
  bool _isLocked =
      false; // true when user has no credits and free tier exhausted

  Question get _current => _questions[_currentIndex];

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
  late final AnimationController _toastCtrl;
  late final Animation<double> _toastAnim;

  final GlobalKey _ustuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _setupEntranceAnimations();
    _setupToastAnimation();
    _entranceCtrl.forward();

    // Route based on session type:
    // - Resuming (Continue card) → skip credit check, load directly
    // - New session              → check + deduct credits first
    if (widget.isResumingSession) {
      _loadQuestions();
    } else {
      _checkAndConsumeCredit();
    }

    _connectivitySub = ConnectivityService().onlineStream.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOffline = !online;
        if (online) _loadOfflineError = false;
      });
      if (online && _questions.isEmpty && !_loadingQuestions) {
        setState(() => _loadingQuestions = true);
        _loadQuestions();
      }
    });
  }

  // ── Credit gate ───────────────────────────────────────────────────────────
  // Called only for NEW sessions. Resumed sessions bypass this entirely.
  //
  // Uses .future to wait for the first Firestore emission — same fix as
  // ExplanationSheet. ref.read(creditsProvider).value is null in initState
  // because the stream hasn't fired yet.
  //
  // Deducts on START so users can't game it by quitting before the last Q.
  Future<void> _checkAndConsumeCredit() async {
    if (!mounted) return;

    UserCredits credits;
    try {
      credits = await ref.read(creditsProvider.future);
    } catch (_) {
      // Provider errored — fail open, never block the student
      _loadQuestions();
      return;
    }

    if (!mounted) return;

    if (credits.canStartQuiz) {
      try {
        await ref.read(creditServiceProvider).consumeForQuiz(credits);
      } catch (_) {
        // Write failed — still let them in, fix silently
      }
      if (!mounted) return;
      _loadQuestions();
    } else {
      // Out of free sessions and credits → show locked screen
      setState(() {
        _loadingQuestions = false;
        _isLocked = true;
      });
    }
  }

  Future<void> _loadQuestions() async {
    final isOnline = await ConnectivityService().isOnline();
    if (!isOnline) {
      setState(() {
        _loadingQuestions = false;
        _loadOfflineError = true;
        _isOffline = true;
      });
      return;
    }

    final questions = await FirestoreService().fetchQuestions(
      exam: widget.exam,
      section: widget.section,
      uid: FirebaseAuth.instance.currentUser!.uid,
      limit: widget.limit,
      topic: widget.topic,
    );

    setState(() {
      _questions = questions;
      _userAnswers = List.generate(questions.length, (i) {
        return i < widget.initialIndex ? -2 : null;
      });
      _currentIndex = questions.isEmpty
          ? 0
          : widget.initialIndex.clamp(0, questions.length - 1);
      _loadingQuestions = false;
      _loadOfflineError = false;
      _isOffline = false;
    });

    _entranceCtrl.forward();
  }

  Future<void> _saveIncompleteSession() async {
    if (_quizCompleted || _questions.isEmpty || widget.topic != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirestoreService().saveIncompleteSession(
      uid: uid,
      exam: widget.exam,
      section: widget.section,
      currentIndex: _currentIndex,
      totalQuestions: _questions.length,
    );
  }

  Future<void> _clearIncompleteSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirestoreService().clearIncompleteSession(uid: uid);
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
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _entranceCtrl.dispose();
    _toastCtrl.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _goNextQuestion() {
    if (_currentIndex + 1 >= _questions.length) {
      _quizCompleted = true;
      _clearIncompleteSession();

      final poolSize =
          FirestoreService().getPoolSize(widget.exam, widget.section) ??
          _questions.length;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            questions: _questions,
            selectedAnswers: _userAnswers,
            exam: widget.exam,
            section: widget.section,
            poolSize: poolSize,
            isWeakTopicPractice: widget.isWeakTopicPractice, // ← Bug 2 flag
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
    HapticService.selection();
    _userAnswers[_currentIndex] = _selectedIndex;
    setState(() => _answered = true);
    _toastCtrl.forward();
  }

  Future<void> _onUstuTapped() async {
    final now = DateTime.now();
    if (_lastUstuTap != null && now.difference(_lastUstuTap!).inSeconds < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    // Locked — user has no credits and free tier exhausted
    if (_isLocked) return _buildLockedScaffold();

    // Offline state
    if (_isOffline || _loadOfflineError) {
      return Scaffold(
        backgroundColor: UstaadColors.background1,
        body: NoInternetWidget(
          onRetry: () async {
            final isOnline = await ConnectivityService().isOnline();
            if (isOnline) {
              setState(() {
                _isOffline = false;
                _loadOfflineError = false;
              });
              if (_questions.isEmpty) {
                setState(() => _loadingQuestions = true);
                _loadQuestions();
              }
            }
          },
          onBack: () => Navigator.of(context).pop(),
        ),
      );
    }

    // Loading
    if (_loadingQuestions) {
      return const QuizLoadingSkeleton();
    }

    // Empty
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

    // ── Main quiz UI ──────────────────────────────────────────────────────
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showQuitDialog();
      },
      child: Scaffold(
        backgroundColor: UstaadColors.background1,
        body: Stack(
          children: [
            // Full-screen gradient background
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

            // ── Web: centered constrained content ──────────────────────
            if (isWeb)
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 14),
                        _buildProgressRow(),
                        const SizedBox(height: 16),
                        _buildSectionBadge(),
                        const SizedBox(height: 14),
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
                        _buildFeedbackToast(),
                        const SizedBox(height: 12),
                        _buildBottomRow(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Mobile: full screen (unchanged) ────────────────────────
            if (!isWeb)
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 14),
                    _buildProgressRow(),
                    const SizedBox(height: 16),
                    _buildSectionBadge(),
                    const SizedBox(height: 14),
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
                    _buildFeedbackToast(),
                    const SizedBox(height: 12),
                    _buildBottomRow(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Locked scaffold — shown when free tier exhausted + no credits ─────────
  Widget _buildLockedScaffold() {
    final creditsAsync = ref.watch(creditsProvider);
    final credits = creditsAsync.value;
    final balance = credits?.credits ?? 0;

    return Scaffold(
      backgroundColor: UstaadColors.background1,
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Locked owl
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: UstaadColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: UstaadColors.primary.withOpacity(0.25),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '🦉',
                            style: TextStyle(fontSize: 40),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1464),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFFFFD700),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "You've used today's\nfree quiz sessions",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      balance > 0
                          ? 'You have $balance credit${balance == 1 ? '' : 's'}. '
                                'A quiz session costs ${CreditCosts.quizCredits} credits.'
                          : 'Free limit: ${CreditCosts.quizFreePerDay} sessions/day.\n'
                                'Get credits or upgrade to Pro for unlimited quizzes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.50),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Primary CTA → PlansScreen
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const PlansScreen()),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9C8DFF), Color(0xFF6C63FF)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: UstaadColors.primary.withOpacity(0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          balance >= CreditCosts.quizCredits
                              ? '⚡  Use ${CreditCosts.quizCredits} Credits'
                              : '✨  Get Credits or Go Pro',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Secondary — go back
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return _slideDown(
      animation: _headerAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showQuitDialog,
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
    if (!_answered) {
      return index == _selectedIndex
          ? _OptionState.selected
          : _OptionState.idle;
    }
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

  // ═══════════════════════════════════════════════════════════════════════════
  // FIXED: Quit now pops the quiz screen itself — no more stuck screen.
  // ═══════════════════════════════════════════════════════════════════════════
  void _showQuitDialog() {
    if (_isNavigating) return;
    showDialog(
      context: context,
      barrierDismissible: false,
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
          "Ustu will save your spot. You can continue from here later.",
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              setState(() => _isNavigating = false); // unlock quit
            },
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
            onPressed: () async {
              if (_isNavigating) return;
              setState(() => _isNavigating = true);
              try {
                await _saveIncompleteSession();
                if (!mounted) return;
                Navigator.of(context).pop(); // close dialog
                // ⬇️ KEY FIX: pop the quiz screen itself
                Navigator.of(context).pop();
              } finally {
                if (mounted) setState(() => _isNavigating = false);
              }
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

  // ── Animation helpers ──────────────────────────────────────────────────────

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
}

// ─── Supporting widgets (unchanged) ───────────────────────────────────────────

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

// ── No Internet Widget ────────────────────────────────────────────────────────
class NoInternetWidget extends StatefulWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const NoInternetWidget({
    super.key,
    required this.onRetry,
    required this.onBack,
  });

  @override
  State<NoInternetWidget> createState() => _NoInternetWidgetState();
}

class _NoInternetWidgetState extends State<NoInternetWidget> {
  static const _lines = [
    'Lagta hai Abba jee ne internet ke paise\nnahi jama krwaye iss mahiney 😬',
    'Reels ke liye internet full taiz chalta hai\ntumhara! 📱',
    'Bhai WiFi ka password phir badal diya\nkya ghar walon ne? 🔐',
    'Ustu bhi offline ho gaya... aur wo toh\nowl hai! 🦉',
    'PTCL walo ne phir scene kar diya\nlagta hai ☎️',
    'Internet nahi toh padhai nahi?\nYe wali excuse nahi chalegi! 📚',
  ];

  late String _currentLine;

  @override
  void initState() {
    super.initState();
    _currentLine = (_lines.toList()..shuffle()).first;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/images/ustu_no_internet.svg', height: 180),
            const SizedBox(height: 28),
            Text(
              _currentLine,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _currentLine = (_lines.toList()..shuffle()).first;
                });
                widget.onRetry();
              },
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6C63FF)),
              label: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onBack,
              child: Text(
                'Go Back',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
