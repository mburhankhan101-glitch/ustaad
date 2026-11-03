// lib/providers/exam_date_provider.dart
//
// The student's test dates, stored on their user document as
//
//   examDates: { 'NUST-NET': Timestamp, 'MDCAT': Timestamp }
//
// A map rather than a single field because sitting two or three tests is the
// norm here, not the exception — a FAST-NU candidate often sits NAT-NTS as
// well, and a medical student sits both MDCAT and NUMS. The home countdown
// shows whichever is soonest, which only works if each one can be recorded.
//
// This follows selectedTestsProvider exactly: it watches authProvider so the
// uid is a tracked dependency (a bare currentUser read would cache one
// account's dates into another's session after a logout/login swap), and it
// prefers the server with the local cache only as a fallback.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/core/exam/exam_countdown.dart';
import 'package:ustaad/providers/auth_provider.dart';

/// Everything about the student's exams that lives on their user document.
///
/// Both halves come from one read. Home needs the dates to draw the countdown
/// and the debrief markers to decide whether to ask about a paper just sat,
/// and two providers each fetching the same document would mean two server
/// round trips before the card could paint.
@immutable
class ExamPlan {
  const ExamPlan({required this.dates, required this.debriefed});

  const ExamPlan.empty() : dates = const {}, debriefed = const {};

  /// Exam id -> the day of that paper, at local midnight.
  final Map<String, DateTime> dates;

  /// Keys of sittings the student has already been asked about, in the shape
  /// [ExamCountdown.debriefKey] produces.
  final Set<String> debriefed;
}

final examPlanProvider = FutureProvider<ExamPlan>((ref) async {
  final uid = ref.watch(authProvider).user?.uid;
  if (uid == null) return const ExamPlan.empty();

  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

  DocumentSnapshot<Map<String, dynamic>>? doc;
  try {
    doc = await docRef.get(const GetOptions(source: Source.server));
  } catch (_) {
    try {
      doc = await docRef.get(const GetOptions(source: Source.cache));
    } catch (_) {
      doc = null;
    }
  }

  final data = doc?.data();
  return ExamPlan(
    dates: parseExamDates(data),
    debriefed: parseDebriefed(data),
  );
});

/// Exam id -> the day of that paper, at local midnight. Derived, so the card
/// keeps a simple dependency and the document is still only read once.
final examDatesProvider = FutureProvider<Map<String, DateTime>>(
  (ref) async => (await ref.watch(examPlanProvider.future)).dates,
);

/// Pulls `examDates` out of a user document.
///
/// Separated from the Firestore read so the parsing can be tested, and
/// deliberately forgiving: a document written by an older build, or by hand
/// in the console, should never crash the home screen. Anything that is not
/// a usable date is simply dropped.
Map<String, DateTime> parseExamDates(Map<String, dynamic>? data) {
  final raw = data?['examDates'];
  if (raw is! Map) return {};

  final out = <String, DateTime>{};
  raw.forEach((key, value) {
    final id = key?.toString();
    if (id == null || id.isEmpty) return;

    DateTime? when;
    if (value is Timestamp) {
      when = value.toDate();
    } else if (value is DateTime) {
      when = value;
    } else if (value is String) {
      when = DateTime.tryParse(value);
    } else if (value is int) {
      // Milliseconds since epoch, which is what a hand-written entry or a
      // JSON import is most likely to contain.
      when = DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (when == null) return;

    // Normalise to local midnight. The time of day on a test date is noise:
    // keeping it would make two dates on the same day compare unequal and
    // would leak into the day arithmetic.
    out[id] = DateTime(when.year, when.month, when.day);
  });
  return out;
}

/// Pulls the set of sittings already asked about out of a user document.
///
/// Stored as a map rather than an array because a map merges: two devices
/// writing different keys both survive, where an array write would have one
/// overwrite the other.
Set<String> parseDebriefed(Map<String, dynamic>? data) {
  final raw = data?['examDebriefs'];
  if (raw is! Map) return {};
  return raw.keys
      .map((k) => k?.toString() ?? '')
      .where((k) => k.isNotEmpty)
      .toSet();
}

/// Writes one exam's date, or clears it when [date] is null.
///
/// Either way only that one exam's entry is touched, never the whole map, so
/// a date set on another device in between is not overwritten.
///
/// The two paths differ because Firestore treats them differently. A write
/// merges a nested map, which also creates `examDates` when the user document
/// predates the field. A clear needs a dotted field path, since
/// `FieldValue.delete()` has to name the field it removes.
Future<void> saveExamDate({
  required String uid,
  required String examId,
  required DateTime? date,
}) async {
  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

  if (date == null) {
    await docRef.update({'examDates.$examId': FieldValue.delete()});
    return;
  }

  await docRef.set({
    'examDates': {
      examId: Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
    },
  }, SetOptions(merge: true));
}

/// Records what a student said about a paper they have sat.
///
/// Two writes, deliberately. The marker on the user document is what stops
/// them being asked twice, and it goes in whether or not they typed anything.
/// The content goes to the same `feedback` collection the feedback screen
/// uses, tagged so it can be told apart — a student venting about a paper is
/// feedback, it belongs where feedback is already read, and reusing that
/// collection means no new security rules.
///
/// The marker is written first and on its own. If the content write fails,
/// the student is not asked again, which is the right way round: being asked
/// twice about a bad exam is worse than losing one message.
Future<void> saveExamDebrief({
  required String uid,
  required String examId,
  required DateTime examDate,
  required String debriefKey,
  required String mood,
  required String note,
  String? displayName,
  String? email,
  String? appVersion,
}) async {
  final db = FirebaseFirestore.instance;

  await db.collection('users').doc(uid).set({
    'examDebriefs': {debriefKey: FieldValue.serverTimestamp()},
  }, SetOptions(merge: true));

  await db.collection('feedback').add({
    'kind': 'exam_debrief',
    'userId': uid,
    'displayName': displayName ?? '',
    'email': email ?? '',
    'exam': examId,
    'examDate': Timestamp.fromDate(examDate),
    'mood': mood,
    'message': note,
    'timestamp': FieldValue.serverTimestamp(),
    if (appVersion != null) 'appVersion': appVersion,
  });
}
