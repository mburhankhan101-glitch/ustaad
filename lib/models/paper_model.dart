// lib/models/paper_model.dart

enum ExamType { fastNU, nustNET, nts, mdcat, numsMdcat }

// ─── Sub‑source for composite sections ───────────────────────────────────────

class SectionSource {
  final String firestoreExam;
  final String firestoreSection;
  final String? additionalSection;
  final int count; // questions to pull from this source

  const SectionSource({
    required this.firestoreExam,
    required this.firestoreSection,
    this.additionalSection,
    required this.count,
  });
}

// ─── SectionConfig ───────────────────────────────────────────────────────────

class SectionConfig {
  final String id;
  final String label;

  // For simple sections
  final String firestoreExam;
  final String firestoreSection;
  final String? additionalSection;

  // For composite sections (NUST maths = 70 AdvMaths + 30 Quantitative)
  final List<SectionSource>? subSections;

  final int totalQuestions;
  final int totalMinutes; // 0 = no per‑section timer
  final double markCorrect;
  final double markWrong;
  final String progressExam;

  const SectionConfig({
    required this.id,
    required this.label,
    this.firestoreExam = '',
    this.firestoreSection = '',
    this.additionalSection,
    this.subSections,
    required this.totalQuestions,
    required this.totalMinutes,
    required this.markCorrect,
    required this.markWrong,
    String? progressExam,
  }) : progressExam = progressExam ?? firestoreExam;
}

// ─── Exam‑specific configs ───────────────────────────────────────────────────

class PaperConfigs {
  // FAST‑NU
  static const List<SectionConfig> fastCS = [
    SectionConfig(
      id: 'advancedMaths',
      label: 'Advanced Maths',
      firestoreExam: 'FAST-NU',
      firestoreSection: 'Advanced Maths',
      totalQuestions: 50,
      totalMinutes: 50,
      markCorrect: 1.0,
      markWrong: -0.25,
    ),
    SectionConfig(
      id: 'basicMaths',
      label: 'Basic Maths',
      firestoreExam: 'NTS',
      firestoreSection: 'Quantitative',
      totalQuestions: 20,
      totalMinutes: 20,
      markCorrect: 1.0,
      markWrong: -0.25,
      progressExam: 'FAST-NU',
    ),
    SectionConfig(
      id: 'analytical',
      label: 'Analytical & IQ',
      firestoreExam: 'NTS',
      firestoreSection: 'Analytical',
      totalQuestions: 20,
      totalMinutes: 20,
      markCorrect: 1.0,
      markWrong: -0.25,
      progressExam: 'FAST-NU',
    ),
    SectionConfig(
      id: 'english',
      label: 'English',
      firestoreExam: 'FAST-NU',
      firestoreSection: 'English',
      totalQuestions: 30,
      totalMinutes: 30,
      markCorrect: 0.344,
      markWrong: -0.0844,
    ),
  ];

  // NUST‑NET – UPDATED Mathematics section with corrected Firestore exam tags
  static const List<SectionConfig> nustEngineering = [
    SectionConfig(
      id: 'maths',
      label: 'Mathematics',
      totalQuestions: 100,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
      progressExam: 'NUST-NET',
      subSections: const [
        // Advanced Maths questions live under exam 'FAST-NU' in your Firestore
        SectionSource(
          firestoreExam: 'FAST-NU',
          firestoreSection: 'Advanced Maths',
          count: 70,
        ),
        // Quantitative questions live under 'NTS'
        SectionSource(
          firestoreExam: 'NTS',
          firestoreSection: 'Quantitative',
          count: 30,
        ),
      ],
    ),
    SectionConfig(
      id: 'physics',
      label: 'Physics',
      firestoreExam: 'NUST-NET',
      firestoreSection: 'Physics',
      totalQuestions: 60,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
    SectionConfig(
      id: 'english',
      label: 'English',
      firestoreExam: 'NUST-NET',
      firestoreSection: 'English',
      totalQuestions: 40,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
  ];

  // NTS
  static const List<SectionConfig> ntsCS = [
    SectionConfig(
      id: 'english',
      label: 'English',
      firestoreExam: 'NTS',
      firestoreSection: 'English',
      totalQuestions: 20,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
    SectionConfig(
      id: 'analytical',
      label: 'Analytical',
      firestoreExam: 'NTS',
      firestoreSection: 'Analytical',
      totalQuestions: 20,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
    SectionConfig(
      id: 'quantitative',
      label: 'Quantitative',
      firestoreExam: 'NTS',
      firestoreSection: 'Quantitative',
      totalQuestions: 20,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
    SectionConfig(
      id: 'computerScience',
      label: 'Computer Science',
      firestoreExam: 'NTS',
      firestoreSection: 'Computer Science',
      totalQuestions: 30,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
  ];

  // MDCAT — 180 MCQs, 180min, no negative marking.
  // Biology/Chemistry/Physics are the SHARED medical content pool — the same
  // questions also serve NUMS (see numsMedical below, which queries this same
  // 'MDCAT' tag). Logical Reasoning is MDCAT-only (NUMS has no such section).
  // Tag new questions exams: ["MDCAT", "NUMS"] for Bio/Chem/Physics so
  // they're discoverable either way; exams: ["MDCAT"] only for Logical Reasoning.
  // English is pooled from your existing NTS bank (not shared with NUMS —
  // see numsMedical, which pools English separately since the count differs
  // and there's no dedicated medical-English content yet either way).
  static const List<SectionConfig> mdcatMedical = [
    SectionConfig(
      id: 'biology',
      label: 'Biology',
      firestoreExam: 'MDCAT',
      firestoreSection: 'Biology',
      totalQuestions: 81,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
    SectionConfig(
      id: 'chemistry',
      label: 'Chemistry',
      firestoreExam: 'MDCAT',
      firestoreSection: 'Chemistry',
      totalQuestions: 45,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
    SectionConfig(
      id: 'physics',
      label: 'Physics',
      // Dedicated medical-Physics content (shared with NUMS), not pooled
      // from NUST-NET — that's maths-intensive engineering Physics, wrong
      // difficulty/scope for FSc pre-medical MDCAT/NUMS Physics.
      firestoreExam: 'MDCAT',
      firestoreSection: 'Physics',
      totalQuestions: 36,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
    SectionConfig(
      id: 'english',
      label: 'English',
      totalQuestions: 9,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
      progressExam: 'MDCAT',
      subSections: const [
        // NTS English is the closest match in style (grammar/vocab-focused,
        // not essay-heavy like FAST-NU's), so pool from there.
        SectionSource(
          firestoreExam: 'NTS',
          firestoreSection: 'English',
          count: 9,
        ),
      ],
    ),
    SectionConfig(
      id: 'logicalReasoning',
      label: 'Logical Reasoning',
      firestoreExam: 'MDCAT',
      firestoreSection: 'Logical Reasoning',
      totalQuestions: 9,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
    ),
  ];

  // NUMS Paper-I — 150 MCQs, 165min (2h45m), no negative marking.
  // Confirmed against official NUMS syllabus table: Biology 55 (37%),
  // Chemistry 40 (26.5%), Physics 40 (26.5%), English 15 (10%).
  // Biology/Chemistry/Physics deliberately query firestoreExam: 'MDCAT' —
  // NOT 'NUMS' — because this is the SAME shared medical content pool as
  // mdcatMedical above (per Burhan: same syllabus, same questions, just
  // different counts pulled). progressExam: 'NUMS' keeps weak-topics and
  // the progress screen correctly labeled under NUMS even though the
  // Firestore query itself hits the MDCAT-tagged pool.
  // Paper-II (50 psychological-assessment MCQs, 15min, 5% weight) is NOT
  // modeled here — it's not academic content, needs a separate content
  // source/decision, deliberately left out given the timeline.
  static const List<SectionConfig> numsMedical = [
    SectionConfig(
      id: 'biology',
      label: 'Biology',
      firestoreExam: 'MDCAT',
      firestoreSection: 'Biology',
      totalQuestions: 55,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
      progressExam: 'NUMS',
    ),
    SectionConfig(
      id: 'chemistry',
      label: 'Chemistry',
      firestoreExam: 'MDCAT',
      firestoreSection: 'Chemistry',
      totalQuestions: 40,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
      progressExam: 'NUMS',
    ),
    SectionConfig(
      id: 'physics',
      label: 'Physics',
      firestoreExam: 'MDCAT',
      firestoreSection: 'Physics',
      totalQuestions: 40,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
      progressExam: 'NUMS',
    ),
    SectionConfig(
      id: 'english',
      label: 'English',
      totalQuestions: 15,
      totalMinutes: 0,
      markCorrect: 1.0,
      markWrong: 0.0,
      progressExam: 'NUMS',
      subSections: const [
        SectionSource(
          firestoreExam: 'NTS',
          firestoreSection: 'English',
          count: 15,
        ),
      ],
    ),
  ];

  static List<SectionConfig> forExamType(ExamType type) {
    switch (type) {
      case ExamType.fastNU:
        return fastCS;
      case ExamType.nustNET:
        return nustEngineering;
      case ExamType.nts:
        return ntsCS;
      case ExamType.mdcat:
        return mdcatMedical;
      case ExamType.numsMdcat:
        return numsMedical;
    }
  }

  static int totalMinutes(ExamType type) {
    switch (type) {
      case ExamType.fastNU:
        return 120;
      case ExamType.nustNET:
        return 180;
      case ExamType.nts:
        return 100;
      case ExamType.mdcat:
        return 180;
      case ExamType.numsMdcat:
        return 165;
    }
  }

  static double maxMarks(ExamType type) {
    switch (type) {
      case ExamType.fastNU:
        return 100.0;
      case ExamType.nustNET:
        return 200.0;
      case ExamType.nts:
        return 100.0;
      case ExamType.mdcat:
        return 180.0;
      case ExamType.numsMdcat:
        return 150.0;
    }
  }

  static String examLabel(ExamType type) {
    switch (type) {
      case ExamType.fastNU:
        return 'FAST-NU';
      case ExamType.nustNET:
        return 'NUST-NET';
      case ExamType.nts:
        return 'NTS';
      case ExamType.mdcat:
        return 'MDCAT';
      case ExamType.numsMdcat:
        return 'NUMS MDCAT';
    }
  }
}

// ─── Answer tracking ──────────────────────────────────────────────────────────

class QuestionAnswer {
  final String questionId;
  final int? selectedIndex;
  final bool isConfirmed;

  const QuestionAnswer({
    required this.questionId,
    this.selectedIndex,
    this.isConfirmed = false,
  });

  QuestionAnswer copyWith({int? selectedIndex, bool? isConfirmed}) {
    return QuestionAnswer(
      questionId: questionId,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}

// ─── Results ──────────────────────────────────────────────────────────────────

class SectionResult {
  final SectionConfig config;
  final int correct;
  final int wrong;
  final int skipped;
  final double marksEarned;
  final double penaltyMarks;

  const SectionResult({
    required this.config,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.marksEarned,
    required this.penaltyMarks,
  });

  double get netMarks => marksEarned + penaltyMarks;
}

class PaperResult {
  final ExamType examType;
  final String examLabel;
  final List<SectionResult> sectionResults;
  final DateTime completedAt;
  final int secondsTaken;

  const PaperResult({
    required this.examType,
    required this.examLabel,
    required this.sectionResults,
    required this.completedAt,
    required this.secondsTaken,
  });

  double get totalEarned =>
      sectionResults.fold(0.0, (s, r) => s + r.marksEarned);
  double get totalPenalty =>
      sectionResults.fold(0.0, (s, r) => s + r.penaltyMarks);
  double get netScore => totalEarned + totalPenalty;

  int get totalCorrect => sectionResults.fold(0, (s, r) => s + r.correct);
  int get totalWrong => sectionResults.fold(0, (s, r) => s + r.wrong);
  int get totalSkipped => sectionResults.fold(0, (s, r) => s + r.skipped);

  double get accuracyPercent {
    final attempted = totalCorrect + totalWrong;
    if (attempted == 0) return 0;
    return (totalCorrect / attempted) * 100;
  }
}
