import 'package:flutter/material.dart';
import 'view/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ADDED FOR LOCALIZATION
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED FOR LOCALIZATION

void main() {
  runApp(const CareConnectApp());
}

class CareConnectApp extends StatelessWidget {
  const CareConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareConnect',
      debugShowCheckedModeBanner: false,
      
      // ==========================================
      // ADDED: LOCALIZATION DELEGATES AND LOCALES
      // ==========================================
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('ms'), // Bahasa Malaysia
      ],
      locale: const Locale('en'), // Forces English for now until we build the dropdown

      theme: ThemeData(
        // Primary brand color: 6B3F69
        primaryColor: const Color(0xFF6B3F69),
        // light background color: DDC3C3
        scaffoldBackgroundColor: const Color(0xFFDDC3C3), 
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF6B3F69),
          secondary: const Color(0xFF8D5F8C),
        ),
        // Accessibility: Large fonts for elderly users (Requirement 1.2)
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 20.0, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 18.0, color: Colors.black54),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}