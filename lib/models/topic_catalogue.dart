// lib/models/topic_catalogue.dart
//
// What the topic picker shows: the chapters of a section, in printed order,
// each with the finer topics underneath it.
//
// Two levels because one would not work either way round. The bank's own
// topic strings are too many — 230 in Physics, averaging seven questions —
// and a student has never heard of most of them, because they are our labels
// rather than the book's. The chapters alone are too few: an NAT student
// looking for "Synonyms" should not have to know it lives under "Vocabulary"
// with 307 questions in it.
//
// Built from the in-memory question pool, which is already loaded to run a
// quiz, so opening the picker costs no reads.

import 'package:flutter/foundation.dart';
import 'package:ustaad/core/exam/syllabus_order.dart';
import 'package:ustaad/models/question_model.dart';

@immutable
class TopicEntry {
  const TopicEntry({required this.name, required this.questionCount});

  final String name;
  final int questionCount;
}

@immutable
class ChapterEntry {
  const ChapterEntry({
    required this.name,
    required this.questionCount,
    required this.topics,
    this.isLoose = false,
  });

  final String name;
  final int questionCount;

  /// The bank's own topics inside this chapter, largest first. One topic that
  /// accounts for the whole chapter is not worth expanding into, so the
  /// picker hides the list in that case.
  final List<TopicEntry> topics;

  /// True when this is a topic with no printed chapter, standing on its own
  /// at the top level. Sections with no syllabus are entirely these, and so
  /// are the few labels too vague to place.
  final bool isLoose;

  bool get worthExpanding => topics.length > 1;
}

@immutable
class TopicCatalogue {
  const TopicCatalogue({required this.chapters, required this.totalQuestions});

  final List<ChapterEntry> chapters;
  final int totalQuestions;

  bool get isEmpty => chapters.isEmpty;

  /// Groups a section's questions into chapters and topics.
  ///
  /// Chapters come back in printed order; anything with no chapter follows,
  /// largest first, so a section with no syllabus still reads sensibly. The
  /// order is deliberate — a student scanning for "Nuclear Physics" expects
  /// it near the end, where the book puts it, not wherever the question count
  /// happens to place it.
  factory TopicCatalogue.fromQuestions(
    List<Question> questions,
    String section,
  ) {
    // chapter -> topic -> count. An empty chapter key collects the loose ones.
    final grouped = <String, Map<String, int>>{};
    for (final q in questions) {
      final chapter = q.chapter.trim();
      final topic = q.topic.trim().isEmpty ? 'General' : q.topic.trim();
      final byTopic = grouped.putIfAbsent(chapter, () => <String, int>{});
      byTopic[topic] = (byTopic[topic] ?? 0) + 1;
    }

    List<TopicEntry> topicsOf(Map<String, int> m) {
      final out = m.entries
          .map((e) => TopicEntry(name: e.key, questionCount: e.value))
          .toList()
        ..sort((a, b) {
          final byCount = b.questionCount.compareTo(a.questionCount);
          return byCount != 0 ? byCount : a.name.compareTo(b.name);
        });
      return out;
    }

    int countOf(Map<String, int> m) =>
        m.values.fold(0, (sum, n) => sum + n);

    final out = <ChapterEntry>[];

    // Printed order first, skipping chapters this section has nothing for —
    // an empty chapter in the list is a dead end a student taps once.
    for (final name in kSyllabusOrder[section] ?? const <String>[]) {
      final byTopic = grouped.remove(name);
      if (byTopic == null || byTopic.isEmpty) continue;
      out.add(ChapterEntry(
        name: name,
        questionCount: countOf(byTopic),
        topics: topicsOf(byTopic),
      ));
    }

    // Anything the syllabus does not name. Each loose topic stands on its own
    // rather than being bundled under a heading like "Other", which would
    // hide questions a student is entitled to practise.
    final loose = grouped.remove('') ?? <String, int>{};
    final leftovers = <TopicEntry>[
      ...topicsOf(loose),
      // A chapter that exists on questions but not in the printed list — only
      // possible if the two have drifted apart. Shown rather than dropped.
      for (final entry in grouped.entries)
        TopicEntry(name: entry.key, questionCount: countOf(entry.value)),
    ]..sort((a, b) => b.questionCount.compareTo(a.questionCount));

    for (final t in leftovers) {
      out.add(ChapterEntry(
        name: t.name,
        questionCount: t.questionCount,
        topics: const [],
        isLoose: true,
      ));
    }

    return TopicCatalogue(
      chapters: out,
      totalQuestions: questions.length,
    );
  }
}
