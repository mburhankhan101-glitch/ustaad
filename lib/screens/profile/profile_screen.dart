import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaad/core/notifications/reminder_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ustaad/core/analytics/analytics_service.dart';
import 'package:ustaad/providers/credits_provider.dart';
import 'package:ustaad/screens/feedback/feedback_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:ustaad/providers/progress_provider.dart';
import 'package:ustaad/providers/user_selection_provider.dart';
import 'package:ustaad/screens/plans/plans_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ustaad/screens/auth/test_selection.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ustaad/services/account_deletion_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final firstName = _getFirstName(user?.displayName);
    final initials = _getInitials(user?.displayName);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF6C63FF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),

                // ── 1. Header ────────────────────────────────────────────────
                _buildProfileHeader(firstName, initials),

                const SizedBox(height: 20),
                _buildPlanCard(context, ref),
                const SizedBox(height: 24),

                // ── Account ──────────────────────────────────────────────────
                _buildSectionLabel('Account'),
                const SizedBox(height: 10),
                _buildInfoCard(user),

                const SizedBox(height: 24),

                // ── Management ───────────────────────────────────────────────
                _buildSectionLabel('Management'),
                const SizedBox(height: 10),
                _buildMenuCard(context, [
                  _MenuItem(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Change Exam & Degree',
                    onTap: () => _changeTestAndDegree(context, ref),
                  ),
                  _MenuItem(
                    icon: Icons.feedback_outlined,
                    label: 'Feedback',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Community ────────────────────────────────────────────────
                _buildSectionLabel('Community'),
                const SizedBox(height: 10),
                _buildMenuCard(context, [
                  _MenuItem(
                    icon: Icons.camera_alt_outlined,
                    label: 'Follow Ustaad on Instagram',
                    onTap: () => _launchInstagram(context),
                    trailingIcon: Icons.open_in_new_rounded,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Legal ────────────────────────────────────────────────────
                _buildSectionLabel('Legal'),
                const SizedBox(height: 10),
                _buildMenuCard(context, [
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => _launchPrivacyPolicy(context),
                    trailingIcon: Icons.open_in_new_rounded,
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Danger Zone ──────────────────────────────────────────────
                // Same tile treatment as every other row on this screen. The
                // weight sits in the two-step confirm and the re-auth, not in
                // making the row look alarming.
                _buildSectionLabel('Danger Zone'),
                const SizedBox(height: 10),
                _buildMenuCard(context, [
                  _MenuItem(
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete My Account',
                    onTap: () => _confirmDeleteAccount(context, ref),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Logout ───────────────────────────────────────────────────
                _buildLogoutButton(ref, context),

                const SizedBox(height: 12),
                _buildVersionTag(),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────── HEADER ──────────────────────────────────────
  Widget _buildProfileHeader(String firstName, String initials) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B7FFF), Color(0xFF6C63FF)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.20), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.55),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ustaad • Free Plan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────── PLAN CARD ───────────────────────────────────
  Widget _buildPlanCard(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsProvider);
    final credits = creditsAsync.value ?? UserCredits.empty();
    return _buildPlanCardContent(
      context,
      credits.isPro ? 'pro' : 'free',
      credits.credits,
    );
  }

  Widget _buildPlanCardContent(BuildContext context, String plan, int credits) {
    final isPro = plan == 'pro';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.11)),
      ),
      child: Column(
        children: [
          // ── Row 1: Plan label + Upgrade button ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // Plan badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isPro
                        ? const Color(0xFFFFD700).withOpacity(0.18)
                        : Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPro
                          ? const Color(0xFFFFD700).withOpacity(0.50)
                          : Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPro
                            ? Icons.auto_awesome_rounded
                            : Icons.person_rounded,
                        size: 13,
                        color: isPro
                            ? const Color(0xFFFFD700)
                            : Colors.white.withOpacity(0.70),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isPro ? 'Pro' : 'Basic',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isPro ? const Color(0xFFFFD700) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Upgrade button — hidden if already Pro
                if (!isPro)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlansScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C8DFF), Color(0xFF6C63FF)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          Divider(height: 1, color: Colors.white.withOpacity(0.07)),

          // ── Row 2: Credits ───────────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlansScreen()),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFFFD700),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Credits',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: Colors.white.withOpacity(0.35),
                    ),
                    const Spacer(),
                    Text(
                      '$credits',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white.withOpacity(0.40),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── SECTION LABEL ───────────────────────────────
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.40),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ────────────────────────── ACCOUNT INFO CARD ───────────────────────────
  Widget _buildInfoCard(user) {
    final uid = user?.uid;

    if (uid == null) {
      return _buildInfoCardContent(user, null, null);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final tests = (data?['selectedTests'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final degreeId = data?['targetDegree'] as String?;
        return _buildInfoCardContent(user, tests, degreeId);
      },
    );
  }

  Widget _buildInfoCardContent(user, List<String>? tests, String? degreeId) {
    const degreeLabels = {
      'cs_se': 'CS / Software Engineering',
      'electrical_mechanical': 'Electrical / Mechanical Engg',
      'business': 'Business & Management',
      'fintech': 'FinTech & Finance',
      'data_ai': 'Data Science / AI',
    };

    final examValue = (tests == null || tests.isEmpty)
        ? 'Not set'
        : tests.join(' · ');

    final degreeValue = degreeId == null
        ? 'Not set'
        : (degreeLabels[degreeId] ?? degreeId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.11)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Name',
            value: user?.displayName ?? 'Not set',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user?.email ?? 'Not set',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.school_outlined,
            label: 'Exam Prep',
            value: examValue,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.auto_awesome_rounded,
            label: 'Target Degree',
            value: degreeValue,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.verified_outlined,
            label: 'Email Status',
            value: (user?.emailVerified ?? false) ? 'Verified ✓' : 'Unverified',
            valueColor: (user?.emailVerified ?? false)
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF6B6B),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF9C8DFF), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.42),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── MENU CARD ───────────────────────────────────
  Widget _buildMenuCard(BuildContext context, List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.11)),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          BorderRadius inkRadius;
          if (items.length == 1) {
            inkRadius = BorderRadius.circular(18);
          } else if (i == 0) {
            inkRadius = const BorderRadius.vertical(top: Radius.circular(18));
          } else if (i == items.length - 1) {
            inkRadius = const BorderRadius.vertical(
              bottom: Radius.circular(18),
            );
          } else {
            inkRadius = BorderRadius.zero;
          }
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: inkRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.icon,
                            color: const Color(0xFF9C8DFF),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(
                          item.trailingIcon ?? Icons.chevron_right_rounded,
                          color: Colors.white.withOpacity(0.28),
                          size: item.trailingIcon != null ? 16 : 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (i < items.length - 1) _buildDivider(),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDivider() => Divider(
    height: 1,
    color: Colors.white.withOpacity(0.07),
    indent: 18,
    endIndent: 18,
  );

  // ────────────────────────── LOGOUT ──────────────────────────────────────
  Widget _buildLogoutButton(WidgetRef ref, BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context, ref),
        icon: const Icon(
          Icons.logout_rounded,
          color: Color(0xFFFF6B6B),
          size: 20,
        ),
        label: const Text(
          'Log Out',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFF6B6B),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of Ustaad?',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log Out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF6B6B),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.invalidate(userProgressProvider);
      // The reminder is armed on the device, not the account, so signing out
      // does not clear it. Without this, someone who signs out keeps being
      // told their streak is about to break.
      await ReminderService.instance.cancelAll();
      await ref.read(authProvider.notifier).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  // ────────────────────────── DELETE ACCOUNT ──────────────────────────────
  // Google Play requires an in-app deletion path for any app that offers
  // account creation. Three steps, in this order:
  //   1. confirm, spelling out exactly what goes
  //   2. re-authenticate, because Firebase refuses delete() on a stale
  //      credential and finding that out later would strand a half-deleted
  //      account
  //   3. delete Firestore data, then the auth user
  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final service = AccountDeletionService();

    // Captured before the first await. Deleting the account flips the app to
    // unauthenticated, and this widget can be deactivated in the rebuild that
    // follows — which is what made the old `context.mounted` guard false and
    // silently skipped the trip to the login screen, leaving the profile
    // rendered with its null-user "Student" placeholder.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Captured with the others: the auth state flips partway through, so
    // the context is not safe to read by the time we need to navigate.
    final router = GoRouter.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete account permanently?',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Everything will be permanently deleted:\n\n'
          '•  Your account and login\n'
          '•  Your streak and daily goals\n'
          '•  Your progress and accuracy\n'
          '•  Your quiz and paper history\n\n'
          'This cannot be undone and we cannot restore it later. '
          'You will be signed out straight away.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            height: 1.55,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete forever',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF6B6B),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // ── Step 2: prove it is really them, but only if Firebase insists ─────
    // The first version prompted every time, so someone who had signed in a
    // minute earlier still got an unexplained Google account picker. Now the
    // picker appears only when the credential is genuinely too old.
    if (service.needsRecentLogin) {
      final ok = await _reauthenticate(context, service);
      if (!ok) return; // cancelled, or could not verify
    }

    if (!context.mounted) return;

    // ── Step 3: delete ────────────────────────────────────────────────────
    _showSpinner(context);

    try {
      await service.deleteUserData();

      try {
        await service.deleteAuthUser();
      } on FirebaseAuthException catch (e) {
        // Rare: the credential went stale between the check and here. The data
        // is already gone, so finish the job rather than stranding an empty
        // account — ask for the credential once more and retry.
        if (e.code != 'requires-recent-login') rethrow;

        navigator.pop(); // close spinner while the picker is up
        if (!context.mounted) return;
        final ok = await _reauthenticate(context, service);
        if (!ok) {
          messenger.showSnackBar(
            _errorSnack('Sign in again to finish deleting your account.'),
          );
          return;
        }
        if (context.mounted) _showSpinner(context);
        await service.deleteAuthUser();
      }

      // Deleting the auth user flips the app to unauthenticated, which can
      // deactivate this widget. Everything from here uses the navigator and
      // messenger captured before the first await, never `context`.
      navigator.pop(); // close spinner

      // Logged before the user id is cleared on sign out, otherwise the event
      // lands with no one attached and the deletion rate is unreadable.
      await Analytics.instance.accountDeleted();

      ref.invalidate(userProgressProvider);
      await ReminderService.instance.cancelAll();
      await ref.read(authProvider.notifier).signOut();

      router.go('/login');
    } catch (e) {
      navigator.pop(); // close spinner
      messenger.showSnackBar(
        _errorSnack('Could not delete your account. Try again.'),
      );
      debugPrint('[Ustaad] Account deletion failed: $e');
    }
  }

  void _showSpinner(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF9C8DFF)),
      ),
    );
  }

  /// Returns true only if the user proved who they are.
  Future<bool> _reauthenticate(
    BuildContext context,
    AccountDeletionService service,
  ) async {
    try {
      if (service.usesPassword) {
        final password = await _promptPassword(context);
        if (password == null) return false; // cancelled
        await service.reauthenticateWithPassword(password);
        return true;
      }
      if (service.usesGoogle) {
        return await service.reauthenticateWithGoogle();
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (context.mounted) _showError(context, _reauthMessage(e.code));
      return false;
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not verify your identity. Try again.');
      }
      return false;
    }
  }

  /// Password re-auth prompt. Returns null if the user backs out.
  Future<String?> _promptPassword(BuildContext context) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Password',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your password to confirm it is you.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.35),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF6B6B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _reauthMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'That password is not right.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Could not verify your identity. Try again.';
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(_errorSnack(message));
  }

  /// Built separately so it can be shown through a ScaffoldMessenger captured
  /// before an await, when the originating context may no longer be mounted.
  SnackBar _errorSnack(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFF6B6B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  /// Reads the real version off the bundle rather than carrying a literal.
  ///
  /// This line has now been wrong twice: it still said v1.2.0 while the app
  /// shipped 1.3.1, because a hardcoded version only stays right until the
  /// next release and nothing fails when it drifts. feedback_screen already
  /// moved to PackageInfo for the same reason; this is the last literal.
  Widget _buildVersionTag() => Center(
    child: FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        return Text(
          version == null
              ? 'Ustaad • Apna Ustaad'
              : 'Ustaad v$version • Apna Ustaad',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Colors.white.withOpacity(0.22),
          ),
        );
      },
    ),
  );

  String _getFirstName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Student';
    return name.trim().split(' ').first;
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'ST';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // ── Change Exam & Degree ─────────────────────────────────────────────────
  Future<void> _changeTestAndDegree(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Map<String, dynamic>? data;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      data = doc.data();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not load your current settings. Try again.',
            ),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    final currentTests =
        (data?['selectedTests'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final currentDegree = data?['targetDegree'] as String?;

    if (!context.mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TestSelectionScreen(
          isEditing: true,
          initialTests: currentTests,
          initialDegree: currentDegree,
        ),
      ),
    );

    if (!context.mounted) return;

    if (result == true) {
      ref.invalidate(userProgressProvider);
      ref.invalidate(selectedTestsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Exam & degree updated!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (result == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No changes made',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: const Color(0xFF6C63FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchInstagram(BuildContext context) async {
    final uri = Uri.parse('https://instagram.com/theustaadapp');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showLaunchError(context);
      }
    } catch (e) {
      if (context.mounted) {
        _showLaunchError(context);
      }
    }
  }

  Future<void> _launchPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse('https://ustaad-privacy.vercel.app/');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showLaunchError(context);
      }
    } catch (e) {
      if (context.mounted) {
        _showLaunchError(context);
      }
    }
  }

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'Could not open link',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─── Menu Item Model ──────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingIcon,
  });
}
