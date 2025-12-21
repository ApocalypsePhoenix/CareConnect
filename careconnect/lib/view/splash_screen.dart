import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Non-functional requirement 2.1: Load page within 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF6B3F69), // Dark Purple Primary
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CareConnect',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDDC3C3), // Light Pinkish-Grey
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(
              color: Color(0xFFA376A2), // Muted Purple
            ),
          ],
        ),
      ),
    );
  }
}