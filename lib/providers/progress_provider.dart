import 'dart:math';

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
      'Kal soye rahe aur streak le dobi. Wah bhai wah.',
      'Ek din chhuti li aur sab khatam. Classic.',
      'Consistency ka janaza nikal diya...',
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
      text: '$streak din ho gaye. Shaabaash!😤.',
      isRoast: false,
    );
  }

  if (streak >= 5 && streak <= 6) {
    return StreakMessage(
      emoji: '⚡',
      text: '$streak din! Machine ban raha hai yaar.',
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

// ─── Greeting lines ───────────────────────────────────────────────────────────
// All lines use '[Name]' as placeholder — getGreeting() replaces it at runtime.
// Add more lines to any list freely; the random picker handles the rest.

const List<String> _morningLines = [
  'Uth bhi jao [Name], 5 baje Ustu bhi so raha hai, tum kyun jag rahe? Padhai karo.',
  'Chai pi li [Name]? Ab bahana khatam, FAST-NU nahi maanta neend.',
  'Good morning [Name], ghar walon ki umeed jagi ya abhi bhi snooze maar rahi?',
  '[Name] uth jao, Ustu bol raha hai aaj streak break nahi karni.',
  '[Name], ammi ne bulaya hoga "beta utho", main bol raha hoon "beta padho".',
  'Ustu ne bhi aankh kholi, ab tumhari baari hai hero.',
  'Morning [Name], kal wali taiyari aaj kaam aayegi ya phir se bhool gaye?',
  '[Name] uth jao, NET rank 1 nahi ayega aise.',
  '[Name] beta, neend chhodo, admission stress aa raha hai.',
  'Uth jao [Name], chai thandi ho rahi aur Ustu garam.',
  'Subah ka sabse bada jhoot: "bas 5 min aur". Ab utho.',
  '[Name], Ustu ready hai, tum bhi hojao ready.',
  'Morning [Name], competitive dost abhi padh rahe honge. Aur Tum?',
  '[Name] utho, aaj ka din waste mat karo.',
];

const List<String> _afternoonLines = [
  '[Name], reels se fursat milgayi ho toh padhai bhi shuru karlo.',
  '[Name], lunch ke baad Netflix ya Ustu? Sahi jawab pata hai 😏',
  'Chai break khatam [Name], Ustu intezar kar raha hai.',
  'Afternoon [Name], ghar walon ki umeed abhi bhi zinda hai kya?',
  '[Name], padho, NUST cutoff tumhara intezar nahi kar raha.',
  '[Name], dost ka message aaya "kitna ho gaya?" Kya jawab doge?',
  'Ustu bol raha: abhi bhi time hai, warna shaam ko rona.',
  'Dopahar ki neend le li? Ab guilt se padhai karo.',
  'Chai #3 ho gayi? Ab quiz #1 kholo yaar.',
  'Ustu watching you [Name], streak mat todna aaj.',
  'Bhai exam date nazdeek aa raha, tum door ja rahe.',
  '[Name], ab serious ho jao, mazak band.',
];

const List<String> _eveningLines = [
  'Shaam ho gayi [Name], ab ghar walay poochhenge "kitna padha?"',
  'Evening [Name], Ustu ka bolna: aaj thoda serious ban jao.',
  'Dost ne story daali "studying", tum daalo "sleeping". Tchtch.',
  '[Name], 7 bajh gaye, abhi bhi Quiz start nahi?',
  'Ghar walon ki umeed mat torro [Name], padho!',
  'Ustu bol raha hai aaj streak 10+ kar do [Name].',
  '[Name], ammi ne khana diya, ab padhai ka time.',
  'Bhai FAST pressure samajh rahe ho? Ya abhi bhi nahi?',
  'Evening [Name], competitive dost aage nikal rahe, tum?',
  '[Name], exam date pass aa raha, tum peeche.',
  'Shaam ho gayi yaar, ab mazaak nahi, kaam karo.',
];

const List<String> _nightLines = [
  'Raat ho gayi [Name], ab asli padhai shuru hoti hai.',
  'Night mode on? Ya sirf phone pe? Books kholo.',
  '[Name], ghar walay so gaye kya?, ab bahana nahi. Padho.',
  'Night [Name], NUST topper banne ka time aa gaya.',
  '[Name], abhi bhi "bas 10 min break"?',
  'Raat ka silence, padhai ka best time. Use it.',
  'Ustu watching, tum mat so jana [Name].',
  '[Name] bhai, family so rahi, tum mat so.',
  'Streak 7 days? Aaj 8 bana do hero.',
  'Raat [Name], sapne dekhne se pehle padh lo.',
  'Ustu bhi thak gaya [Name], lekin tumhare liye jag raha hai 🦉',
];

const List<String> _lateNightLines = [
  '[Name] bhai, 2 baje raat, ab toh padho warna Ustu bhi hassega.',
  'Late night [Name], neend haar rahi hai ya tum haar rahe?',
  'Ustu bhi so raha hota lekin tumhare liye jag raha. Padho.',
  '[Name], 3 baje, ab bahane nahi chalenge bhai.',
  'Raat ke 2, chai khatam, ab sirf padhai aur sapne.',
  '[Name], FAST-NU ke liye yeh sacrifice karna padta hai.',
  '[Name], ghar walay so rahe, tum topper ban rahe.',
  '1 baje raat, abhi bhi Instagram? Tchtch',
  'Late night [Name], exam date nazdeek, tum door mat jao.',
  'Neend aa rahi? Ustu sirf tumhare liye jaagha hua hai 🦉',
  'Raat ke andhere mein topper ban rahe ho na?',
  '[Name], ek last question. Ustu promise 🤞',
];

// ─── Greeting function ────────────────────────────────────────────────────────
// Returns a time-appropriate, randomized greeting with the user's first name.
//
// Usage in HomeScreen:
//   final greeting = getGreeting(firstName);
//
// Where to get firstName:
//   final data  = ref.watch(userProgressProvider).value;
//   final firstName = (data?['name'] as String? ?? 'Yaar').split(' ').first;

String getGreeting(String name) {
  final hour = DateTime.now().hour;
  final rng = Random();

  late List<String> pool;

  if (hour >= 5 && hour < 12) {
    pool = _morningLines;
  } else if (hour >= 12 && hour < 17) {
    pool = _afternoonLines;
  } else if (hour >= 17 && hour < 21) {
    pool = _eveningLines;
  } else if (hour >= 21 && hour < 24) {
    pool = _nightLines;
  } else {
    // 12am – 4:59am
    pool = _lateNightLines;
  }

  final raw = pool[rng.nextInt(pool.length)];
  return raw.replaceAll('[Name]', name);
}

// ─── Private helpers ──────────────────────────────────────────────────────────

String _dateString(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
