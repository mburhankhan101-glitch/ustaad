// lib/screens/quiz/topic_practice_screen.dart
//
// Pick a chapter, or a topic inside it, and practise just that.
//
// The list is the contents page of the book on the student's desk: printed
// chapter order, not question-count order, because someone looking for
// Nuclear Physics expects it near the end where the book puts it. Chapters
// the bank has nothing for are left out — an empty chapter is a dead end a
// student taps once and then distrusts the whole list.
//
// Weak topics come first, above everything, because the student who opens
// this screen is usually looking for the thing they keep getting wrong.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/core/analytics/analytics_service.dart';
import 'package:ustaad/models/topic_catalogue.dart';
import 'package:ustaad/providers/progress_provider.dart';
import 'package:ustaad/screens/home/home_screen.dart'; // UstaadColors
import 'package:ustaad/screens/quiz/quiz_screen.dart' show QuizScreen;
import 'package:ustaad/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TopicPracticeScreen extends ConsumerStatefulWidget {
  const TopicPracticeScreen({
    super.key,
    required this.exam,
    required this.section,
    this.additionalSection,
  });

  final String exam;
  final String section;
  final String? additionalSection;

  @override
  ConsumerState<TopicPracticeScreen> createState() =>
      _TopicPracticeScreenState();
}

class _TopicPracticeScreenState extends ConsumerState<TopicPracticeScreen> {
  /// Below this a "quiz" is a couple of questions and an anticlimax, so the
  /// entry is shown greyed with its count rather than hidden — a student who
  /// knows the chapter exists should see why it is not offered.
  static const int _minForQuiz = 4;

  /// Chapters can run to 157 questions; a sitting is still ten.
  static const int _quizLength = 10;

  Future<TopicCatalogue>? _future;
  final _search = TextEditingController();
  String _query = '';
  String? _expanded;

  @override
  void initState() {
    super.initState();
    _future = FirestoreService().topicCatalogue(
      exam: widget.exam,
      section: widget.section,
      additionalSection: widget.additionalSection,
      uid: FirebaseAuth.instance.currentUser?.uid,
    );
    Analytics.instance.topicPickerOpened(
      exam: widget.exam,
      section: widget.section,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _start({String? chapter, String? topic, required int available}) {
    HapticFeedback.lightImpact();
    Analytics.instance.topicPracticeStarted(
      exam: widget.exam,
      section: widget.section,
      chapter: chapter ?? '',
      topic: topic ?? '',
      available: available,
    );
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => QuizScreen(
          exam: widget.exam,
          section: widget.section,
          chapter: chapter,
          topic: topic,
          // Never ask for more than the chapter holds, so the last sitting of
          // a small chapter is honest rather than padded.
          limit: available < _quizLength ? available : _quizLength,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );
  }

  /// The student's own weak topics for this section, strongest signal first.
  List<MapEntry<String, int>> _weakTopics() {
    final data = ref.watch(userProgressProvider).valueOrNull;
    final weak = data?['weakTopics'] as Map<String, dynamic>?;
    final sections = data?['weakTopicSections'] as Map<String, dynamic>?;
    if (weak == null) return const [];
    final out = <MapEntry<String, int>>[];
    weak.forEach((topic, count) {
      // Only this section's, so a Physics weak topic does not appear while
      // the student is choosing Chemistry.
      if (sections != null &&
          sections[topic] != null &&
          sections[topic].toString() != widget.section) {
        return;
      }
      final n = (count as num?)?.toInt() ?? 0;
      if (n > 0) out.add(MapEntry(topic, n));
    });
    out.sort((a, b) => b.value.compareTo(a.value));
    return out.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UstaadColors.background1,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Practice by chapter',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${widget.exam} · ${widget.section}',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<TopicCatalogue>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          }
          final cat = snap.data;
          if (cat == null || cat.isEmpty) {
            return _message(
              'No questions here yet',
              'This section has nothing to practise by chapter. Try a normal '
                  'quiz instead.',
            );
          }

          final chapters = _filtered(cat.chapters);
          final weak = _query.isEmpty ? _weakTopics() : const [];

          return ListView(
            // Enough tail that the last chapter is not pinned to the bezel,
            // plus whatever the system navigation bar takes.
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              48 + MediaQuery.of(context).viewPadding.bottom,
            ),
            children: [
              _searchBox(cat.totalQuestions),
              if (weak.isNotEmpty) ...[
                const SizedBox(height: 18),
                _label('Where you keep slipping'),
                const SizedBox(height: 8),
                for (final w in weak) _weakRow(w.key, w.value),
              ],
              const SizedBox(height: 18),
              _label(_query.isEmpty
                  ? 'Chapters'
                  : '${chapters.length} matching'),
              const SizedBox(height: 8),
              if (chapters.isEmpty)
                _message('Nothing matches', 'Try a different word.')
              else
                for (final c in chapters) _chapterTile(c),
            ],
          );
        },
      ),
    );
  }

  List<ChapterEntry> _filtered(List<ChapterEntry> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.topics.any((t) => t.name.toLowerCase().contains(q)))
        .toList();
  }

  // ── Pieces ───────────────────────────────────────────────────────────────

  Widget _searchBox(int total) {
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v.trim()),
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Search $total questions',
        hintStyle: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white.withOpacity(0.35),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4), size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 18),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: UstaadColors.primary),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white.withOpacity(0.45),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      );

  Widget _weakRow(String topic, int wrongCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _start(topic: topic, available: _quizLength),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: UstaadColors.accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: UstaadColors.accent.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 17)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  topic,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$wrongCount wrong',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: UstaadColors.accent.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chapterTile(ChapterEntry c) {
    final open = _expanded == c.name;
    final enough = c.questionCount >= _minForQuiz;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: open
                ? UstaadColors.primary.withOpacity(0.45)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enough
                  ? () => _start(
                        chapter: c.isLoose ? null : c.name,
                        topic: c.isLoose ? c.name : null,
                        available: c.questionCount,
                      )
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: enough
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.45),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            enough
                                ? '${c.questionCount} questions'
                                : 'only ${c.questionCount} — too few for a quiz',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (c.worthExpanding)
                      IconButton(
                        icon: Icon(
                          open ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white.withOpacity(0.5),
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _expanded = open ? null : c.name),
                      )
                    else if (enough)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: UstaadColors.primary.withOpacity(0.85),
                          size: 22,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    Divider(color: Colors.white.withOpacity(0.08), height: 14),
                    for (final t in c.topics) _topicRow(t),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topicRow(TopicEntry t) {
    final enough = t.questionCount >= _minForQuiz;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enough
          ? () => _start(topic: t.name, available: t.questionCount)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(right: 11, left: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(enough ? 0.4 : 0.18),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                t.name,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(enough ? 0.82 : 0.38),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${t.questionCount}',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (enough)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.3),
                  size: 17,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _message(String title, String body) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
}
