import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaad/core/analytics/analytics_service.dart';
import 'package:ustaad/core/notifications/push_service.dart';

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
  final _Stream stream;

  const _DegreeOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.stream,
  });
}

class _TestOption {
  final String id;
  final String shortName;
  final String fullName;
  final String description;
  final IconData icon;
  final Color accentColor;
  final _Stream stream;
  final Map<String, List<_Subject>> weightages;

  const _TestOption({
    required this.id,
    required this.shortName,
    required this.fullName,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.stream,
    required this.weightages,
  });

  List<_Subject> subjectsFor(String? degreeId) =>
      weightages[degreeId] ?? weightages['default'] ?? [];
}

// ─────────────────────────────────────────────────────────────────────────────
// STATIC DATA
// ─────────────────────────────────────────────────────────────────────────────

/// A degree and a test each belong to one stream. A medical degree can only sit
/// with medical tests, and vice versa — before this existed the screen happily
/// let someone pair CS with MDCAT.
enum _Stream { engineering, medical }

const _degrees = [
  _DegreeOption(
    id: 'cs_se',
    label: 'CS / Software Engineering',
    subtitle: 'BCS, BSCS, BSSE, BSE',
    icon: Icons.code_rounded,
    stream: _Stream.engineering,
  ),
  _DegreeOption(
    id: 'electrical_mechanical',
    label: 'Electrical / Mechanical Engg',
    subtitle: 'BSEE, BSME, BSCE, BSIE',
    icon: Icons.settings_rounded,
    stream: _Stream.engineering,
  ),
  _DegreeOption(
    id: 'business',
    label: 'Business & Management',
    subtitle: 'BBA, MBA, BSBA, BS Management',
    icon: Icons.business_center_rounded,
    stream: _Stream.engineering,
  ),
  _DegreeOption(
    id: 'fintech',
    label: 'FinTech & Finance',
    subtitle: 'BS Finance, BS FinTech, BBA Finance',
    icon: Icons.account_balance_rounded,
    stream: _Stream.engineering,
  ),
  _DegreeOption(
    id: 'data_ai',
    label: 'Data Science / AI',
    subtitle: 'BSDS, BSAI, BS Data Engineering',
    icon: Icons.auto_awesome_rounded,
    stream: _Stream.engineering,
  ),
  _DegreeOption(
    id: 'architecture',
    label: 'Architecture / Industrial Design',
    subtitle: 'B.Arch, B.Industrial Design',
    icon: Icons.architecture_rounded,
    stream: _Stream.engineering,
  ),
  _DegreeOption(
    id: 'applied_sciences',
    label: 'Applied Sciences',
    subtitle: 'BS Physics, Chemistry, Biosciences',
    icon: Icons.science_rounded,
    stream: _Stream.engineering,
  ),
  _DegreeOption(
    id: 'medical',
    label: 'MBBS / BDS (Medical)',
    subtitle: 'Doctor of Medicine, Dental Surgery',
    icon: Icons.medical_services_rounded,
    stream: _Stream.medical,
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
    stream: _Stream.engineering,
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
    stream: _Stream.engineering,
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
      'business': [
        _Subject('Quantitative Mathematics', 0.50),
        _Subject('English', 0.50),
      ],
      'fintech': [
        _Subject('Quantitative Mathematics', 0.50),
        _Subject('English', 0.50),
      ],
      'architecture': [
        _Subject('Design Aptitude', 0.50),
        _Subject('Mathematics', 0.30),
        _Subject('English', 0.20),
      ],
      'applied_sciences': [
        _Subject('Biology', 0.50),
        _Subject('Chemistry', 0.30),
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
    stream: _Stream.engineering,
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
  _TestOption(
    id: 'MDCAT',
    shortName: 'MDCAT',
    fullName: 'Medical & Dental College Admissions Test',
    description: 'PMC national entry test for MBBS & BDS admissions',
    icon: Icons.medical_services_rounded,
    accentColor: const Color(0xFF4CAF50),
    stream: _Stream.medical,
    weightages: {
      'default': [
        _Subject('Biology', 0.45),
        _Subject('Chemistry', 0.25),
        _Subject('Physics', 0.20),
        _Subject('English', 0.05),
        _Subject('Logical Reasoning', 0.05),
      ],
      'medical': [
        _Subject('Biology', 0.45),
        _Subject('Chemistry', 0.25),
        _Subject('Physics', 0.20),
        _Subject('English', 0.05),
        _Subject('Logical Reasoning', 0.05),
      ],
    },
  ),
  _TestOption(
    id: 'NUMS',
    shortName: 'NUMS',
    fullName: 'National University of Medical Sciences',
    description: 'NUMS entry test for MBBS & BDS admissions (Paper-I)',
    icon: Icons.local_hospital_rounded,
    accentColor: const Color(0xFF2196F3),
    stream: _Stream.medical,
    weightages: {
      'default': [
        _Subject('Biology', 0.37),
        _Subject('Chemistry', 0.265),
        _Subject('Physics', 0.265),
        _Subject('English', 0.10),
      ],
      'medical': [
        _Subject('Biology', 0.37),
        _Subject('Chemistry', 0.265),
        _Subject('Physics', 0.265),
        _Subject('English', 0.10),
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

class _TestSelectionScreenState extends State<TestSelectionScreen> {
  final Set<String> _selectedTestIds = {};
  String? _selectedDegreeId;
  bool _isSaving = false;





  bool get _canContinue =>
      _selectedTestIds.isNotEmpty && _selectedDegreeId != null;

  @override
  void initState() {
    super.initState();
    // Profile opens this screen to change an existing choice, so it starts
    // on what the student already picked rather than blank.
    if (widget.isEditing) {
      _selectedTestIds.addAll(widget.initialTests);
      _selectedDegreeId = widget.initialDegree;
    }
  }

  @override
  void dispose() {
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
  }

  void _selectDegree(String id) {
    setState(() {
      _selectedDegreeId = id;

      // Switching stream invalidates anything ticked in the other one. Without
      // this, picking NET first and then a medical degree would leave NET
      // quietly selected and saved against an MBBS profile.
      final stream = _degrees.firstWhere((d) => d.id == id).stream;
      _selectedTestIds.removeWhere(
        (testId) => _tests.firstWhere((t) => t.id == testId).stream != stream,
      );
    });
  }

  /// Sections are derived from the data rather than listed by hand, so a
  /// test added to the list appears without anyone remembering to render it.
  List<_TestOption> _testsIn(_Stream stream) =>
      _tests.where((t) => t.stream == stream).toList();

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

        // Exam choice is the only segmentation worth having here: NET students
        // and NTS students behave nothing alike, and every later report reads
        // through it. Topics are what keep a broadcast on the students it
        // applies to — an MDCAT announcement sent to every install is how
        // people uninstall.
        final exams = _selectedTestIds.toList();
        Analytics.instance.examsSelected(exams);
        Analytics.instance.setSelectedExams(exams);
        PushService.instance.syncTopics(exams);

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


  @override
  // ───────────────────────────────────────────────────────────────────────
  // UI
  //
  // Rebuilt to be a page a student reads once and answers. What was here
  // before had an animated owl, decorative circles, per-card icons and
  // accent colours, bordered cards sliding in on a stagger, a searchable
  // bottom sheet for degrees, and weightages as coloured pills. All of it
  // was decoration around two questions, and it made a two-question page
  // feel like a product tour.
  //
  // What remains: the gradient, two lists, and a button. The weightages
  // stay because they are the reason a student can choose confidently
  // rather than guess — as small grey text, which is what they are.
  //
  // None of the logic below the fold changed: the same selections, the same
  // stream rule, the same save, the same edit mode from the profile.
  // ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final degree = _selectedDegree;

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
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  children: [
                    if (widget.isEditing)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Icon(Icons.arrow_back,
                                color: Colors.white70, size: 22),
                          ),
                        ),
                      ),
                    Text(
                      widget.isEditing
                          ? 'Change your test'
                          : 'What are you preparing for?',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 28),

                    _heading('Degree'),
                    for (final d in _degrees) _degreeRow(d),

                    if (degree != null) ...[
                      const SizedBox(height: 28),
                      _heading('Tests'),
                      for (final t in _testsIn(degree.stream)) _testRow(t),
                    ],
                  ],
                ),
              ),
              _continueBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.5),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _degreeRow(_DegreeOption d) {
    final on = _selectedDegreeId == d.id;
    return _row(
      selected: on,
      onTap: () => _selectDegree(d.id),
      title: d.label,
      subtitle: d.subtitle,
    );
  }

  Widget _testRow(_TestOption t) {
    final on = _selectedTestIds.contains(t.id);
    final subjects = t.subjectsFor(_selectedDegreeId);
    // "Maths 50 · Physics 30 · English 20" — the split, in the order the
    // paper weights it, without a pill or a bar chart in sight.
    final weights = subjects
        .map((s) => '${s.name} ${(s.weightage * 100).round()}')
        .join('  ·  ');
    return _row(
      selected: on,
      onTap: () => _toggleTest(t.id),
      title: t.fullName,
      subtitle: weights.isEmpty ? t.shortName : weights,
    );
  }

  /// One row, used for both lists. A tick on the right and brighter text is
  /// the whole selected state — no border, no fill, no card.
  Widget _row({
    required bool selected,
    required VoidCallback onTap,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(selected ? 1 : 0.86),
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 21,
              color: selected
                  ? Colors.white
                  : Colors.white.withOpacity(0.25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _continueBar() {
    final ready = _canContinue && !_isSaving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: ready ? _continue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withOpacity(0.18),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1A1464),
                  ),
                )
              : Text(
                  widget.isEditing ? 'Save' : 'Continue',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: ready
                        ? const Color(0xFF1A1464)
                        : Colors.white.withOpacity(0.55),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
