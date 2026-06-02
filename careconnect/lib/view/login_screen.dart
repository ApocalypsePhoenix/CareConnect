import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'signup_screen.dart';
import 'client_dashboard.dart';
import 'worker_dashboard.dart'; 
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Localization Import
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _rememberMe = false;
  bool _isLoading = false;

  // Initialize the Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Secure login result handler that processes both credential and Google responses,
  /// triggers warning checks, processes active session flags, and navigates correctly.
  void _processLoginResult(Map<String, dynamic> result, AppLocalizations l10n) async {
    // Check for success either as a boolean success flag or a 'success' status string
    if (result['success'] == true || result['status'] == 'success') {
      final user = result['user'];

      // ==========================================
      // CHECK FOR WARNING BEFORE DASHBOARD
      // ==========================================
      if (user['account_status'] == 'Warning') {
        // FIX: Safely convert the database string (like "1") into a math integer (1)
        int warnings = int.tryParse(user['warning_count']?.toString() ?? '0') ?? 0;
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 10),
                // TRANSLATED: 'Account Warning'
                Text(l10n.accountWarning, style: const TextStyle(color: Colors.orange)),
              ],
            ),
            // TRANSLATED: Dynamic warning message
            content: Text(
              l10n.warningMessage(warnings), // Uses the safe integer here!
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                // TRANSLATED: 'I Understand'
                child: Text(
                  l10n.iUnderstand, 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)
                ),
              ),
            ],
          ),
        );
      }
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // TRANSLATED: Dynamic welcome message
          content: Text(l10n.welcomeBackName(user['name'])), 
          backgroundColor: const Color(0xFF6B3F69),
        ),
      );

      // Role-based navigation
      if (user['role'] == 'Client') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClientDashboard(user: user),
          ),
        );
      } else if (user['role'] == 'Worker') {
        // Connected the Worker Dashboard!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkerDashboard(user: user),
          ),
        );
      }
      
    } else {
      // ==========================================
      // CHECK FOR BANNED ACCOUNT / ERRORS
      // ==========================================
      final message = result['message'] ?? '';
      if (message == 'ACCOUNT_BANNED') {
        _showBannedDialog(l10n); // Pass the dictionary to the dialog
      } else {
        // If login failed (e.g., Google account not registered), sign out of Google 
        // immediately so that the bad session doesn't lock the user in.
        try {
          await _googleSignIn.signOut();
        } catch (_) {}

        // Show normal error message from server (e.g., wrong password)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.isNotEmpty ? message : l10n.loginFailed), // Translated fallback
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Standard credential login method
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Grab the translation dictionary BEFORE the async API call
      final l10n = AppLocalizations.of(context)!;

      try {
        // Call the centralized API service
        final result = await MysqlApiService.login(email, password);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        _processLoginResult(result, l10n);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.loginFailed),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Secure Google Sign-In flow
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    final l10n = AppLocalizations.of(context)!;

    try {
      // FORCE Google Account Picker to display every single time.
      // Signing out first clears the cached session and resets the native dialog picker.
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Safe to ignore if there was no active cached account
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; // User canceled the sign-in
      }

      // Retrieve authentication details to get the secure verification token
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Call the clean centralized API service instead of performing a raw HTTP post
      final result = await MysqlApiService.loginWithGoogle(
        googleUser.email, 
        googleAuth.idToken ?? '',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _processLoginResult(result, l10n);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.loginFailed}: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- BANNED DIALOG UI ---
  void _showBannedDialog(AppLocalizations l10n) { 
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            // TRANSLATED: 'Account Banned'
            Text(l10n.accountBanned, style: const TextStyle(color: Colors.red)),
          ],
        ),
        // TRANSLATED: Banned message
        content: Text(
          l10n.bannedMessage,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            // TRANSLATED: 'Close'
            child: Text(l10n.close, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TRANSLATION INITIALIZATION FOR THE BUILD METHOD
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B3F69), // Dark Purple
              Color(0xFF8D5F8C), // Medium Purple
              Color(0xFFDDC3C3), // Light Pink-Grey
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Floating Branding Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'CARECONNECT', // Brand names stay the same
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                
                // ELEVATED WTMS CARD
                Card(
                  elevation: 15,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  color: Colors.white.withOpacity(0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.signIn, // TRANSLATED: 'Sign In'
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B3F69),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          
                          // Email Input
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 18),
                            decoration: InputDecoration(
                              labelText: l10n.emailLabel, // TRANSLATED: 'Email'
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8D5F8C)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return l10n.pleaseEnterEmail; // TRANSLATED
                              if (!value.contains('@')) return l10n.enterValidEmail; // TRANSLATED
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(fontSize: 18),
                            decoration: InputDecoration(
                              labelText: l10n.passwordLabel, // TRANSLATED: 'Password'
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8D5F8C)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return l10n.pleaseEnterPassword; // TRANSLATED
                              if (value.length < 6) return l10n.min6Chars; // TRANSLATED
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Remember Me Checkbox
                          Theme(
                            data: ThemeData(unselectedWidgetColor: const Color(0xFF8D5F8C)),
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                l10n.rememberMe, // TRANSLATED: 'Remember Me'
                                style: const TextStyle(color: Color(0xFF6B3F69), fontSize: 16),
                              ),
                              value: _rememberMe,
                              onChanged: (newValue) {
                                setState(() {
                                  _rememberMe = newValue!;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: const Color(0xFF6B3F69),
                              dense: true,
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          // Login Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B3F69),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 8,
                            ),
                            child: _isLoading 
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  l10n.loginBtn, // TRANSLATED: 'LOGIN'
                                  style: const TextStyle(
                                    fontSize: 20, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.white
                                  ),
                                ),
                          ),

                          // Visually appealing custom divider "OR"
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: Divider(color: const Color(0xFF8D5F8C).withOpacity(0.5))),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  "OR", 
                                  style: TextStyle(
                                    color: Color(0xFF8D5F8C), 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: const Color(0xFF8D5F8C).withOpacity(0.5))),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Outlined Google Sign-In Button matching layout elements
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            icon: Image.network(
                              'https://developers.google.com/static/identity/images/g-logo.png',
                              height: 22,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.login, color: Color(0xFF6B3F69));
                              },
                            ),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: Color(0xFF6B3F69),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF6B3F69), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignUpScreen()),
                    );
                  },
                  child: Text(
                    l10n.newToCareConnect, // TRANSLATED: 'New to CareConnect? Sign Up'
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}