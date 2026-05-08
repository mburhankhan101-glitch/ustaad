import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Password strength
  double _passwordStrength = 0;
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasSpecialChar = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Password strength checker ─────────────────────────────────────────
  void _checkPasswordStrength(String password) {
    bool minLength = password.length >= 8;
    bool uppercase = password.contains(RegExp(r'[A-Z]'));
    bool special = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    double strength = 0;
    if (minLength) strength += 0.33;
    if (uppercase) strength += 0.33;
    if (special) strength += 0.34;

    setState(() {
      _hasMinLength = minLength;
      _hasUppercase = uppercase;
      _hasSpecialChar = special;
      _passwordStrength = strength;
    });
  }

  Color get _strengthColor {
    if (_passwordStrength <= 0.33) return const Color(0xFFFF6B6B);
    if (_passwordStrength <= 0.66) return const Color(0xFFFFD700);
    return const Color(0xFF4CAF50);
  }

  String get _strengthLabel {
    if (_passwordStrength <= 0.33) return 'Weak';
    if (_passwordStrength <= 0.66) return 'Fair';
    return 'Strong';
  }

  // ── Sign up ───────────────────────────────────────────────────────────
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authProvider.notifier).clearError();

    final success = await ref
        .read(authProvider.notifier)
        .signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      // THIS IS YOUR POPUP
      Navigator.pushReplacementNamed(context, '/verify_email');
    }
    // If failed — errorMessage is in authState, shown by ref.watch below
  }

  // ── Google sign in ────────────────────────────────────────────────────
  Future<void> _signUpWithGoogle() async {
    ref.read(authProvider.notifier).clearError();

    final success = await ref.read(authProvider.notifier).signInWithGoogle();

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/test_selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.errorMessage;

    return Scaffold(
      body: Container(
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
                    const SizedBox(height: 36),

                    // Back button
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Join Ustaad and start your prep journey',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),

                    const SizedBox(height: 32),

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

                    // ── Full name ─────────────────────────────────────
                    _buildLabel('Full Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                      ),
                      onChanged: (_) =>
                          ref.read(authProvider.notifier).clearError(),
                      decoration: _inputDecoration(
                        hint: 'Your full name',
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Name is required';
                        if (v.trim().length < 2) return 'Name is too short';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Email ─────────────────────────────────────────
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
                        if (v == null || v.isEmpty) return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Password ──────────────────────────────────────
                    _buildLabel('Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                      ),
                      onChanged: (v) {
                        _checkPasswordStrength(v);
                        ref.read(authProvider.notifier).clearError();
                      },
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
                        if (!_hasMinLength)
                          return 'Minimum 8 characters required';
                        if (!_hasUppercase)
                          return 'Add at least one uppercase letter';
                        if (!_hasSpecialChar)
                          return 'Add at least one special character';
                        return null;
                      },
                    ),

                    // ── Strength bar ──────────────────────────────────
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _passwordStrength,
                                minHeight: 5,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation(
                                  _strengthColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _strengthLabel,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _strengthColor,
                            ),
                          ),
                        ],
                      ),

                      // Requirements checklist
                      const SizedBox(height: 8),
                      _RequirementRow(
                        met: _hasMinLength,
                        text: 'At least 8 characters',
                      ),
                      _RequirementRow(
                        met: _hasUppercase,
                        text: 'One uppercase letter',
                      ),
                      _RequirementRow(
                        met: _hasSpecialChar,
                        text: 'One special character',
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Confirm password ──────────────────────────────
                    _buildLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                      ),
                      decoration: _inputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Please confirm your password';
                        if (v != _passwordController.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // ── Sign up button ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _signUp,
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
                                'Create Account',
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
                          child: Divider(color: Colors.white.withOpacity(0.15)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or sign up with',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: Colors.white.withOpacity(0.15)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Google button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: isLoading ? null : _signUpWithGoogle,
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

                    // ── Login redirect ────────────────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            ),
                            child: const Text(
                              'Login',
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

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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

// ─────────────────────────────────────────────────────────────────────────────
// PASSWORD REQUIREMENT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _RequirementRow extends StatelessWidget {
  final bool met;
  final String text;

  const _RequirementRow({required this.met, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: met
                ? const Color(0xFF4CAF50)
                : Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: met
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}
