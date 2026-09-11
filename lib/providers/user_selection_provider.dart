// lib/providers/user_selection_provider.dart
//
// Exposes the current user's `selectedTests` (the exam IDs picked on
// TestSelectionScreen, e.g. ['FAST-NU', 'MDCAT']) so screens like
// PaperSelectionScreen can filter what they show without each doing their
// own Firestore read.
//
// IMPORTANT: this watches authProvider rather than reading
// FirebaseAuth.instance.currentUser directly. A bare currentUser read is
// invisible to Riverpod's dependency graph — the provider would cache its
// result on first run and never know to recompute when the logged-in user
// changes, silently leaking one account's selected tests into another
// account's session after a logout/login swap on the same device.
// ref.watch(authProvider) makes the uid a real tracked dependency, so
// Riverpod automatically reruns this provider when the user changes —
// no manual invalidate needed for the login/logout case (manual invalidate
// is still needed after ProfileScreen's edit flow, since that's a Firestore
// write this provider has no way to observe on its own).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/auth_provider.dart';

final selectedTestsProvider = FutureProvider<List<String>>((ref) async {
  final authState = ref.watch(authProvider);
  final uid = authState.user?.uid;
  if (uid == null) return [];

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  final data = doc.data();
  if (data == null) return [];

  return (data['selectedTests'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
      [];
});

/// True if the user's selected tests include any medical exam.
/// Medical (MDCAT/NUMS) and engineering/CS (FAST-NU/NUST-NET/NAT-NTS) are
/// treated as mutually exclusive buckets for now — see paper_selection_screen.
bool isMedicalSelection(List<String> selectedTests) {
  return selectedTests.contains('MDCAT') || selectedTests.contains('NUMS');
}
