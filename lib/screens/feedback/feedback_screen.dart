// lib/screens/feedback/feedback_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _isSaving = false;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Start the staggered animation after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Staggered animation helper ────────────────────────────────────────────
  Widget _animatedItem(int index, Widget child) {
    final Animation<double> animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(
        index * 0.2, // start after previous item
        (index * 0.2) + 0.3, // each item animates for 0.3 of the total time
        curve: Curves.easeOut,
      ),
    );
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }

  // ── Submit logic ──────────────────────────────────────────────────────────
  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user?.uid ?? 'anonymous',
        'displayName': user?.displayName ?? 'Anonymous',
        'email': user?.email ?? '',
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been submitted.'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send feedback: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity, // forces full-screen gradient
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
              // ── Header (always on top) ────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 20, top: 8),
                child: _animatedItem(
                  0,
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Feedback',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Scrollable middle content ─────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _animatedItem(
                        1,
                        Text(
                          "We'd love to hear your suggestions or help you "
                          "with any issues you've come across.",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700, // ← bolder
                            color: Colors.white.withOpacity(0.9),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _animatedItem(
                        2,
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            cursorColor: Colors.white,
                            cursorHeight: 14.9,
                            controller: _messageController,
                            maxLines: 6,
                            maxLength: 500,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Your experience matters to us. Let us know '
                                  'what went wrong. How can we improve to make '
                                  'your experience better ?',
                              hintStyle: const TextStyle(
                                // ← smaller hint
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0x80FFFFFF),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF6C63FF),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF6B6B),
                                  width: 1.5,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF6B6B),
                                  width: 2,
                                ),
                              ),
                              errorStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFFFF6B6B),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              counterStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please write your feedback'
                                : null,
                          ),
                        ),
                      ),
                      // Extra space so the TextField isn't stuck to the edge
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // ── Submit button (always visible at the bottom) ───────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: _animatedItem(
                  3,
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF6C63FF,
                        ).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Submit Feedback',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
