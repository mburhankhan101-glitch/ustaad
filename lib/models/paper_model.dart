// lib/models/paper_model.dart

enum ExamType { fastNU, nustNET, nts }

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

  static List<SectionConfig> forExamType(ExamType type) {
    switch (type) {
      case ExamType.fastNU:
        return fastCS;
      case ExamType.nustNET:
        return nustEngineering;
      case ExamType.nts:
        return ntsCS;
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
