import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  // ← ConsumerStatefulWidget
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // ← ConsumerState
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Navigate based on Firestore data ──────────────────────────────────
  Future<void> _navigateAfterLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. CRITICAL CHECK: Is the email verified?
    if (!user.emailVerified) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/verify-email');
      return;
    }

    // 2. If verified, then check Firestore for test selection
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final hasSelectedTest = doc.exists && doc.data()?['selectedTests'] != null;

    if (hasSelectedTest) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/test_selection');
    }
  }

  // ── Email sign in ─────────────────────────────────────────────────────
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    // Clear any previous error before trying
    ref.read(authProvider.notifier).clearError();

    final success = await ref
        .read(authProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      await _navigateAfterLogin();
    } else {
      final status = ref.read(authProvider).status;
      if (status == AuthStatus.emailUnverified) {
        Navigator.pushReplacementNamed(context, '/verify-email');
      }
      // If error — it's already in authProvider.state.errorMessage,
      // the UI below will show it automatically via ref.watch
    }
  }

  // ── Google sign in ────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    ref.read(authProvider.notifier).clearError();

    final success = await ref.read(authProvider.notifier).signInWithGoogle();

    if (!mounted) return;

    if (success) {
      await _navigateAfterLogin();
    }
  }

  // ── Forgot password ───────────────────────────────────────────────────
  void _showForgotPassword() {
    final forgotController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1464),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email and we\'ll send you a reset link.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: forgotController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (forgotController.text.trim().isNotEmpty) {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: forgotController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset email sent!')),
                  );
                }
              }
            },
            child: const Text(
              'Send',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Watch auth state — UI rebuilds automatically on changes ──────────
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.errorMessage;

    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF6C63FF)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),

                      // Logo / Ustu
                      Center(
                        child: Container(
                          height: 90,
                          width: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Text('🦉', style: TextStyle(fontSize: 44)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      const Center(
                        child: Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Center(
                        child: Text(
                          'Login to continue your preparation',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Error message ─────────────────────────────────
                      if (errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFFF6B6B),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Color(0xFFFF6B6B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Email field ────────────────────────────────────
                      _buildLabel('Email Address'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                        ),
                        onChanged: (_) =>
                            ref.read(authProvider.notifier).clearError(),
                        decoration: _inputDecoration(
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Password field ────────────────────────────────
                      _buildLabel('Password'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                        ),
                        onChanged: (_) =>
                            ref.read(authProvider.notifier).clearError(),
                        decoration: _inputDecoration(
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white38,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Password is required';
                          return null;
                        },
                      ),

                      // ── Forgot password ───────────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPassword,
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Login button ──────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6C63FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF6C63FF),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Divider ───────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or continue with',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.35),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Google button ─────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google G icon
                              Container(
                                height: 22,
                                width: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: const Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6C63FF),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Sign up redirect ──────────────────────────────
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Don\'t have an account? ',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(
                                context,
                                '/signup',
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.white.withOpacity(0.75),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white.withOpacity(0.3),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
      ),
      errorStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11),
    );
  }
}
