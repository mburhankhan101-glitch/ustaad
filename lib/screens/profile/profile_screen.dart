// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'package:ustaad/providers/progress_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      _buildAvatar(user?.displayName, user?.email),
                      const SizedBox(height: 32),
                      _buildInfoCard(user),
                      const SizedBox(height: 24),
                      _buildLogoutButton(ref, context),
                      const SizedBox(height: 40),
                      _buildVersionTag(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Text(
            'Profile',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? name, String? email) {
    final initials = _getInitials(name);

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9C8DFF)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name ?? 'Student',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email ?? '',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(user) {
    // You can pull selectedExam from Firestore later.
    // For now, show the fields we have from Firebase Auth.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
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
            value: 'FAST-NU', // TODO: pull from Firestore userModel
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
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

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.white.withOpacity(0.08),
      indent: 20,
      endIndent: 20,
    );
  }

  Widget _buildLogoutButton(WidgetRef ref, BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context, ref),
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B)),
        label: const Text(
          'Log Out',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
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
      // 1. Immediately invalidate progress and other providers
      ref.invalidate(userProgressProvider);

      // 2. Execute the sign-out from the notifier
      // This will trigger the AuthWrapper to switch to LoginScreen automatically
      await ref.read(authProvider.notifier).signOut();

      // 3. Clear the navigation stack to ensure no "Back" button to the profile exists
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  Widget _buildVersionTag() {
    return Text(
      'Ustaad v1.0.0 • Apna Ustaad',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: Colors.white.withOpacity(0.3),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'ST'; // 'ST' for Student

    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();

    // Grabs first and last name initials
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
