import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authService = AuthService();
  Timer? _timer;
  bool _canResend = false;
  int _resendCountdown = 60;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
    _startResendCountdown();
  }

  // Check every 3 seconds if user verified their email
  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final verified = await _authService.isEmailVerified();
      if (verified && mounted) {
        _timer?.cancel();
        Navigator.pushReplacementNamed(context, '/test_selection');
      }
    });
  }

  // 60 second countdown before allowing resend
  void _startResendCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendEmail() async {
    await _authService.resendVerificationEmail();
    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });
    _startResendCountdown();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? '';

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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Email icon
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Verify Your Email 📧',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  'We\'ve sent a verification link to:',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Email badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    email,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Click the link in the email to verify your account. This page will update automatically.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Resend button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _canResend ? _resendEmail : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _canResend
                          ? 'Resend Email'
                          : 'Resend in ${_resendCountdown}s',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _canResend
                            ? const Color(0xFF6C63FF)
                            : Colors.white54,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Wrong email — go back
                TextButton(
                  onPressed: () async {
                    await _authService.logout();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Wrong email? Go back',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
