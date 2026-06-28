import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppError {
  final String message;
  final String? urduMessage;
  final bool isRetryable;

  const AppError({
    required this.message,
    this.urduMessage,
    this.isRetryable = true,
  });
}

class AppErrorHandler {
  // Call this on every FirebaseException
  static AppError fromFirebase(FirebaseException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return const AppError(
          message: 'Incorrect email or password.',
          urduMessage: 'Email ya password galat hai.',
          isRetryable: true,
        );
      case 'user-not-found':
        return const AppError(
          message: 'No account found with this email.',
          urduMessage: 'Is email ka koi account nahi mila.',
          isRetryable: false,
        );
      case 'email-already-in-use':
        return const AppError(
          message: 'An account already exists with this email.',
          urduMessage: 'Is email se pehle se account bana hua hai.',
          isRetryable: false,
        );
      case 'too-many-requests':
        return const AppError(
          message: 'Too many attempts. Please wait a moment.',
          urduMessage: 'Zyada attempts ho gayi. Thodi der baad try karein.',
          isRetryable: true,
        );
      case 'network-request-failed':
        return const AppError(
          message: 'No internet connection.',
          urduMessage: 'Internet connection nahi hai.',
          isRetryable: true,
        );
      case 'permission-denied':
        return const AppError(
          message: 'Access denied. Please log in again.',
          urduMessage: 'Access nahi mila. Dobara login karein.',
          isRetryable: false,
        );
      default:
        debugPrint('Unhandled Firebase error: ${e.code} — ${e.message}');
        return const AppError(
          message: 'Something went wrong. Please try again.',
          urduMessage: 'Kuch masla aa gaya. Dobara try karein.',
          isRetryable: true,
        );
    }
  }

  // Call this on general exceptions
  static AppError fromException(Object e) {
    debugPrint('App error: $e');
    return const AppError(
      message: 'Something went wrong. Please try again.',
      urduMessage: 'Kuch masla aa gaya. Dobara try karein.',
      isRetryable: true,
    );
  }
}
