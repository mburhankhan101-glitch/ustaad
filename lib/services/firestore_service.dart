// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ustaad/models/question_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Fetch questions from Firestore ───────────────────────────────────────
  // Called by both QuizScreen AND PaperSessionNotifier.
  //
  // exam    → value from SectionConfig.firestoreExam   e.g. "FAST-NU"
  //           Queries the 'exams' ARRAY field using arrayContains —
  //           one question can belong to multiple exams without duplication.
  // section → value from SectionConfig.firestoreSection e.g. "Advanced Maths"
  // limit   → how many to return after shuffling the full pool

  Future<List<Question>> fetchQuestions({
    required String exam,
    required String section,
    int limit = 10,
  }) async {
    try {
      print(
        '📚 USTAAD: Fetching questions — exam: $exam | section: $section | limit: $limit',
      );

      // 'exams' is now an array field (migrated from old 'exam' string).
      // arrayContains returns docs where the array includes this exam value.
      final snapshot = await _db
          .collection('questions')
          .where('exams', arrayContains: exam)
          .where('section', isEqualTo: section)
          .get();

      print(
        '📚 USTAAD: Found ${snapshot.docs.length} docs for $exam / $section',
      );

      if (snapshot.docs.isEmpty) {
        print(
          '🔴 USTAAD WARNING: No questions found for exam="$exam" section="$section"',
        );
        print(
          '   → Did the migration script run? Check Firestore that docs have an "exams" array.',
        );
        print(
          '   → Also verify that firestoreSection in paper_model.dart matches Firestore exactly.',
        );
        return [];
      }

      final questions = <Question>[];
      for (final doc in snapshot.docs) {
        try {
          questions.add(
            Question.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
          );
        } catch (e) {
          // One malformed doc should not crash the whole fetch
          print('⚠️ USTAAD: Skipping malformed doc ${doc.id}: $e');
        }
      }

      // Shuffle the full pool then take `limit`
      questions.shuffle();
      final result = questions.length > limit
          ? questions.sublist(0, limit)
          : questions;

      print(
        '✅ USTAAD: Returning ${result.length} questions for $exam / $section',
      );
      return result;
    } catch (e) {
      print('🔴 USTAAD Firestore fetch error for $exam/$section: $e');
      // Rethrow so quiz/paper screens can show an error state
      rethrow;
    }
  }

  // ─── Save user progress after a quiz session ───────────────────────────────

  Future<void> saveProgress({
    required String uid,
    required String exam,
    required String section,
    required int score,
    required int totalSessionQuestions,
    required int totalPoolSize,
  }) async {
    final userRef = _db.collection('users').doc(uid);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data() ?? {};

        final int currentTotalSolved = data['totalSolved'] ?? 0;
        final int currentTotalCorrect = data['totalCorrect'] ?? 0;

        final int newTotalSolved = currentTotalSolved + totalSessionQuestions;
        final int newTotalCorrect = currentTotalCorrect + score;
        final double overallAccuracy = (newTotalCorrect / newTotalSolved) * 100;

        final progressMap = data['progress'] as Map<String, dynamic>? ?? {};
        final sectionKey = '${exam}_$section';
        final sectionData =
            progressMap[sectionKey] as Map<String, dynamic>? ?? {};

        int newSectionSolved =
            (sectionData['totalSolved'] ?? 0) + totalSessionQuestions;
        if (newSectionSolved > totalPoolSize) newSectionSolved = totalPoolSize;

        transaction.set(userRef, {
          'totalSolved': newTotalSolved,
          'totalCorrect': newTotalCorrect,
          'accuracy': overallAccuracy,
          'lastActive': FieldValue.serverTimestamp(),
          'progress': {
            sectionKey: {
              'lastScore': score,
              'totalSolved': newSectionSolved,
              'percent': newSectionSolved / totalPoolSize,
              'lastPlayed': FieldValue.serverTimestamp(),
            },
          },
        }, SetOptions(merge: true));
      });

      print('✅ USTAAD SUCCESS: Progress saved to Firestore!');
    } catch (e) {
      print('🔴 USTAAD ERROR: Failed to save progress: $e');
    }
  }

  Future<void> debugRawQuery() async {
    final test1 = await _db
        .collection('questions')
        .where('exams', arrayContains: 'NTS')
        .limit(3)
        .get();
    print('🧪 Test1 (arrayContains NTS only): ${test1.docs.length} docs');

    final test2 = await _db
        .collection('questions')
        .where('section', isEqualTo: 'Quantitative')
        .limit(3)
        .get();
    print('🧪 Test2 (section Quantitative only): ${test2.docs.length} docs');

    final test3 = await _db
        .collection('questions')
        .where('exams', arrayContains: 'NTS')
        .where('section', isEqualTo: 'Quantitative')
        .limit(3)
        .get();
    print('🧪 Test3 (both together): ${test3.docs.length} docs');

    final test4 = await _db.collection('questions').limit(3).get();
    print('🧪 Test4 (no filter at all): ${test4.docs.length} docs');
  }
}
