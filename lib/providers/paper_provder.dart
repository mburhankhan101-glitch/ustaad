// lib/providers/paper_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question_model.dart';
import '../models/paper_model.dart';
import '../services/firestore_service.dart';

final _firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

// ─── Loaded section ───────────────────────────────────────────────────────────

class LoadedSection {
  final SectionConfig config;
  final List<Question> questions; // shuffled, length == config.totalQuestions

  const LoadedSection({required this.config, required this.questions});
}

// ─── Session state ────────────────────────────────────────────────────────────

class PaperSessionState {
  final ExamType examType;
  final List<LoadedSection> sections;
  final Map<String, QuestionAnswer> answers;
  final int currentSectionIndex;
  final int currentQuestionIndex;
  final bool isSubmitted;

  final int globalSecondsLeft;
  final Map<String, int> sectionSecondsLeft;

  const PaperSessionState({
    required this.examType,
    required this.sections,
    required this.answers,
    required this.currentSectionIndex,
    required this.currentQuestionIndex,
    required this.isSubmitted,
    required this.globalSecondsLeft,
    required this.sectionSecondsLeft,
  });

  LoadedSection get currentSection => sections[currentSectionIndex];
  Question get currentQuestion =>
      currentSection.questions[currentQuestionIndex];

  QuestionAnswer? answerFor(String id) => answers[id];
  bool get isCurrentAnswered =>
      answers[currentQuestion.id]?.selectedIndex != null;
  bool get isCurrentConfirmed =>
      answers[currentQuestion.id]?.isConfirmed == true;

  int answeredInSection(int sectionIdx) {
    final qs = sections[sectionIdx].questions;
    return qs.where((q) => answers[q.id]?.selectedIndex != null).length;
  }

  PaperSessionState copyWith({
    Map<String, QuestionAnswer>? answers,
    int? currentSectionIndex,
    int? currentQuestionIndex,
    bool? isSubmitted,
    int? globalSecondsLeft,
    Map<String, int>? sectionSecondsLeft,
  }) {
    return PaperSessionState(
      examType: examType,
      sections: sections,
      answers: answers ?? this.answers,
      currentSectionIndex: currentSectionIndex ?? this.currentSectionIndex,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      globalSecondsLeft: globalSecondsLeft ?? this.globalSecondsLeft,
      sectionSecondsLeft: sectionSecondsLeft ?? this.sectionSecondsLeft,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class PaperSessionNotifier
    extends StateNotifier<AsyncValue<PaperSessionState?>> {
  final FirestoreService _service;
  Timer? _timer;
  PaperResult? _lastResult;

  PaperSessionNotifier(this._service) : super(const AsyncValue.data(null));

  // ── Start a paper ─────────────────────────────────────────────────────────

  Future<void> startPaper(ExamType examType, {required String uid}) async {
    state = const AsyncValue.loading();

    try {
      final configs = PaperConfigs.forExamType(examType);
      final sessionExcludeIds = <String>{};
      final loadedSections = <LoadedSection>[];

      for (final cfg in configs) {
        List<Question> questions;

        if (cfg.subSections != null && cfg.subSections!.isNotEmpty) {
          // Composite section — fetch each sub‑source with its exact count
          final allQuestions = <Question>[];
          for (final source in cfg.subSections!) {
            final batch = await _service.fetchQuestions(
              exam: source.firestoreExam,
              section: source.firestoreSection,
              additionalSection: source.additionalSection,
              limit: source.count,
              uid: uid,
              sessionExcludeIds: sessionExcludeIds,
            );
            print(
              '   📦 Composite fetch: ${source.firestoreSection} '
              '→ got ${batch.length} / ${source.count}',
            );
            sessionExcludeIds.addAll(batch.map((q) => q.id));
            allQuestions.addAll(batch);
          }

          // Validate that we got enough questions
          final totalFetched = allQuestions.length;
          if (totalFetched < cfg.totalQuestions) {
            throw Exception(
              'Not enough questions for "${cfg.label}". '
              'Check your Firestore data and sub‑sections mapping.\n'
              'Expected: ${cfg.totalQuestions}, got: $totalFetched',
            );
          }

          allQuestions.shuffle();
          questions = allQuestions;
        } else {
          // Simple single‑source section
          questions = await _service.fetchQuestions(
            exam: cfg.firestoreExam,
            section: cfg.firestoreSection,
            additionalSection: cfg.additionalSection,
            limit: cfg.totalQuestions,
            uid: uid,
            sessionExcludeIds: sessionExcludeIds,
          );
          sessionExcludeIds.addAll(questions.map((q) => q.id));
        }

        if (questions.isEmpty) {
          print(
            'USTAAD WARNING: Section "${cfg.label}" skipped '
            '(0 questions in Firestore).',
          );
          continue;
        }

        loadedSections.add(LoadedSection(config: cfg, questions: questions));
      }

      if (loadedSections.isEmpty) {
        state = AsyncValue.error(
          'No questions found in Firestore.\n\n'
          'Check:\n'
          '1. "exam" and "section" field values match exactly.\n'
          '2. Composite index on exam + section exists in Firebase Console.\n'
          '3. Firestore security rules allow reads.',
          StackTrace.current,
        );
        return;
      }

      // FAST: randomise section order
      if (examType == ExamType.fastNU) {
        loadedSections.shuffle();
      }

      final sectionSeconds = {
        for (final s in loadedSections) s.config.id: s.config.totalMinutes * 60,
      };

      final session = PaperSessionState(
        examType: examType,
        sections: loadedSections,
        answers: {},
        currentSectionIndex: 0,
        currentQuestionIndex: 0,
        isSubmitted: false,
        globalSecondsLeft: PaperConfigs.totalMinutes(examType) * 60,
        sectionSecondsLeft: sectionSeconds,
      );

      state = AsyncValue.data(session);
      _startTimer(examType);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer(ExamType type) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state.value;
      if (current == null || current.isSubmitted) {
        _timer?.cancel();
        return;
      }
      if (current.sections.isEmpty) return;

      if (type == ExamType.nustNET || type == ExamType.nts) {
        final rem = current.globalSecondsLeft - 1;
        if (rem <= 0) {
          submitPaper();
          return;
        }
        state = AsyncValue.data(current.copyWith(globalSecondsLeft: rem));
      } else {
        final sectionId = current.currentSection.config.id;
        final rem = (current.sectionSecondsLeft[sectionId] ?? 0) - 1;
        if (rem <= 0) {
          _autoAdvanceOrSubmit(current);
          return;
        }
        final updated = Map<String, int>.from(current.sectionSecondsLeft);
        updated[sectionId] = rem;
        state = AsyncValue.data(current.copyWith(sectionSecondsLeft: updated));
      }
    });
  }

  void _autoAdvanceOrSubmit(PaperSessionState current) {
    final next = current.currentSectionIndex + 1;
    if (next >= current.sections.length) {
      submitPaper();
    } else {
      state = AsyncValue.data(
        current.copyWith(currentSectionIndex: next, currentQuestionIndex: 0),
      );
    }
  }

  // ── Answer selection ──────────────────────────────────────────────────────

  void selectOption(int optionIndex) {
    final current = state.value;
    if (current == null || current.isSubmitted) return;
    final qId = current.currentQuestion.id;
    if (current.answers[qId]?.isConfirmed == true) return;
    final updated = Map<String, QuestionAnswer>.from(current.answers);
    updated[qId] = QuestionAnswer(questionId: qId, selectedIndex: optionIndex);
    state = AsyncValue.data(current.copyWith(answers: updated));
  }

  void selectOptionById(String questionId, int optionIndex) {
    final current = state.value;
    if (current == null || current.isSubmitted) return;
    final updated = Map<String, QuestionAnswer>.from(current.answers);
    updated[questionId] = QuestionAnswer(
      questionId: questionId,
      selectedIndex: optionIndex,
    );
    state = AsyncValue.data(current.copyWith(answers: updated));
  }

  void confirmAnswer() {
    final current = state.value;
    if (current == null || current.isSubmitted) return;
    final qId = current.currentQuestion.id;
    final existing = current.answers[qId];
    if (existing?.selectedIndex == null) return;
    final updated = Map<String, QuestionAnswer>.from(current.answers);
    updated[qId] = existing!.copyWith(isConfirmed: true);
    state = AsyncValue.data(current.copyWith(answers: updated));
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void nextQuestion() {
    final current = state.value;
    if (current == null) return;
    final max = current.currentSection.questions.length - 1;
    if (current.currentQuestionIndex < max) {
      state = AsyncValue.data(
        current.copyWith(
          currentQuestionIndex: current.currentQuestionIndex + 1,
        ),
      );
    }
  }

  void previousQuestion() {
    final current = state.value;
    if (current == null) return;
    if (current.currentQuestionIndex > 0) {
      state = AsyncValue.data(
        current.copyWith(
          currentQuestionIndex: current.currentQuestionIndex - 1,
        ),
      );
    }
  }

  void switchToSection(int sectionIndex) {
    final current = state.value;
    if (current == null || current.isSubmitted) return;
    if (current.examType != ExamType.nustNET) return;
    state = AsyncValue.data(
      current.copyWith(
        currentSectionIndex: sectionIndex,
        currentQuestionIndex: 0,
      ),
    );
  }

  void advanceToNextSection() {
    final current = state.value;
    if (current == null || current.isSubmitted) return;
    final next = current.currentSectionIndex + 1;
    if (next < current.sections.length) {
      state = AsyncValue.data(
        current.copyWith(currentSectionIndex: next, currentQuestionIndex: 0),
      );
    } else {
      submitPaper();
    }
  }

  void jumpToPage(int pageIndex, int questionsPerPage) {
    final current = state.value;
    if (current == null || current.isSubmitted) return;
    final qIndex = pageIndex * questionsPerPage;
    final max = current.currentSection.questions.length - 1;
    if (qIndex <= max) {
      state = AsyncValue.data(current.copyWith(currentQuestionIndex: qIndex));
    }
  }

  // ── Submit & compute results ───────────────────────────────────────────────

  PaperResult submitPaper() {
    _timer?.cancel();
    final current = state.value!;

    final secondsUsed =
        PaperConfigs.totalMinutes(current.examType) * 60 -
        current.globalSecondsLeft;

    final sectionResults = current.sections.map((ls) {
      int correct = 0, wrong = 0, skipped = 0;
      double earned = 0, penalty = 0;

      for (final q in ls.questions) {
        final ans = current.answers[q.id];
        if (ans?.selectedIndex == null) {
          skipped++;
        } else if (ans!.selectedIndex == q.correctIndex) {
          correct++;
          earned += ls.config.markCorrect;
        } else {
          wrong++;
          penalty += ls.config.markWrong;
        }
      }

      return SectionResult(
        config: ls.config,
        correct: correct,
        wrong: wrong,
        skipped: skipped,
        marksEarned: earned,
        penaltyMarks: penalty,
      );
    }).toList();

    state = AsyncValue.data(current.copyWith(isSubmitted: true));

    _lastResult = PaperResult(
      examType: current.examType,
      examLabel: PaperConfigs.examLabel(current.examType),
      sectionResults: sectionResults,
      completedAt: DateTime.now(),
      secondsTaken: secondsUsed,
    );

    return _lastResult!;
  }

  PaperResult? buildResult() => _lastResult;

  void reset() {
    _timer?.cancel();
    _lastResult = null;
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final paperSessionProvider =
    StateNotifierProvider<PaperSessionNotifier, AsyncValue<PaperSessionState?>>(
      (ref) => PaperSessionNotifier(ref.read(_firestoreServiceProvider)),
    );
