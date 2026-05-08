// lib/models/question_model.dart
// FIXED: All fields use safe null-coalescing casts.
// Your Firestore docs don't have 'year', 'difficulty', or 'topic' on every doc
// — this model handles that gracefully without crashing.

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String section;
  final String exam;
  final String topic;
  final int year;
  final String difficulty;
  final String explanationEn;
  final String explanationUr;

  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.section,
    required this.exam,
    required this.topic,
    required this.year,
    required this.difficulty,
    required this.explanationEn,
    required this.explanationUr,
  });

  factory Question.fromFirestore(Map<String, dynamic> data, String docId) {
    return Question(
      id: docId,
      // ── FIXED: Use ?? to provide defaults instead of 'as String' ──
      text: data['text']?.toString() ?? "Missing Question Text",

      // ── FIXED: Handle 'exams' (Array) from DB while model expects String ──
      // This takes the first exam from the list, or 'N/A' if empty
      exam: (data['exams'] as List?)?.isNotEmpty == true
          ? data['exams'][0].toString()
          : (data['exam']?.toString() ?? 'N/A'),

      section: data['section']?.toString() ?? "General",

      // ── FIXED: Safe list conversion ──
      options: List<String>.from(data['options'] ?? []),

      // ── correctIndex: Keep your num cast, but add a null fallback ──
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,

      // ── Optional fields ──
      topic: data['topic']?.toString() ?? 'General',
      year: (data['year'] as num?)?.toInt() ?? 2024,
      difficulty: data['difficulty']?.toString() ?? 'medium',
      explanationEn: data['explanation_en']?.toString() ?? '',
      explanationUr: data['explanation_ur']?.toString() ?? '',
    );
  }
}
