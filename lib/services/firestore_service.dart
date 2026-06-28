import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ustaad/models/question_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FirestoreService — Ustaad
//
// QUESTION DELIVERY MODEL (pool-pointer / deck-of-cards):
//
//   • First call for a section  → fetch ALL matching docs from Firestore server,
//     place unseen questions first (shuffled), seen questions after (shuffled),
//     store the whole deck in _pool. Cost: 1 Firestore read per section per
//     app session.
//
//   • Every subsequent call     → read from _pool using _pointer. Zero network
//     reads. Pointer advances so every question is served exactly once before
//     any question can repeat.
//
//   • Pointer reaches pool end  → reshuffle entire deck in memory, reset
//     pointer to 0, clear seenIds so cross-session tracking also resets.
//
// EXPLANATION CACHING:
//   • If your Question model carries an `explanation` field, it is pre-loaded
//     into _explanationCache when the pool is built (zero extra reads ever).
//   • If explanation is fetched separately, fetchExplanation() reads it once
//     and caches it. Every subsequent click on the same question costs 0 reads.
//
// SEEN-IDS (cross-session — prioritises unseen questions after app restart):
//   • Loaded from Firestore SDK local cache first (zero network cost).
//     Falls back to server only on first install (1 read, rare).
//   • Written to Firestore ONCE at session end via flushSeenIds(),
//     not after every quiz start. Saves many write operations.
//
// READ COST SUMMARY per app session:
//   Questions    : 1 read × number of distinct sections opened
//   SeenIds      : 1 read × section (SDK cache hit after first install)
//   Explanations : 1 read × question (only if not in Question model already)
//   Progress/User: unchanged (transactional writes only, no extra reads)
// ═══════════════════════════════════════════════════════════════════════════════

class FirestoreService {
  // ── SINGLETON ──────────────────────────────────────────────────────────────
  // Using a singleton means the _pool built in QuizScreen is still alive
  // when ResultScreen calls getPoolSize() — no new instance, no empty pool.
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── IN-MEMORY STATE ─────────────────────────────────────────────────────────

  // Full question deck per section, ordered unseen-first after shuffle.
  // Key format: "FAST-NU_Advanced Maths"
  final Map<String, List<Question>> _pool = {};

  // Next index to serve from each pool. Advances until deck is exhausted.
  final Map<String, int> _pointer = {};

  // Explanation text, keyed by question ID.
  // Pre-populated from Question.explanation when pool is built.
  // After that, every tap on ExplanationSheet costs zero reads.
  final Map<String, String> _explanationCache = {};

  // SeenIds loaded once from Firestore, kept in memory.
  // Written back only at session end — not after every quiz start.
  final Map<String, Set<String>> _seenCache = {};

  // ── PUBLIC: POOL SIZE ───────────────────────────────────────────────────────

  /// Returns the real total number of questions in Firestore for [exam]/[section].
  ///
  /// This is the actual pool size — not hardcoded, not guessed.
  /// The pool is already in memory after fetchQuestions() runs in QuizScreen,
  /// so this is a zero-cost in-memory lookup.
  ///
  /// Returns null if the pool hasn't been built yet for this section.
  int? getPoolSize(String exam, String section) {
    final key = _sectionKey(exam, section);
    return _pool[key]?.length;
  }

  // ── PUBLIC: FETCH QUESTIONS ─────────────────────────────────────────────────

  /// Returns up to [limit] questions for [exam] / [section].
  ///
  /// [uid]               — supply for cross-session unseen-first ordering.
  ///                       If null, pool still works without seenIds priority.
  /// [sessionExcludeIds] — IDs already shown in this paper run.
  ///                       For quiz screen, leave empty; the pointer handles it.
  // firestore_service.dart – inside FirestoreService class

  Future<List<Question>> fetchQuestions({
    required String exam,
    required String section,
    String? additionalSection,
    int limit = 10,
    String? uid,
    Set<String> sessionExcludeIds = const {},
    String? topic, // ← new
  }) async {
    final key = _sectionKey(exam, section);

    try {
      // Build pool if not yet loaded
      if (!_pool.containsKey(key)) {
        await _buildPool(
          exam: exam,
          section: section,
          additionalSection: additionalSection,
          uid: uid,
          key: key,
        );
      }

      // ── Topic‑filtered branch ──────────────────────────────────────────
      if (topic != null && topic.isNotEmpty) {
        final pool = _pool[key];
        if (pool == null || pool.isEmpty) return [];

        final filtered =
            pool
                .where(
                  (q) =>
                      q.topic.trim().toLowerCase() ==
                      topic.trim().toLowerCase(),
                )
                .toList()
              ..shuffle();

        final count = filtered.length < limit ? filtered.length : limit;
        print(
          '🎯 USTAAD: Topic-filtered practice → “$topic” → $count questions',
        );
        return filtered.take(count).toList();
      }

      // ── Standard pool‑pointer branch (unchanged) ──────────────────────
      return _serveFromPool(
        key: key,
        limit: limit,
        sessionExcludeIds: sessionExcludeIds,
        uid: uid,
        exam: exam,
        section: section,
      );
    } on FirebaseException catch (e) {
      print(
        '🔴 USTAAD Firebase Error in fetchQuestions [${e.code}]: ${e.message}',
      );
      return [];
    } catch (e) {
      print('🔴 USTAAD Error in fetchQuestions: $e');
      return [];
    }
  }

  // ── PUBLIC: FETCH EXPLANATION ───────────────────────────────────────────────

  /// Returns the explanation for [questionId] in the requested language.
  ///
  /// Since both `explanation_en` and `explanation_ur` are fields on your
  /// Question documents, they are pre-loaded into cache when the pool builds.
  /// This means the very first tap on ExplanationSheet already costs 0 reads.
  ///
  /// The Firestore fallback only fires if somehow a question wasn't in the
  /// pool (e.g. ExplanationSheet opened from a history screen).
  Future<String> fetchExplanation(
    String questionId, {
    bool inUrdu = false,
  }) async {
    final lang = inUrdu ? 'ur' : 'en';
    final cacheKey = '${questionId}_$lang';
    final firestoreField = inUrdu ? 'explanation_ur' : 'explanation_en';

    // Cache hit — instant, zero reads (covers 99%+ of cases)
    final cached = _explanationCache[cacheKey];
    if (cached != null) {
      print('⚡ USTAAD: Explanation ($lang) from cache — $questionId');
      return cached;
    }

    // Cache miss — 1 read, then permanently cached for this app session
    try {
      final doc = await _db.collection('questions').doc(questionId).get();
      final text = doc.data()?[firestoreField] as String? ?? '';
      _explanationCache[cacheKey] = text;
      print('📖 USTAAD: Explanation ($lang) fetched & cached — $questionId');
      return text;
    } on FirebaseException catch (e) {
      print('🔴 USTAAD: fetchExplanation error [${e.code}]: ${e.message}');
      return '';
    } catch (e) {
      print('🔴 USTAAD: fetchExplanation exception: $e');
      return '';
    }
  }

  // ── PUBLIC: FLUSH SEEN IDS ──────────────────────────────────────────────────

  /// Merges [servedIds] into the seenIds for [exam]/[section] and writes
  /// the result to Firestore. Call this ONCE when a quiz or paper ends.
  ///
  /// Do NOT call this after every question. One write per completed session.
  Future<void> flushSeenIds({
    required String uid,
    required String exam,
    required String section,
    required Set<String> servedIds,
  }) async {
    if (servedIds.isEmpty) return;
    final key = _sectionKey(exam, section);

    final existing = _seenCache[key] ?? {};
    final merged = {...existing, ...servedIds};
    _seenCache[key] = merged; // keep memory in sync

    await _writeSeenIds(uid: uid, key: key, seenIds: merged);
    print('💾 USTAAD: seenIds flushed — ${merged.length} total for $key');
  }

  // ── PUBLIC: RESET PROGRESS ──────────────────────────────────────────────────

  /// Clears seen-question history for a section (Profile screen).
  /// Also wipes the in-memory pool so it rebuilds fresh next time.
  Future<void> resetSeenQuestions({
    required String uid,
    required String sectionKey,
  }) async {
    _seenCache.remove(sectionKey);
    _pool.remove(sectionKey);
    _pointer.remove(sectionKey);

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('seenQuestions')
          .doc(sectionKey)
          .delete();
      print('✅ USTAAD: SeenIds reset for $sectionKey');
    } on FirebaseException catch (e) {
      print('⚠️ USTAAD: resetSeenQuestions error [${e.code}]: ${e.message}');
    } catch (e) {
      print('⚠️ USTAAD: resetSeenQuestions exception: $e');
    }
  }

  // ── PRIVATE: BUILD POOL ─────────────────────────────────────────────────────
  // Called once per section per app session. This is the only place that
  // hits the Firestore server for questions.

  Future<void> _buildPool({
    required String exam,
    required String section,
    String? additionalSection,
    String? uid,
    required String key,
  }) async {
    // 1. Fetch ALL questions for this section from Firestore server.
    //    Parallel queries if additionalSection is set (cuts latency ~50%).
    final all = await _fetchAllFromServer(
      exam: exam,
      section: section,
      additionalSection: additionalSection,
    );

    if (all.isEmpty) {
      _pool[key] = [];
      _pointer[key] = 0;
      print('⚠️ USTAAD: Pool empty for $key — no questions in Firestore?');
      return;
    }

    // 2. Pre-populate explanation cache from the question data.
    //    Data is already in memory — this loop costs zero Firestore reads.
    //    Both English and Urdu are cached separately so ExplanationSheet
    //    can switch languages without ever hitting the network again.
    for (final q in all) {
      if (q.explanationEn.isNotEmpty) {
        _explanationCache['${q.id}_en'] = q.explanationEn;
      }
      if (q.explanationUr.isNotEmpty) {
        _explanationCache['${q.id}_ur'] = q.explanationUr;
      }
    }

    // 3. Load seenIds (SDK cache-first = zero network. 1 server read on fresh install only).
    Set<String> seen = {};
    if (uid != null) {
      seen = await _loadSeenIds(uid: uid, key: key);
      _seenCache[key] = seen;
    }

    // 4. Unseen questions first (shuffled), seen questions after (shuffled).
    //    This means every new question is always shown before revisiting old ones,
    //    even if the unseen count is smaller than the requested limit.
    final unseen = all.where((q) => !seen.contains(q.id)).toList()..shuffle();
    final seenList = all.where((q) => seen.contains(q.id)).toList()..shuffle();

    _pool[key] = [...unseen, ...seenList];
    _pointer[key] = 0;

    print(
      '🏗️ USTAAD Pool[$key]: '
      '${unseen.length} unseen + ${seenList.length} seen '
      '= ${_pool[key]!.length} total',
    );
  }

  // ── PRIVATE: SERVE FROM POOL ────────────────────────────────────────────────

  List<Question> _serveFromPool({
    required String key,
    required int limit,
    required Set<String> sessionExcludeIds,
    String? uid,
    required String exam,
    required String section,
  }) {
    final pool = _pool[key];
    if (pool == null || pool.isEmpty) return [];

    final result = <Question>[];
    int ptr = _pointer[key] ?? 0;

    // Safety cap: never spin more than 2× pool length.
    // Handles edge cases where sessionExcludeIds is nearly as large as the pool.
    int guard = 0;
    final maxIterations = pool.length * 2;

    while (result.length < limit && guard < maxIterations) {
      // ── Deck exhausted: reshuffle and reset ─────────────────────────────
      if (ptr >= pool.length) {
        pool.shuffle();
        ptr = 0;
        _seenCache[key] = {};
        if (uid != null) {
          _deleteSeenIds(uid: uid, key: key); // fire-and-forget, non-fatal
        }
        print('🔄 USTAAD: Deck[$key] completed — reshuffled for next round');
      }

      final q = pool[ptr++];
      guard++;

      // Skip questions already shown in this paper/quiz session
      if (!sessionExcludeIds.contains(q.id)) {
        result.add(q);
      }
    }

    _pointer[key] = ptr;

    print(
      '✅ USTAAD: Served ${result.length}/$limit from $key '
      '(ptr $ptr/${pool.length})',
    );
    return result;
  }

  // ── PRIVATE: RAW SERVER FETCH ───────────────────────────────────────────────
  // No GetOptions = Firestore SDK default: server first, local cache if offline.
  // Parallel Future.wait slashes latency when additionalSection is set.

  Future<List<Question>> _fetchAllFromServer({
    required String exam,
    required String section,
    String? additionalSection,
  }) async {
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      _db
          .collection('questions')
          .where('exams', arrayContains: exam)
          .where('section', isEqualTo: section)
          .get(),
      if (additionalSection != null)
        _db
            .collection('questions')
            .where('exams', arrayContains: exam)
            .where('section', isEqualTo: additionalSection)
            .get(),
    ];

    final snapshots = await Future.wait(futures);
    final questions = <Question>[];

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        try {
          questions.add(Question.fromFirestore(doc.data(), doc.id));
        } catch (e) {
          print('⚠️ USTAAD: Skipping malformed doc ${doc.id}: $e');
        }
      }
    }

    print(
      '📥 USTAAD: Server fetched ${questions.length} docs '
      'for $exam / $section',
    );
    return questions;
  }

  // ── PRIVATE: SEEN IDS HELPERS ───────────────────────────────────────────────

  Future<Set<String>> _loadSeenIds({
    required String uid,
    required String key,
  }) async {
    // Return from memory if already loaded this session (zero reads)
    if (_seenCache.containsKey(key)) return _seenCache[key]!;

    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('seenQuestions')
        .doc(key);

    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        // SDK local cache — zero network cost on any app restart after first install
        doc = await ref.get(const GetOptions(source: Source.cache));
        print('⚡ USTAAD: seenIds from SDK cache for $key');
      } on FirebaseException {
        // First install or cache evicted — 1 server read
        doc = await ref.get();
        print('📡 USTAAD: seenIds from server for $key');
      }

      if (!doc.exists) return {};
      final raw = doc.data()?['seenIds'];
      return raw is List ? raw.map((e) => e.toString()).toSet() : {};
    } catch (e) {
      print('⚠️ USTAAD: _loadSeenIds failed for $key: $e');
      return {};
    }
  }

  Future<void> _writeSeenIds({
    required String uid,
    required String key,
    required Set<String> seenIds,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('seenQuestions')
          .doc(key)
          .set({'seenIds': seenIds.toList()});
    } on FirebaseException catch (e) {
      print('⚠️ USTAAD: _writeSeenIds error [${e.code}]: ${e.message}');
    }
  }

  // Fire-and-forget. Called when deck is exhausted. Failure is non-fatal.
  void _deleteSeenIds({required String uid, required String key}) {
    _db
        .collection('users')
        .doc(uid)
        .collection('seenQuestions')
        .doc(key)
        .delete()
        .catchError((_) {});
  }

  // ── PUBLIC: SAVE PROGRESS ───────────────────────────────────────────────────

  Future<void> saveProgress({
    required String uid,
    required String exam,
    required String section,
    required int score,
    required int totalSessionQuestions,
    required int totalPoolSize,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final today = _dateString(DateTime.now());

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data() ?? {};

        final int currentTotalSolved = (data['totalSolved'] as num? ?? 0)
            .toInt();
        final int currentTotalCorrect = (data['totalCorrect'] as num? ?? 0)
            .toInt();

        final int newTotalSolved = currentTotalSolved + totalSessionQuestions;
        final int newTotalCorrect = currentTotalCorrect + score;
        final double overallAccuracy = newTotalSolved > 0
            ? (newTotalCorrect / newTotalSolved) * 100
            : 0.0;

        final String lastSolvedDate = data['lastSolvedDate'] as String? ?? '';
        final int currentSolvedToday = (data['solvedToday'] as num? ?? 0)
            .toInt();
        final int newSolvedToday = lastSolvedDate == today
            ? currentSolvedToday + totalSessionQuestions
            : totalSessionQuestions;

        final progressMap = data['progress'] as Map<String, dynamic>? ?? {};
        final sectionKey = _sectionKey(exam, section);
        final sectionData =
            progressMap[sectionKey] as Map<String, dynamic>? ?? {};

        int newSectionSolved =
            (sectionData['totalSolved'] as num? ?? 0).toInt() +
            totalSessionQuestions;
        if (newSectionSolved > totalPoolSize) newSectionSolved = totalPoolSize;

        transaction.set(userRef, {
          'totalSolved': newTotalSolved,
          'totalCorrect': newTotalCorrect,
          'accuracy': overallAccuracy,
          'lastActive': FieldValue.serverTimestamp(),
          'solvedToday': newSolvedToday,
          'lastSolvedDate': today,
          'progress': {
            sectionKey: {
              'lastScore': score,
              'totalSolved': newSectionSolved,
              'percent': totalPoolSize > 0
                  ? newSectionSolved / totalPoolSize
                  : 0.0,
              'lastPlayed': FieldValue.serverTimestamp(),
            },
          },
        }, SetOptions(merge: true));
      });

      print('✅ USTAAD: Progress saved.');
    } on FirebaseException catch (e) {
      print('🔴 USTAAD Transaction error [${e.code}]: ${e.message}');
    } catch (e) {
      print('🔴 USTAAD: saveProgress exception: $e');
    }
  }

  // ── PUBLIC: WEAK TOPICS ─────────────────────────────────────────────────────

  Future<void> saveWeakTopics({
    required String uid,
    required Map<String, int> sessionWeakTopics,
    required String exam,
    required String section,
  }) async {
    if (sessionWeakTopics.isEmpty) return;
    final userRef = _db.collection('users').doc(uid);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data() ?? {};

        // ── Weak topic counts ──────────────────────────────────────────────
        final existing = Map<String, dynamic>.from(
          data['weakTopics'] as Map? ?? {},
        );
        for (final entry in sessionWeakTopics.entries) {
          final int current = (existing[entry.key] as num? ?? 0).toInt();
          existing[entry.key] = current + entry.value;
        }

        // ── Per-topic section map (NEW) ────────────────────────────────────
        // Stores which section each weak topic came from so home_screen can
        // open the correct pool. e.g. { "Trigonometry": "Advanced Maths" }
        final existingSections = Map<String, dynamic>.from(
          data['weakTopicSections'] as Map? ?? {},
        );
        for (final key in sessionWeakTopics.keys) {
          existingSections[key] = section;
        }

        tx.set(userRef, {
          'weakTopics': existing,
          'weakTopicSections': existingSections,
          'weakTopicExam': exam,
          'weakTopicSection': section,
        }, SetOptions(merge: true));
      });

      print(
        '✅ USTAAD: Weak topics saved — ${sessionWeakTopics.keys.join(", ")}',
      );
    } on FirebaseException catch (e) {
      print('🔴 USTAAD: saveWeakTopics error [${e.code}]: ${e.message}');
    } catch (e) {
      print('🔴 USTAAD: saveWeakTopics exception: $e');
    }
  }

  // ── PUBLIC: INCOMPLETE SESSION ──────────────────────────────────────────────

  Future<void> saveIncompleteSession({
    required String uid,
    required String exam,
    required String section,
    required int currentIndex,
    required int totalQuestions,
  }) async {
    try {
      await _db.collection('users').doc(uid).set({
        'incompleteSession': {
          'exam': exam,
          'section': section,
          'currentIndex': currentIndex,
          'totalQuestions': totalQuestions,
          'savedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      print(
        '✅ USTAAD: Incomplete session saved — $exam/$section @ Q${currentIndex + 1}',
      );
    } on FirebaseException catch (e) {
      print('🔴 USTAAD: saveIncompleteSession error [${e.code}]: ${e.message}');
    } catch (e) {
      print('🔴 USTAAD: saveIncompleteSession exception: $e');
    }
  }

  Future<void> clearIncompleteSession({required String uid}) async {
    try {
      await _db.collection('users').doc(uid).update({
        'incompleteSession': FieldValue.delete(),
      });
      print('✅ USTAAD: Incomplete session cleared.');
    } on FirebaseException catch (e) {
      print(
        '⚠️ USTAAD: clearIncompleteSession error [${e.code}]: ${e.message}',
      );
    } catch (e) {
      print('⚠️ USTAAD: clearIncompleteSession exception: $e');
    }
  }

  // ── DEBUG ───────────────────────────────────────────────────────────────────

  Future<void> debugRawQuery() async {
    try {
      final t1 = await _db
          .collection('questions')
          .where('exams', arrayContains: 'NTS')
          .limit(3)
          .get();
      print('🧪 Test1 (NTS only): ${t1.docs.length} docs');

      final t2 = await _db
          .collection('questions')
          .where('section', isEqualTo: 'Quantitative')
          .limit(3)
          .get();
      print('🧪 Test2 (Quantitative only): ${t2.docs.length} docs');

      final t3 = await _db
          .collection('questions')
          .where('exams', arrayContains: 'NTS')
          .where('section', isEqualTo: 'Quantitative')
          .limit(3)
          .get();
      print('🧪 Test3 (NTS + Quantitative): ${t3.docs.length} docs');

      final t4 = await _db.collection('questions').limit(3).get();
      print('🧪 Test4 (no filter): ${t4.docs.length} docs');

      // Pool diagnostics
      print('\n🧪 In-memory pool state:');
      if (_pool.isEmpty) {
        print('  (empty — no section loaded yet)');
      }
      for (final entry in _pool.entries) {
        final ptr = _pointer[entry.key] ?? 0;
        final pct = entry.value.isNotEmpty
            ? (ptr / entry.value.length * 100).toStringAsFixed(1)
            : '0';
        print(
          '  ${entry.key}: ${entry.value.length} questions, '
          'ptr=$ptr ($pct% through deck)',
        );
      }
      print('🧪 Explanation cache: ${_explanationCache.length} entries');
    } catch (e) {
      print('🧪 debugRawQuery crashed: $e');
    }
  }

  // ── PRIVATE UTILS ───────────────────────────────────────────────────────────

  String _sectionKey(String exam, String section) => '${exam}_$section';

  String _dateString(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
