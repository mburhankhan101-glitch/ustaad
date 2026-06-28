import 'package:flutter/material.dart';

class WebAuthLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WebAuthLayout({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E2E), Color(0xFF1A1464), Color(0xFF6C63FF)],
          ),
        ),
        child: isWeb
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Container(
                    width: maxWidth,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(36),
                    child: child,
                  ),
                ),
              )
            : SafeArea(child: child), // mobile: unchanged
      ),
    );
  }
}
