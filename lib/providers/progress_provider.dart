import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Auth state ───────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ─── User progress stream ─────────────────────────────────────────────────────
// Listens to the user's Firestore doc in real-time.
// Automatically resets when the user changes (logout/login).

final userProgressProvider = StreamProvider<Map<String, dynamic>?>((
  ref,
) async* {
  final user = ref.watch(authStateProvider).value;

  if (user == null) {
    yield null;
    return;
  }

  await user.getIdToken(true);
  await Future.delayed(const Duration(milliseconds: 500));

  yield* FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

// ─── Streak updater ───────────────────────────────────────────────────────────
// Call this at the end of every quiz session or paper submission.
//
// Logic:
//   - Same day as lastActiveDate  → already counted, do nothing
//   - Yesterday                   → streak += 1, update date
//   - Any older date / never set  → streak resets to 1 (today counts)
//   - Also keeps longestStreak up to date

Future<void> updateStreak() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final snapshot = await doc.get();
  final data = snapshot.data() ?? {};

  final today = _dateString(DateTime.now());
  final lastActive = data['lastActiveDate'] as String? ?? '';
  final currentStreak = data['streak'] as int? ?? 0;
  final longestStreak = data['longestStreak'] as int? ?? 0;

  // Already practiced today — nothing to update
  if (lastActive == today) return;

  final yesterday = _dateString(
    DateTime.now().subtract(const Duration(days: 1)),
  );
  final int newStreak = lastActive == yesterday
      ? currentStreak +
            1 // kept the chain alive
      : 1; // missed a day (or first ever session), reset to 1

  final int newLongest = newStreak > longestStreak ? newStreak : longestStreak;

  await doc.set({
    'streak': newStreak,
    'lastActiveDate': today,
    'longestStreak': newLongest,
  }, SetOptions(merge: true));
  // merge: true so we never wipe totalSolved, accuracy, progress etc.
}

// ─── Streak message helper ────────────────────────────────────────────────────
// Returns a Roman Urdu message based on the streak count and whether the
// student missed yesterday (streakBroken = streak was >0 but reset to 0).
//
// Usage in HomeScreen:
//   final msg = streakMessage(streak, lastActiveDate);

StreakMessage streakMessage(int streak, String lastActiveDate) {
  final yesterday = _dateString(
    DateTime.now().subtract(const Duration(days: 1)),
  );
  final today = _dateString(DateTime.now());

  // Practiced today already
  final bool practicedToday = lastActiveDate == today;
  // Had a streak going but missed yesterday (streak now shows old value
  // before reset — UI calls this after reading Firestore, so if streak
  // is 0 and lastActiveDate is not today/yesterday, it was broken)
  final bool streakBroken =
      streak == 0 &&
      lastActiveDate.isNotEmpty &&
      lastActiveDate != today &&
      lastActiveDate != yesterday;

  if (streak == 0 && lastActiveDate.isEmpty) {
    // Brand new user, never practiced
    return const StreakMessage(
      emoji: '👀',
      text: 'Pehli baar? Shuru tou karo yaar.',
      isRoast: false,
    );
  }

  if (streakBroken) {
    // Had activity before but missed a day — roast them
    final roasts = [
      'Streak gayi tel lene. NUST khud qualify karega kya?',
      'Kal soye rahe aur streak le dobi. Wah bhai wah.',
      'Ek din chhuti li aur sab khatam. Classic.',
      'Consistency ka janaza nikal diya. Dobara shuru karo.',
    ];
    // Pick based on day of week so it feels random but is deterministic
    final msg = roasts[DateTime.now().weekday % roasts.length];
    return StreakMessage(emoji: '💀', text: msg, isRoast: true);
  }

  if (streak == 1 && !practicedToday) {
    return const StreakMessage(
      emoji: '🌱',
      text: 'Pehla din. Dekhtay hain kal bhi aate ho ya nahi.',
      isRoast: false,
    );
  }

  if (streak == 1 && practicedToday) {
    return const StreakMessage(
      emoji: '🌱',
      text: 'Aaj ka din ho gaya. Kal mat bhaagna.',
      isRoast: false,
    );
  }

  if (streak >= 2 && streak <= 4) {
    return StreakMessage(
      emoji: '🔥',
      text: '$streak din ho gaye. Bura nahi — abhi tak tou.',
      isRoast: false,
    );
  }

  if (streak >= 5 && streak <= 6) {
    return const StreakMessage(
      emoji: '⚡',
      text: 'Paanch din! Machine ban raha hai yaar.',
      isRoast: false,
    );
  }

  if (streak == 7) {
    return const StreakMessage(
      emoji: '🏆',
      text: 'Ek hafta poora! Seedha FAST ka form bharo.',
      isRoast: false,
    );
  }

  if (streak >= 8 && streak <= 13) {
    return StreakMessage(
      emoji: '🚀',
      text: '$streak din! Seriously yaar, tu toh serious hai.',
      isRoast: false,
    );
  }

  if (streak == 14) {
    return const StreakMessage(
      emoji: '👑',
      text: 'Do hafte! Apna ustaad khud ban gaya.',
      isRoast: false,
    );
  }

  if (streak >= 15 && streak <= 29) {
    return StreakMessage(
      emoji: '🤖',
      text: '$streak din bhai. Tu insaan hai ya algorithm?',
      isRoast: false,
    );
  }

  // 30+ days — absolute legend
  return StreakMessage(
    emoji: '🦅',
    text: '$streak din. Beta FAST mein seat pakki samjho.',
    isRoast: false,
  );
}

// ─── StreakMessage model ──────────────────────────────────────────────────────

class StreakMessage {
  final String emoji;
  final String text;
  final bool isRoast; // true = show in red/coral, false = show in gold/green

  const StreakMessage({
    required this.emoji,
    required this.text,
    required this.isRoast,
  });
}

// ─── Private helpers ──────────────────────────────────────────────────────────

String _dateString(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
