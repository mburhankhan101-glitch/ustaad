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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/auth_provider.dart';

/// Exam id -> the day of that paper, at local midnight.
final examDatesProvider = FutureProvider<Map<String, DateTime>>((ref) async {
  final uid = ref.watch(authProvider).user?.uid;
  if (uid == null) return {};

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

  return parseExamDates(doc?.data());
});

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
