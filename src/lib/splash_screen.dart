import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/lock');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121426),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 104,
              width: 104,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 58,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Raven',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Privacidade sob pressão',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.68),
              ),
            ),
            const SizedBox(height: 34),
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
