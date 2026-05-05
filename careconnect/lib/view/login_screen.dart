import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'signup_screen.dart';
import 'client_dashboard.dart';
import 'worker_dashboard.dart'; 
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED: Localization Import

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

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Grab the translation dictionary BEFORE the async API call
      final l10n = AppLocalizations.of(context)!;

      // Call the centralized API service
      final result = await MysqlApiService.login(email, password);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        final user = result['user'];

        // ==========================================
        // CHECK FOR WARNING BEFORE DASHBOARD
        // ==========================================
        if (user['account_status'] == 'Warning') {
          
          // FIX: Safely convert the database string (like "1") into a math integer (1)
          // This prevents the translation dictionary from crashing the popup!
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
                  child: Text(l10n.iUnderstand, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
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
        // CHECK FOR BANNED ACCOUNT
        // ==========================================
        if (result['message'] == 'ACCOUNT_BANNED') {
          _showBannedDialog(l10n); // Pass the dictionary to the dialog
        } else {
          // Show normal error message from server (e.g., wrong password)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? l10n.loginFailed), // Translated fallback
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
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