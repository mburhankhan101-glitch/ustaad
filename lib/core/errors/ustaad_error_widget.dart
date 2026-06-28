import 'package:flutter/material.dart';
import 'app_error_handler.dart';

// 1. Full screen error (for providers/screens)
class UstaadErrorWidget extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;

  const UstaadErrorWidget({required this.error, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFFF6B6B),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              error.urduMessage ?? error.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            if (error.isRetryable && onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Dobara Try Karein',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 2. Empty state widget (when Firestore returns nothing)
class UstaadEmptyWidget extends StatelessWidget {
  final String message;
  final String? urduMessage;

  const UstaadEmptyWidget({
    this.message = 'Nothing here yet.',
    this.urduMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(
            urduMessage ?? message,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// 3. Inline snackbar helper — use anywhere
void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: const Color(0xFFFF6B6B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
