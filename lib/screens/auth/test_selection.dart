import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _Subject {
  final String name;
  final double weightage; // 0.0 – 1.0
  const _Subject(this.name, this.weightage);
}

class _DegreeOption {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;

  const _DegreeOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

class _TestOption {
  final String id;
  final String shortName;
  final String fullName;
  final String description;
  final IconData icon;
  final Color accentColor;
  final Map<String, List<_Subject>> weightages;

  const _TestOption({
    required this.id,
    required this.shortName,
    required this.fullName,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.weightages,
  });

  List<_Subject> subjectsFor(String? degreeId) =>
      weightages[degreeId] ?? weightages['default'] ?? [];
}

// ─────────────────────────────────────────────────────────────────────────────
// STATIC DATA
// ─────────────────────────────────────────────────────────────────────────────

const _degrees = [
  _DegreeOption(
    id: 'cs_se',
    label: 'CS / Software Engineering',
    subtitle: 'BCS, BSCS, BSSE, BSE',
    icon: Icons.code_rounded,
  ),
  _DegreeOption(
    id: 'electrical_mechanical',
    label: 'Electrical / Mechanical Engg',
    subtitle: 'BSEE, BSME, BSCE, BSIE',
    icon: Icons.settings_rounded,
  ),
  _DegreeOption(
    id: 'business',
    label: 'Business & Management',
    subtitle: 'BBA, MBA, BSBA, BS Management',
    icon: Icons.business_center_rounded,
  ),
  _DegreeOption(
    id: 'fintech',
    label: 'FinTech & Finance',
    subtitle: 'BS Finance, BS FinTech, BBA Finance',
    icon: Icons.account_balance_rounded,
  ),
  _DegreeOption(
    id: 'data_ai',
    label: 'Data Science / AI',
    subtitle: 'BSDS, BSAI, BS Data Engineering',
    icon: Icons.auto_awesome_rounded,
  ),
];

final _tests = [
  _TestOption(
    id: 'FAST-NU',
    shortName: 'FAST-NU',
    fullName: 'FAST National University',
    description: 'NU Entry Test for all FAST campuses',
    icon: Icons.computer_rounded,
    accentColor: const Color(0xFF6C63FF),
    weightages: {
      'cs_se': [
        _Subject('Advanced Mathematics', 0.50),
        _Subject('Basic Mathematics', 0.20),
        _Subject('IQ & Analytical', 0.20),
        _Subject('English', 0.10),
      ],
      'electrical_mechanical': [
        _Subject('Advanced Mathematics', 0.50),
        _Subject('Basic Mathematics', 0.20),
        _Subject('IQ & Analytical', 0.20),
        _Subject('English', 0.10),
      ],
      'business': [
        _Subject('Basic Mathematics', 0.50),
        _Subject('Analytical Skills', 0.25),
        _Subject('Essay Writing', 0.15),
        _Subject('English', 0.10),
      ],
      'fintech': [
        _Subject('Basic Mathematics', 0.50),
        _Subject('Analytical Skills', 0.25),
        _Subject('Essay Writing', 0.15),
        _Subject('English', 0.10),
      ],
      'data_ai': [
        _Subject('Advanced Mathematics', 0.50),
        _Subject('Basic Mathematics', 0.20),
        _Subject('IQ & Analytical', 0.20),
        _Subject('English', 0.10),
      ],
    },
  ),
  _TestOption(
    id: 'NUST-NET',
    shortName: 'NUST NET',
    fullName: 'National University of S&T',
    description: 'NET for Engineering, CS & Sciences',
    icon: Icons.science_rounded,
    accentColor: const Color(0xFF00BCD4),
    weightages: {
      'cs_se': [
        _Subject('Mathematics', 0.50),
        _Subject('Physics', 0.30),
        _Subject('English', 0.20),
      ],
      'electrical_mechanical': [
        _Subject('Mathematics', 0.50),
        _Subject('Physics', 0.30),
        _Subject('English', 0.20),
      ],
      'data_ai': [
        _Subject('Mathematics', 0.50),
        _Subject('Physics', 0.30),
        _Subject('English', 0.20),
      ],
      'default': [
        _Subject('Mathematics', 0.50),
        _Subject('Physics', 0.30),
        _Subject('English', 0.20),
      ],
    },
  ),
  _TestOption(
    id: 'NAT-NTS',
    shortName: 'NAT-NTS',
    fullName: 'National Aptitude Test — NTS',
    description: 'General admissions test across Pakistan',
    icon: Icons.school_rounded,
    accentColor: const Color(0xFFFFD700),
    weightages: {
      'cs_se': [
        _Subject('Mathematics', 0.40),
        _Subject('English', 0.30),
        _Subject('Analytical', 0.30),
      ],
      'business': [
        _Subject('English', 0.40),
        _Subject('Analytical', 0.35),
        _Subject('Mathematics', 0.25),
      ],
      'fintech': [
        _Subject('Mathematics', 0.35),
        _Subject('English', 0.35),
        _Subject('Analytical', 0.30),
      ],
      'default': [
        _Subject('English', 0.35),
        _Subject('Mathematics', 0.35),
        _Subject('Analytical', 0.30),
      ],
    },
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class TestSelectionScreen extends StatefulWidget {
  /// Set to true when launched from ProfileScreen to change existing selections.
  /// When false (default) — onboarding flow after signup.
  final bool isEditing;

  /// Pre-populate with user's current selections when [isEditing] is true.
  final List<String> initialTests;
  final String? initialDegree;

  const TestSelectionScreen({
    super.key,
    this.isEditing = false,
    this.initialTests = const [],
    this.initialDegree,
  });

  @override
  State<TestSelectionScreen> createState() => _TestSelectionScreenState();
}

class _TestSelectionScreenState extends State<TestSelectionScreen>
    with TickerProviderStateMixin {
  final Set<String> _selectedTestIds = {};
  String? _selectedDegreeId;
  bool _isSaving = false;

  bool _degreeSheetOpen = false;
  String _degreeSearch = '';
  final _degreeSearchController = TextEditingController();

  late final AnimationController _ustuController;
  late final Animation<double> _ustuBounce;

  late final AnimationController _btnController;
  late final Animation<double> _btnFade;

  late final AnimationController _cardsController;
  late final List<Animation<Offset>> _cardSlides;
  late final List<Animation<double>> _cardFades;

  bool get _canContinue =>
      _selectedTestIds.isNotEmpty && _selectedDegreeId != null;

  @override
  void initState() {
    super.initState();

    _ustuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _ustuBounce = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.22,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.22,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
    ]).animate(_ustuController);

    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _btnFade = CurvedAnimation(parent: _btnController, curve: Curves.easeIn);

    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _cardSlides = List.generate(_tests.length, (i) {
      final start = i * 0.18;
      return Tween<Offset>(
        begin: const Offset(0.0, 0.45),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _cardsController,
          curve: Interval(start, start + 0.55, curve: Curves.easeOutCubic),
        ),
      );
    });
    _cardFades = List.generate(_tests.length, (i) {
      final start = i * 0.18;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _cardsController,
          curve: Interval(start, start + 0.55, curve: Curves.easeOut),
        ),
      );
    });

    _cardsController.forward();

    // always show the button area (just disabled until valid)
    _btnController.forward();

    // ── Pre-populate when editing existing selections ─────────────────────
    if (widget.isEditing) {
      _selectedTestIds.addAll(widget.initialTests);
      _selectedDegreeId = widget.initialDegree;
      // Trigger owl bounce so user sees the pre-filled state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ustuController.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _ustuController.dispose();
    _btnController.dispose();
    _cardsController.dispose();
    _degreeSearchController.dispose();
    super.dispose();
  }

  void _toggleTest(String id) {
    setState(() {
      if (_selectedTestIds.contains(id)) {
        _selectedTestIds.remove(id);
      } else {
        _selectedTestIds.add(id);
      }
    });
    _ustuController.forward(from: 0);
  }

  void _selectDegree(String id) {
    setState(() {
      _selectedDegreeId = id;
      _degreeSheetOpen = false;
      _degreeSearch = '';
      _degreeSearchController.clear();
    });
    _ustuController.forward(from: 0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _continue — handles BOTH onboarding (isEditing=false) and profile edit
  // (isEditing=true). In edit mode: detects no-change, shows warning dialog,
  // clears exam-specific Firestore data, then pops instead of going to /home.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _continue() async {
    if (!_canContinue || _isSaving) return;

    final degreeId = _selectedDegreeId;
    if (degreeId == null || _selectedTestIds.isEmpty) return;

    // ── Edit mode: no-change detection ──────────────────────────────────────
    if (widget.isEditing) {
      final sameTests =
          _selectedTestIds.length == widget.initialTests.length &&
          _selectedTestIds.containsAll(widget.initialTests);
      final sameDegree = _selectedDegreeId == widget.initialDegree;

      if (sameTests && sameDegree) {
        if (!mounted) return;
        Navigator.pop(context, false); // signal: nothing changed
        return;
      }

      // ── Confirm before overwriting ─────────────────────────────────────
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1464),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '⚠️  Confirm Change',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: Text(
            'Changing your exam or degree will reset:\n\n'
            '  • Your weak topic history\n'
            '  • Any incomplete quiz session\n\n'
            'Your streak, accuracy, and total questions solved will stay.',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.78),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Yes, Change',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return; // user cancelled
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // ── Build subject weightages map ─────────────────────────────────
        final Map<String, dynamic> testWeightages = {};
        for (final testId in _selectedTestIds) {
          final test = _tests.firstWhere(
            (t) => t.id == testId,
            orElse: () => _tests.first,
          );
          final subjects = test.subjectsFor(degreeId);
          testWeightages[testId] = subjects
              .map((s) => {'subject': s.name, 'weightage': s.weightage})
              .toList();
        }

        // ── Write new selections ─────────────────────────────────────────
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'selectedTests': _selectedTestIds.toList(),
          'targetDegree': degreeId,
          'testWeightages': testWeightages,
          'testSelectedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // ── Edit mode: clear exam-specific data that is now stale ────────
        // weakTopics and incompleteSession are tied to the old exam/sections.
        // Streak, accuracy, totalSolved etc. are global — leave them alone.
        if (widget.isEditing) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({
                  'weakTopics': FieldValue.delete(),
                  'weakTopicSections': FieldValue.delete(),
                  'weakTopicExam': FieldValue.delete(),
                  'weakTopicSection': FieldValue.delete(),
                  'lastWeakTopicShownDate': FieldValue.delete(),
                  'incompleteSession': FieldValue.delete(),
                });
          } catch (_) {
            // Fields may not exist yet for new users — not an error
          }
        }
      }

      if (!mounted) return;

      if (widget.isEditing) {
        Navigator.pop(context, true); // signal: saved successfully
      } else {
        context.go('/home'); // onboarding flow — navigate to home
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  _DegreeOption? get _selectedDegree => _selectedDegreeId == null
      ? null
      : _degrees.firstWhere((d) => d.id == _selectedDegreeId);

  List<_DegreeOption> get _filteredDegrees => _degreeSearch.isEmpty
      ? _degrees
      : _degrees
            .where(
              (d) =>
                  d.label.toLowerCase().contains(_degreeSearch.toLowerCase()) ||
                  d.subtitle.toLowerCase().contains(
                    _degreeSearch.toLowerCase(),
                  ),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
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

            SafeArea(
              child: Column(
                children: [
                  // ── Back button — only shown when editing from Profile ────
                  if (widget.isEditing)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, top: 8),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: widget.isEditing ? 8 : 28),

                            ScaleTransition(
                              scale: _ustuBounce,
                              child: _UstuOwl(
                                isHappy: _canContinue,
                                hasPartial:
                                    _selectedTestIds.isNotEmpty ||
                                    _selectedDegreeId != null,
                              ),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              widget.isEditing
                                  ? 'Update Your Prep 🎯'
                                  : 'Personalise Your Prep 🎯',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 6),

                            Text(
                              widget.isEditing
                                  ? 'Update your exams and degree.\nWeak topic history will reset on change.'
                                  : 'Select all exams you\'re preparing for.\nUstu will tailor your quizzes accordingly.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.6),
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 28),

                            // ── Degree selector ──────────────────────
                            _SectionLabel(label: 'Target Degree'),
                            const SizedBox(height: 10),
                            _DegreeSelector(
                              selected: _selectedDegree,
                              isOpen: _degreeSheetOpen,
                              searchController: _degreeSearchController,
                              filteredDegrees: _filteredDegrees,
                              onTap: () => setState(
                                () => _degreeSheetOpen = !_degreeSheetOpen,
                              ),
                              onSearchChanged: (v) =>
                                  setState(() => _degreeSearch = v),
                              onSelectDegree: _selectDegree,
                            ),

                            const SizedBox(height: 28),

                            // ── Test cards ───────────────────────────
                            _SectionLabel(
                              label: 'Entry Tests',
                              note: 'Select all that apply',
                            ),
                            const SizedBox(height: 10),

                            ...List.generate(_tests.length, (i) {
                              final test = _tests[i];
                              final isSelected = _selectedTestIds.contains(
                                test.id,
                              );
                              final subjects = test.subjectsFor(
                                _selectedDegreeId,
                              );

                              return SlideTransition(
                                position: _cardSlides[i],
                                child: FadeTransition(
                                  opacity: _cardFades[i],
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _TestCard(
                                      test: test,
                                      isSelected: isSelected,
                                      subjects: subjects,
                                      showWeightages: _selectedDegreeId != null,
                                      onTap: () => _toggleTest(test.id),
                                    ),
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Bottom button area ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: !_canContinue
                              ? Padding(
                                  key: const ValueKey('hint'),
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    _selectedTestIds.isEmpty &&
                                            _selectedDegreeId == null
                                        ? 'Select your degree and at least one exam'
                                        : _selectedDegreeId == null
                                        ? 'Now select your target degree ☝️'
                                        : 'Now pick at least one exam ☝️',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.45),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : const SizedBox(key: ValueKey('empty')),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _canContinue && !_isSaving
                                ? _continue
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF6C63FF),
                              disabledBackgroundColor: Colors.white.withOpacity(
                                0.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF6C63FF),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        widget.isEditing
                                            ? 'Save Changes'
                                            : "Let's Go!",
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        widget.isEditing
                                            ? Icons.check_rounded
                                            : Icons.arrow_forward_rounded,
                                        size: 20,
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

// ─────────────────────────────────────────────────────────────────────────────
// DEGREE SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _DegreeSelector extends StatelessWidget {
  final _DegreeOption? selected;
  final bool isOpen;
  final TextEditingController searchController;
  final List<_DegreeOption> filteredDegrees;
  final VoidCallback onTap;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelectDegree;

  const _DegreeSelector({
    required this.selected,
    required this.isOpen,
    required this.searchController,
    required this.filteredDegrees,
    required this.onTap,
    required this.onSearchChanged,
    required this.onSelectDegree,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Trigger
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(selected != null ? 0.12 : 0.07),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: isOpen ? Radius.zero : const Radius.circular(14),
              ),
              border: Border.all(
                color: selected != null
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white.withOpacity(0.15),
                width: selected != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected?.icon ?? Icons.school_outlined,
                  color: selected != null ? Colors.white : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: selected == null
                      ? Text(
                          'What degree are you aiming for?',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.35),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected!.label,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              selected!.subtitle,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Dropdown
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1340),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    autofocus: isOpen,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search degree...',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                ...filteredDegrees.map(
                  (degree) => InkWell(
                    onTap: () => onSelectDegree(degree.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(degree.icon, color: Colors.white54, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  degree.label,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  degree.subtitle,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.4),
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
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TestCard extends StatelessWidget {
  final _TestOption test;
  final bool isSelected;
  final List<_Subject> subjects;
  final bool showWeightages;
  final VoidCallback onTap;

  const _TestCard({
    required this.test,
    required this.isSelected,
    required this.subjects,
    required this.showWeightages,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? test.accentColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isSelected
                ? test.accentColor
                : Colors.white.withOpacity(0.13),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: test.accentColor.withOpacity(0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? test.accentColor.withOpacity(0.25)
                        : Colors.white.withOpacity(0.07),
                    border: Border.all(
                      color: isSelected
                          ? test.accentColor.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    test.icon,
                    color: isSelected ? test.accentColor : Colors.white38,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.shortName,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        test.fullName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkbox (square for multi-select)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 26,
                  width: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: isSelected ? test.accentColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? test.accentColor
                          : Colors.white.withOpacity(0.25),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              test.description,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),

            // Weightage bars — appear once degree is picked
            if (showWeightages && subjects.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUBJECT WEIGHTAGES FOR YOUR DEGREE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.35),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...subjects.map(
                      (s) => _WeightageRow(
                        subject: s,
                        accentColor: test.accentColor,
                        isCardSelected: isSelected,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEIGHTAGE ROW
// ─────────────────────────────────────────────────────────────────────────────

class _WeightageRow extends StatelessWidget {
  final _Subject subject;
  final Color accentColor;
  final bool isCardSelected;

  const _WeightageRow({
    required this.subject,
    required this.accentColor,
    required this.isCardSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (subject.weightage * 100).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              subject.name,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white.withOpacity(0.75),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: subject.weightage,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(
                  isCardSelected ? accentColor : Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '$pct%',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isCardSelected
                    ? accentColor
                    : Colors.white.withOpacity(0.5),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? note;

  const _SectionLabel({required this.label, this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        if (note != null) ...[
          const Spacer(),
          Text(
            note!,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ],
    );
  }
}

class _UstuOwl extends StatelessWidget {
  final bool isHappy;
  final bool hasPartial;

  const _UstuOwl({required this.isHappy, required this.hasPartial});

  @override
  Widget build(BuildContext context) {
    // Replace with: Lottie.asset('assets/lottie/ustu_owl.json', height: 100, width: 100)
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.07),
        border: Border.all(
          color: isHappy
              ? Colors.white.withOpacity(0.45)
              : hasPartial
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.12),
          width: isHappy ? 2.5 : 1.5,
        ),
        boxShadow: isHappy
            ? [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.45),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ]
            : [],
      ),
      child: Center(
        child: Text(
          isHappy ? '🦉✨' : '🦉',
          style: const TextStyle(fontSize: 46),
        ),
      ),
    );
  }
}
