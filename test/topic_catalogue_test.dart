// How the chapter picker is assembled.
//
// The failure modes here are quiet ones: a chapter listed with nothing in it
// is a dead end a student taps once and then stops trusting the list, and a
// topic with no chapter silently dropped is questions the student paid for
// and cannot reach.

import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/models/question_model.dart';
import 'package:ustaad/models/topic_catalogue.dart';

Question _q({
  required String topic,
  String chapter = '',
  String section = 'Physics',
  String id = 'q',
}) =>
    Question(
      id: id,
      text: 'text',
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: 0,
      section: section,
      exam: 'NUST-NET',
      exams: const ['NUST-NET'],
      topic: topic,
      chapter: chapter,
      year: 2024,
      difficulty: 'medium',
      explanationEn: '',
      explanationUr: '',
    );

List<Question> _many(int n, {required String topic, String chapter = ''}) =>
    List.generate(n, (i) => _q(topic: topic, chapter: chapter, id: '$topic$i'));

void main() {
  group('chapters come back in printed order', () {
    test('not in question-count order', () {
      // Electrostatics has far more questions, but Measurement is chapter one
      // and a student scanning the list expects it first.
      final cat = TopicCatalogue.fromQuestions(
        [
          ..._many(80, topic: 'Coulomb Law', chapter: 'Electrostatics'),
          ..._many(5, topic: 'Units', chapter: 'Measurement'),
        ],
        'Physics',
      );
      expect(cat.chapters.map((c) => c.name).toList(),
          ['Measurement', 'Electrostatics']);
    });

    test('a chapter with no questions is left out entirely', () {
      final cat = TopicCatalogue.fromQuestions(
        _many(6, topic: 'Units', chapter: 'Measurement'),
        'Physics',
      );
      expect(cat.chapters.length, 1);
      expect(cat.chapters.single.name, 'Measurement');
    });
  });

  group('nothing is lost', () {
    test('a topic with no chapter still appears, on its own', () {
      final cat = TopicCatalogue.fromQuestions(
        [
          ..._many(5, topic: 'Units', chapter: 'Measurement'),
          ..._many(9, topic: 'General'),
        ],
        'Physics',
      );
      final loose = cat.chapters.firstWhere((c) => c.isLoose);
      expect(loose.name, 'General');
      expect(loose.questionCount, 9);
    });

    test('a section with no syllabus is all loose topics', () {
      final cat = TopicCatalogue.fromQuestions(
        [
          ..._many(12, topic: 'Analogies', chapter: ''),
          ..._many(7, topic: 'Blood Relations', chapter: ''),
        ],
        'Analytical',
      );
      expect(cat.chapters.every((c) => c.isLoose), isTrue);
      expect(cat.chapters.map((c) => c.name).toList(),
          ['Analogies', 'Blood Relations'], reason: 'largest first');
    });

    test('a chapter not in the printed list is shown, not dropped', () {
      // Only possible if the app and the bank have drifted apart. Showing it
      // is strictly better than silently hiding the questions.
      final cat = TopicCatalogue.fromQuestions(
        _many(8, topic: 'Something', chapter: 'Chapter We Do Not Know'),
        'Physics',
      );
      expect(cat.chapters.single.name, 'Chapter We Do Not Know');
      expect(cat.chapters.single.questionCount, 8);
    });

    test('every question lands somewhere', () {
      final all = [
        ..._many(5, topic: 'Units', chapter: 'Measurement'),
        ..._many(9, topic: 'General'),
        ..._many(3, topic: 'Odd', chapter: 'Unknown Chapter'),
      ];
      final cat = TopicCatalogue.fromQuestions(all, 'Physics');
      final counted =
          cat.chapters.fold<int>(0, (n, c) => n + c.questionCount);
      expect(counted, all.length);
      expect(cat.totalQuestions, all.length);
    });
  });

  group('topics inside a chapter', () {
    test('are listed largest first', () {
      final cat = TopicCatalogue.fromQuestions(
        [
          ..._many(3, topic: 'Capacitance', chapter: 'Electrostatics'),
          ..._many(11, topic: 'Coulomb Law', chapter: 'Electrostatics'),
          ..._many(7, topic: 'Electric Field', chapter: 'Electrostatics'),
        ],
        'Physics',
      );
      final c = cat.chapters.single;
      expect(c.questionCount, 21);
      expect(c.topics.map((t) => t.name).toList(),
          ['Coulomb Law', 'Electric Field', 'Capacitance']);
    });

    test('a chapter of one topic is not worth expanding', () {
      // Expanding to reveal a single row that says the same as the header is
      // a control that does nothing.
      final cat = TopicCatalogue.fromQuestions(
        _many(20, topic: 'Coulomb Law', chapter: 'Electrostatics'),
        'Physics',
      );
      expect(cat.chapters.single.worthExpanding, isFalse);
    });

    test('an empty topic label becomes General rather than a blank row', () {
      final cat = TopicCatalogue.fromQuestions(
        [_q(topic: '   ', chapter: 'Measurement')],
        'Physics',
      );
      expect(cat.chapters.single.topics.single.name, 'General');
    });
  });

  test('an empty section produces an empty catalogue, not a crash', () {
    final cat = TopicCatalogue.fromQuestions(const [], 'Physics');
    expect(cat.isEmpty, isTrue);
    expect(cat.totalQuestions, 0);
  });
}
