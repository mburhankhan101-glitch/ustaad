import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaad/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
// LAUNCH SWITCH — flip this ONE line when RevenueCat is wired
// false → users are never blocked (soft launch, tracking still works)
// true  → gates are active, users hit paywall when limits exceeded
// ════════════════════════════════════════════════════════════════════════════
const bool _paymentsLive = false; // TODO: set to true after RevenueCat launch

// ═══════════════════════════════════════════════════════════════════════════════
// credits_provider.dart — Ustaad
//
// Single source of truth for plan type and credit balance.
// Used by ProfileScreen (plan card), ExplanationSheet, QuizScreen,
// PaperDetailScreen — anywhere a feature needs to be gated.
//
// FLOW:
//  1. creditsProvider streams the user's Firestore doc → UserCredits model
//  2. Any screen calls ref.watch(creditsProvider) to read state
//  3. Before any gated action, call CreditService.consume*() to check & deduct
//  4. CreditService writes back to Firestore → stream fires → UI updates
//
// AUTO-INIT:
//  If a user doc has no credit fields (existing users before this was built),
//  initCreditsIfNeeded() writes the defaults once. Called from the stream.
// ═══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum UserPlan { free, pro }

// ─────────────────────────────────────────────────────────────────────────────
// UserCredits MODEL
// ─────────────────────────────────────────────────────────────────────────────

class UserCredits {
  final int credits;
  final UserPlan plan;
  final DateTime? planExpiry;

  // Daily usage (resets when date changes)
  final int quizzesToday;
  final String quizzesDate;

  // Monthly usage (resets when month changes)
  final int papersThisMonth;
  final String papersMonth;

  // Lifetime AI explanation counter for free tier
  final int aiExplanationsToday;
  final String aiExplanationsDate;

  const UserCredits({
    required this.credits,
    required this.plan,
    this.planExpiry,
    required this.quizzesToday,
    required this.quizzesDate,
    required this.papersThisMonth,
    required this.papersMonth,
    required this.aiExplanationsToday,
    required this.aiExplanationsDate,
  });

  // ── Computed getters ──────────────────────────────────────────────────────

  /// True if on Pro plan AND plan hasn't expired
  bool get isPro {
    if (plan != UserPlan.pro) return false;
    if (planExpiry == null) return true; // no expiry = lifetime
    return planExpiry!.isAfter(DateTime.now());
  }

  /// Today's date string in yyyy-MM-dd format
  static String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// This month's string in yyyy-MM format
  static String get _monthStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Effective AI uses today (reset to 0 if date changed)
  int get effectiveAiToday =>
      aiExplanationsDate == _todayStr ? aiExplanationsToday : 0;

  /// Effective quizzes today (reset to 0 if date changed)
  int get effectiveQuizzesToday => quizzesDate == _todayStr ? quizzesToday : 0;

  /// Effective papers this month (reset to 0 if month changed)
  int get effectivePapersThisMonth =>
      papersMonth == _monthStr ? papersThisMonth : 0;

  // ── Permission checks — used by gated screens ─────────────────────────────
  // When _paymentsLive is false, all checks return true so no student
  // is ever blocked before payments are properly integrated.
  // Tracking and credit deduction still happen regardless — data is real.

  /// Can the user view an AI explanation right now?
  bool get canUseAI {
    if (!_paymentsLive) return true; // ← soft launch: always allowed
    if (isPro) return true;
    if (effectiveAiToday < CreditCosts.aiFreePerDay) return true;
    return credits >= CreditCosts.aiPerCredit;
  }

  /// Can the user start a quiz session right now?
  bool get canStartQuiz {
    if (!_paymentsLive) return true; // ← soft launch: always allowed
    if (isPro) return true;
    if (effectiveQuizzesToday < CreditCosts.quizFreePerDay) return true;
    return credits >= CreditCosts.quizCredits;
  }

  /// Can the user start a full paper right now?
  bool get canStartPaper {
    if (!_paymentsLive) return true; // ← soft launch: always allowed
    if (isPro) return true;
    if (effectivePapersThisMonth < CreditCosts.paperFreePerMonth) return true;
    return credits >= CreditCosts.paperCredits;
  }

  // ── Human-readable reason strings (shown in paywall dialogs) ──────────────

  String get aiBlockReason => isPro
      ? ''
      : effectiveAiToday >= CreditCosts.aiFreePerDay
      ? 'You\'ve used your ${CreditCosts.aiFreePerDay} free AI explanations today.'
      : '';

  String get quizBlockReason => isPro
      ? ''
      : effectiveQuizzesToday >= CreditCosts.quizFreePerDay
      ? 'You\'ve done ${CreditCosts.quizFreePerDay} free quizzes today.'
      : '';

  String get paperBlockReason => isPro
      ? ''
      : effectivePapersThisMonth >= CreditCosts.paperFreePerMonth
      ? 'You\'ve used your ${CreditCosts.paperFreePerMonth} free papers this month.'
      : '';

  // ── Factory: build from Firestore document map ─────────────────────────────

  factory UserCredits.fromMap(Map<String, dynamic> data) {
    return UserCredits(
      credits: (data['credits'] as num?)?.toInt() ?? 0,
      plan: data['plan'] == 'pro' ? UserPlan.pro : UserPlan.free,
      planExpiry: data['planExpiry'] != null
          ? (data['planExpiry'] as Timestamp).toDate()
          : null,
      quizzesToday: (data['quizzesToday'] as num?)?.toInt() ?? 0,
      quizzesDate: data['quizzesDate'] as String? ?? '',
      papersThisMonth: (data['papersThisMonth'] as num?)?.toInt() ?? 0,
      papersMonth: data['papersMonth'] as String? ?? '',
      aiExplanationsToday: (data['aiExplanationsToday'] as num?)?.toInt() ?? 0,
      aiExplanationsDate: data['aiExplanationsDate'] as String? ?? '',
    );
  }

  /// Default value for a brand-new user or when doc has no credit fields
  factory UserCredits.empty() {
    return const UserCredits(
      credits: 0,
      plan: UserPlan.free,
      planExpiry: null,
      quizzesToday: 0,
      quizzesDate: '',
      papersThisMonth: 0,
      papersMonth: '',
      aiExplanationsToday: 0,
      aiExplanationsDate: '',
    );
  }

  @override
  String toString() =>
      'UserCredits(plan: $plan, credits: $credits, '
      'ai: $effectiveAiToday/${CreditCosts.aiFreePerDay}, '
      'quiz: $effectiveQuizzesToday/${CreditCosts.quizFreePerDay}, '
      'papers: $effectivePapersThisMonth/${CreditCosts.paperFreePerMonth})';
}

// ─────────────────────────────────────────────────────────────────────────────
// CREDIT COSTS — change prices here, nowhere else
// ─────────────────────────────────────────────────────────────────────────────

class CreditCosts {
  CreditCosts._(); // not instantiable

  // Free tier daily/monthly allowances
  static const int aiFreePerDay = 5;
  static const int quizFreePerDay = 10;
  static const int paperFreePerMonth = 2;

  // Credit costs when free tier is exhausted
  static const int aiPerCredit = 1; // 1 credit per AI explanation
  static const int quizCredits = 5; // 5 credits per extra quiz session
  static const int paperCredits = 5; // 5 credits per extra paper
}

// ─────────────────────────────────────────────────────────────────────────────
// CREDITS PROVIDER — real-time stream from Firestore
// ─────────────────────────────────────────────────────────────────────────────

/// Streams the current user's credit/plan state.
/// Returns [UserCredits.empty()] when signed out or on any error.
///
/// Usage:
/// ```dart
/// final credits = ref.watch(creditsProvider).value ?? UserCredits.empty();
/// if (!credits.canStartQuiz) { /* show paywall */ }
/// ```
final creditsProvider = StreamProvider<UserCredits>((ref) {
  // Listens to auth changes — if user signs out, stream switches to empty
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return Stream.value(UserCredits.empty());
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .asyncMap((snap) async {
        final data = snap.data();

        // ── Auto-init: if credit fields are missing, write defaults once ────────
        // This handles existing users created before the credit system existed.
        if (data != null && !data.containsKey('credits')) {
          await CreditService._initCreditsForUser(user.uid);
          // Return empty for now — the next snapshot from the write above will
          // carry the real values and fire immediately
          return UserCredits.empty();
        }

        return data != null ? UserCredits.fromMap(data) : UserCredits.empty();
      });
});

// ─────────────────────────────────────────────────────────────────────────────
// CREDIT SERVICE — all write operations (consume, add, init)
// ─────────────────────────────────────────────────────────────────────────────

class CreditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  CreditService(this.uid);

  // ── AI Explanation ─────────────────────────────────────────────────────────

  /// Call this BEFORE making the Gemini API call.
  /// Returns true if allowed (and deducts credits if needed).
  /// Returns false if the user is out of free uses and credits.
  Future<bool> consumeForAI(UserCredits current) async {
    if (!_paymentsLive)
      return true; // soft launch: no writes, no deduction, no locking
    if (current.isPro) return true;

    final today = UserCredits._todayStr;

    // Still has free uses today
    if (current.effectiveAiToday < CreditCosts.aiFreePerDay) {
      await _db.collection('users').doc(uid).set({
        'aiExplanationsToday': FieldValue.increment(1),
        'aiExplanationsDate': today,
      }, SetOptions(merge: true));
      print(
        '⚡ USTAAD Credits: AI used (free tier) — '
        '${current.effectiveAiToday + 1}/${CreditCosts.aiFreePerDay} today',
      );
      return true;
    }

    // Free tier exhausted — spend credits
    if (current.credits >= CreditCosts.aiPerCredit) {
      await _db.collection('users').doc(uid).set({
        'credits': FieldValue.increment(-CreditCosts.aiPerCredit),
        'aiExplanationsToday': FieldValue.increment(1),
        'aiExplanationsDate': today,
      }, SetOptions(merge: true));
      print(
        '⚡ USTAAD Credits: AI used (${CreditCosts.aiPerCredit} credit) — '
        '${current.credits - CreditCosts.aiPerCredit} remaining',
      );
      return true;
    }

    print('🔒 USTAAD Credits: AI blocked — no free uses or credits');
    return false;
  }

  // ── Quiz Session ───────────────────────────────────────────────────────────

  /// Call this BEFORE navigating to QuizScreen.
  Future<bool> consumeForQuiz(UserCredits current) async {
    if (!_paymentsLive)
      return true; // soft launch: no writes, no deduction, no locking
    if (current.isPro) {
      await _incrementQuizCount();
      return true;
    }

    final today = UserCredits._todayStr;

    if (current.effectiveQuizzesToday < CreditCosts.quizFreePerDay) {
      await _db.collection('users').doc(uid).set({
        'quizzesToday': FieldValue.increment(1),
        'quizzesDate': today,
      }, SetOptions(merge: true));
      print(
        '⚡ USTAAD Credits: Quiz used (free tier) — '
        '${current.effectiveQuizzesToday + 1}/${CreditCosts.quizFreePerDay} today',
      );
      return true;
    }

    if (current.credits >= CreditCosts.quizCredits) {
      await _db.collection('users').doc(uid).set({
        'credits': FieldValue.increment(-CreditCosts.quizCredits),
        'quizzesToday': FieldValue.increment(1),
        'quizzesDate': today,
      }, SetOptions(merge: true));
      print(
        '⚡ USTAAD Credits: Quiz used (${CreditCosts.quizCredits} credits) — '
        '${current.credits - CreditCosts.quizCredits} remaining',
      );
      return true;
    }

    print('🔒 USTAAD Credits: Quiz blocked — no free sessions or credits');
    return false;
  }

  // ── Full Paper ─────────────────────────────────────────────────────────────

  /// Call this BEFORE starting a full timed paper.
  Future<bool> consumeForPaper(UserCredits current) async {
    if (!_paymentsLive)
      return true; // soft launch: no writes, no deduction, no locking
    if (current.isPro) {
      await _incrementPaperCount();
      return true;
    }

    final month = UserCredits._monthStr;

    if (current.effectivePapersThisMonth < CreditCosts.paperFreePerMonth) {
      await _db.collection('users').doc(uid).set({
        'papersThisMonth': FieldValue.increment(1),
        'papersMonth': month,
      }, SetOptions(merge: true));
      print(
        '⚡ USTAAD Credits: Paper used (free tier) — '
        '${current.effectivePapersThisMonth + 1}/${CreditCosts.paperFreePerMonth} this month',
      );
      return true;
    }

    if (current.credits >= CreditCosts.paperCredits) {
      await _db.collection('users').doc(uid).set({
        'credits': FieldValue.increment(-CreditCosts.paperCredits),
        'papersThisMonth': FieldValue.increment(1),
        'papersMonth': month,
      }, SetOptions(merge: true));
      print(
        '⚡ USTAAD Credits: Paper used (${CreditCosts.paperCredits} credits) — '
        '${current.credits - CreditCosts.paperCredits} remaining',
      );
      return true;
    }

    print('🔒 USTAAD Credits: Paper blocked — no free papers or credits');
    return false;
  }

  // ── Add Credits (called after RevenueCat purchase confirms) ───────────────

  /// Add [amount] credits to the user's wallet.
  /// Call this from your purchase success callback.
  Future<void> addCredits(int amount) async {
    await _db.collection('users').doc(uid).set({
      'credits': FieldValue.increment(amount),
      'totalCreditsEarned': FieldValue.increment(amount),
    }, SetOptions(merge: true));
    print('💰 USTAAD Credits: +$amount credits added for uid=$uid');
  }

  /// Upgrade user to Pro plan for [days] days.
  /// Call this from your RevenueCat subscription purchase callback.
  Future<void> activateProPlan({int days = 30}) async {
    final expiry = DateTime.now().add(Duration(days: days));
    await _db.collection('users').doc(uid).set({
      'plan': 'pro',
      'planExpiry': Timestamp.fromDate(expiry),
    }, SetOptions(merge: true));
    print(
      '🌟 USTAAD Credits: Pro activated for uid=$uid — expires ${expiry.toIso8601String()}',
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _incrementQuizCount() async {
    await _db.collection('users').doc(uid).set({
      'quizzesToday': FieldValue.increment(1),
      'quizzesDate': UserCredits._todayStr,
    }, SetOptions(merge: true));
  }

  Future<void> _incrementPaperCount() async {
    await _db.collection('users').doc(uid).set({
      'papersThisMonth': FieldValue.increment(1),
      'papersMonth': UserCredits._monthStr,
    }, SetOptions(merge: true));
  }

  // ── Auto-init (called internally from creditsProvider stream) ─────────────

  /// Writes default credit fields for users who existed before this system.
  /// Safe to call multiple times — uses merge so it never overwrites real data.
  static Future<void> _initCreditsForUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'credits': 15, // welcome gift of 15 credits
        'totalCreditsEarned': 15,
        'plan': 'free',
        'planExpiry': null,
        'quizzesToday': 0,
        'quizzesDate': '',
        'papersThisMonth': 0,
        'papersMonth': '',
        'aiExplanationsToday': 0,
        'aiExplanationsDate': '',
      }, SetOptions(merge: true));
      print('✅ USTAAD Credits: Initialised for uid=$uid (15 welcome credits)');
    } catch (e) {
      print('🔴 USTAAD Credits: Init failed for uid=$uid — $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Provides a [CreditService] for the currently signed-in user.
/// Throws if called when no user is signed in — guard with currentUserProvider.
final creditServiceProvider = Provider<CreditService>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null)
    throw StateError('creditServiceProvider: no user signed in');
  return CreditService(user.uid);
});
