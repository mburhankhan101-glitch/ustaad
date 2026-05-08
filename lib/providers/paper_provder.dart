// lib/providers/paper_provider.dart
//
// Uses your existing FirestoreService.fetchQuestions() — no changes needed
// to your firestore_service.dart. This provider manages the full exam session.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question_model.dart';
import '../models/paper_model.dart';
import '../services/firestore_service.dart';

// Re-use your existing service (if you already have a provider for it, use that)
final _firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

// ─── Loaded section: config + its questions ───────────────────────────────────

class LoadedSection {
  final SectionConfig config;
  final List<Question> questions; // shuffled, length == config.totalQuestions

  const LoadedSection({required this.config, required this.questions});
}

// ─── Full session state ───────────────────────────────────────────────────────

class PaperSessionState {
  final ExamType examType;
  final List<LoadedSection> sections; // randomised order for FAST
  final Map<String, QuestionAnswer> answers; // key: question.id
  final int currentSectionIndex;
  final int currentQuestionIndex;
  final bool isSubmitted;

  // FAST & NTS: per-section seconds remaining
  // NUST: only globalSecondsLeft is used
  final int globalSecondsLeft;
  final Map<String, int> sectionSecondsLeft; // key: SectionConfig.id

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

  // How many questions answered in a given section (for NUST tab badge)
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

  PaperResult? _lastResult; // cached so ref.listen can read it after submit

  PaperSessionNotifier(this._service) : super(const AsyncValue.data(null));

  // ── Start a paper ─────────────────────────────────────────────────────────
  // Fetches all sections from Firestore using your existing fetchQuestions(),
  // then builds the session.

  Future<void> startPaper(ExamType examType) async {
    state = const AsyncValue.loading();

    try {
      final configs = PaperConfigs.forExamType(examType);

      // IMPORTANT: .toList() converts the lazy Iterable to a real List
      // before passing to Future.wait — without this the shuffle crashes
      // with RangeError because the result is a fixed-length list.
      final futures = configs.map((cfg) async {
        final questions = await _service.fetchQuestions(
          exam: cfg.firestoreExam,
          section: cfg.firestoreSection,
          limit: cfg.totalQuestions,
        );
        return LoadedSection(config: cfg, questions: questions);
      }).toList(); // ← critical .toList() here

      // Collect results into a growable list so shuffle works
      final loadedSections = List<LoadedSection>.from(
        await Future.wait(futures),
      );

      // Drop sections that have 0 questions (not uploaded yet).
      // Lets you test with partial data without crashing the whole paper.
      loadedSections.removeWhere((ls) {
        if (ls.questions.isEmpty) {
          print(
            'USTAAD WARNING: Section "\${ls.config.label}" skipped '
            '(0 questions in Firestore). Upload them and restart.',
          );
          return true;
        }
        return false;
      });

      // Fail only if every section is empty
      if (loadedSections.isEmpty) {
        state = AsyncValue.error(
          'No questions found in Firestore.\n\n'
          'Check:\n'
          '1. "exam" and "section" field values match exactly (case-sensitive).\n'
          '2. Composite index on exam + section exists in Firebase Console.\n'
          '3. Firestore security rules allow reads for logged-in users.',
          StackTrace.current,
        );
        return;
      }

      // FAST: randomise section order. NUST and NTS keep fixed order.
      if (examType == ExamType.fastNU) {
        loadedSections.shuffle(); // safe - growable List.from() above
      }

      // Build per-section timer map (seconds)
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
      // Guard: don't tick if session not ready or already done
      if (current == null || current.isSubmitted) {
        _timer?.cancel();
        return;
      }
      // Guard: don't tick if sections are somehow empty
      if (current.sections.isEmpty) return;

      if (type == ExamType.nustNET || type == ExamType.nts) {
        // NTS and NUST both use a single global countdown timer.
        // NTS sections have totalMinutes=0 so per-section timer must NOT be used.
        final rem = current.globalSecondsLeft - 1;
        if (rem <= 0) {
          submitPaper();
          return;
        }
        state = AsyncValue.data(current.copyWith(globalSecondsLeft: rem));
      } else {
        // FAST only — per-section timer
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

    // FAST: locked after confirm
    if (current.answers[qId]?.isConfirmed == true) return;

    final updated = Map<String, QuestionAnswer>.from(current.answers);
    updated[qId] = QuestionAnswer(questionId: qId, selectedIndex: optionIndex);
    state = AsyncValue.data(current.copyWith(answers: updated));
  }

  // NTS only — answer a specific question by ID (3 on one page at once)
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

  // FAST only — locks the answer permanently
  void confirmAnswer() {
    final current = state.value;
    if (current == null || current.isSubmitted) return;

    final qId = current.currentQuestion.id;
    final existing = current.answers[qId];
    if (existing?.selectedIndex == null) return; // nothing selected

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

  // NUST only — free switching between sections
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

  // FAST only — one-way section advance, cannot go back
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

  // NTS booklet: jump to a specific page within current section
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
          penalty += ls.config.markWrong; // already ≤ 0
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

  // Returns the last computed result — used by ref.listen navigation
  // so the screen can navigate to PaperResultScreen after timer auto-submit.
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
