// lib/screens/home/widgets/notification_ask_sheet.dart
//
// Ustu asking, in its own voice, before the system asks in its.
//
// This exists to protect a one-shot resource. The Android 13+ permission
// dialog can only be refused twice before it stops appearing at all, so it
// should only ever be shown to someone who has already agreed. "Abhi nahi"
// here costs nothing and can be asked again in five days; "Abhi nahi" to the
// system dialog costs the permission permanently.
//
// So the primary button is the quiet one and the decline is given equal
// weight. A card that tricks someone into the system dialog has spent their
// one chance on a no.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ustaad/screens/home/home_screen.dart'; // UstaadColors

class NotificationAskSheet extends StatelessWidget {
  const NotificationAskSheet({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onYes,
    required this.onNotNow,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final VoidCallback onYes;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: const BoxDecoration(
            color: UstaadColors.background2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Center(
                    child: SvgPicture.asset(
                      'assets/images/app_ustu.svg',
                      height: 104,
                      placeholderBuilder: (_) => const SizedBox(height: 104),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    body,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onYes();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UstaadColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onNotNow,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        'Abhi nahi',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
