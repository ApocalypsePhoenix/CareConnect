import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADDED: To read the saved language
import 'view/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 

// THE MAGIC SWITCH: Controls the language for the whole app!
// We initialize it with English as a fallback, but it will be overridden instantly in main()
final ValueNotifier<Locale> appLocale = ValueNotifier<Locale>(const Locale('en'));

void main() async {
  // 1. Ensure Flutter is fully ready before we talk to the phone's native storage
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Open the phone's memory and look for the saved language
  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString('language_code') ?? 'en'; // Defaults to 'en' if nothing is saved

  // 3. Set the global magic switch to the saved language BEFORE the app boots up
  appLocale.value = Locale(savedLanguage);

  runApp(const CareConnectApp());
}

class CareConnectApp extends StatelessWidget {
  const CareConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder listens to the "appLocale" switch. 
    // When the settings button changes it, the whole app instantly redraws!
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'CareConnect',
          debugShowCheckedModeBanner: false,
          
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), 
            Locale('ms'), 
          ],
          
          // Connect the app's language to our Magic Switch
          locale: locale, 

          theme: ThemeData(
            primaryColor: const Color(0xFF6B3F69),
            scaffoldBackgroundColor: const Color(0xFFDDC3C3), 
            colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: const Color(0xFF6B3F69),
              secondary: const Color(0xFF8D5F8C),
            ),
            textTheme: const TextTheme(
              displayLarge: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold),
              bodyLarge: TextStyle(fontSize: 20.0, color: Colors.black87),
              bodyMedium: TextStyle(fontSize: 18.0, color: Colors.black54),
            ),
          ),
          home: const SplashScreen(),
        );
      }
    );
  }
}