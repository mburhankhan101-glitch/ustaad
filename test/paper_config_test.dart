import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/models/paper_model.dart';

/// Marking schemes, pinned.
///
/// These are the numbers a student's result is calculated from, and they are
/// the kind of thing that breaks silently: a wrong figure here does not crash,
/// it just quietly reports the wrong score for every paper anyone sits. There
/// is no way to notice by using the app unless you happen to do the arithmetic.
///
/// Writing this file found two live discrepancies. See the NTS group below.
void main() {
  /// Every question in a section is worth [markCorrect], so a perfect paper
  /// scores the sum of totalQuestions * markCorrect across its sections. That
  /// figure has to match [PaperConfigs.maxMarks], because the result screen
  /// renders "N out of ${maxMarks}".
  double perfectScore(ExamType type) => PaperConfigs.forExamType(type).fold(
        0.0,
        (sum, s) => sum + s.totalQuestions * s.markCorrect,
      );

  int questionCount(ExamType type) => PaperConfigs.forExamType(type)
      .fold(0, (sum, s) => sum + s.totalQuestions);

  group('a perfect paper scores exactly the advertised maximum', () {
    test('NUST NET — 200 marks', () {
      expect(perfectScore(ExamType.nustNET), closeTo(200.0, 0.001));
      expect(PaperConfigs.maxMarks(ExamType.nustNET), 200.0);
    });

    test('MDCAT — 180 marks', () {
      expect(perfectScore(ExamType.mdcat), closeTo(180.0, 0.001));
      expect(PaperConfigs.maxMarks(ExamType.mdcat), 180.0);
    });

    test('NUMS — 150 marks', () {
      expect(perfectScore(ExamType.numsMdcat), closeTo(150.0, 0.001));
      expect(PaperConfigs.maxMarks(ExamType.numsMdcat), 150.0);
    });

    test('NTS — 90 marks, not 100', () {
      // NTS NAT is a 90 question paper: 20 English + 20 Analytical +
      // 20 Quantitative + 30 subject, all worth 1 mark. maxMarks was 100, so
      // a student answering every question correctly was shown
      // "90 out of 100" — a perfect paper that reads as 90%.
      expect(questionCount(ExamType.nts), 90);
      expect(perfectScore(ExamType.nts), closeTo(90.0, 0.001));
      expect(PaperConfigs.maxMarks(ExamType.nts), 90.0);
    });

    test('FAST NU — 100 marks, within the English rounding', () {
      // FAST weights English at 0.344 a question rather than 1.0, which is
      // the real paper's scheme. 30 * 0.344 = 10.32, so a perfect paper comes
      // to 100.32 rather than a round 100.
      //
      // The tolerance is deliberate: it accepts the existing rounding but
      // fails if the weighting or a question count drifts far enough to
      // actually mislead someone. If the real FAST English section is meant
      // to total 10.0, markCorrect should be 1/3 and this becomes exact.
      expect(perfectScore(ExamType.fastNU), closeTo(100.0, 0.5));
      expect(PaperConfigs.maxMarks(ExamType.fastNU), 100.0);
    });
  });

  group('negative marking applies only where the real exam has it', () {
    test('FAST NU penalises wrong answers', () {
      final sections = PaperConfigs.forExamType(ExamType.fastNU);
      expect(sections.every((s) => s.markWrong < 0), isTrue,
          reason: 'FAST deducts marks in every section');
    });

    test('NUST, NTS, MDCAT and NUMS do not penalise wrong answers', () {
      for (final type in [
        ExamType.nustNET,
        ExamType.nts,
        ExamType.mdcat,
        ExamType.numsMdcat,
      ]) {
        expect(
          PaperConfigs.forExamType(type).every((s) => s.markWrong == 0.0),
          isTrue,
          reason: '${PaperConfigs.examLabel(type)} has no negative marking; '
              'deducting marks would under-report every result',
        );
      }
    });
  });

  group('every exam is configured at all', () {
    test('each type has sections, a duration and a label', () {
      for (final type in ExamType.values) {
        final sections = PaperConfigs.forExamType(type);
        expect(sections, isNotEmpty,
            reason: '$type has no sections, so its paper cannot be built');
        expect(PaperConfigs.totalMinutes(type), greaterThan(0));
        expect(PaperConfigs.maxMarks(type), greaterThan(0));
        expect(PaperConfigs.examLabel(type).trim(), isNotEmpty);
      }
    });

    test('section ids are unique within an exam', () {
      // Duplicate ids silently collapse answers from two sections into one.
      for (final type in ExamType.values) {
        final ids = PaperConfigs.forExamType(type).map((s) => s.id).toList();
        expect(ids.toSet().length, ids.length,
            reason: '${PaperConfigs.examLabel(type)} has a duplicate section id');
      }
    });

    test('no section is empty or untimed at the paper level', () {
      for (final type in ExamType.values) {
        for (final s in PaperConfigs.forExamType(type)) {
          expect(s.totalQuestions, greaterThan(0),
              reason: '${PaperConfigs.examLabel(type)} / ${s.id} has no questions');
          expect(s.markCorrect, greaterThan(0),
              reason: '${PaperConfigs.examLabel(type)} / ${s.id} awards nothing '
                  'for a correct answer');
        }
      }
    });
  });

  group('question counts match the published paper patterns', () {
    test('counts are what the store listing and website advertise', () {
      expect(questionCount(ExamType.fastNU), 120);
      expect(questionCount(ExamType.nustNET), 200);
      expect(questionCount(ExamType.nts), 90);
      expect(questionCount(ExamType.mdcat), 180);
      expect(questionCount(ExamType.numsMdcat), 150);
    });
  });
}
