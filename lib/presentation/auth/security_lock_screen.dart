import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SecurityLockScreen extends StatelessWidget {
  final String threatMessage;

  const SecurityLockScreen({super.key, required this.threatMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium sleek dark background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: const Color(0xFF1E293B),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Shield alert icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          shape: BoxShape.circle),
                        child: const Icon(
                          Icons.gpp_bad,
                          size: 64,
                          color: Color(0xFFEF4444)))),
                    const SizedBox(height: 28),
                    const Text(
                      'App Integrity Failure',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'This application has blocked execution because it detected a potential security threat or unauthorized modifications.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        height: 1.5)),
                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 16),

                    // Threat details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.2))),
                      child: Text(
                        threatMessage,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.5))),
                    const SizedBox(height: 32),

                    // Exit button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        SystemNavigator.pop(); // Safely exit app
                      },
                      child: const Text(
                        'EXIT APPLICATION',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14))),
                  ])))))));
  }
}
