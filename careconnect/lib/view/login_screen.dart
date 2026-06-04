import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADDED: To save credentials
import '../services/mysql_api_service.dart';
import 'signup_screen.dart';
import 'client_dashboard.dart';
import 'worker_dashboard.dart'; 
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import '../main.dart'; 

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

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Automatically check for saved login details!
  }

  // --- NEW: Load saved email & password from memory ---
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  void _processLoginResult(Map<String, dynamic> result, AppLocalizations l10n) async {
    if (result['success'] == true || result['status'] == 'success') {
      final user = result['user'];

      if (user['account_status'] == 'Warning') {
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
                Text(l10n.accountWarning, style: const TextStyle(color: Colors.orange)),
              ],
            ),
            content: Text(
              l10n.warningMessage(warnings), 
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
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
          content: Text(l10n.welcomeBackName(user['name'])), 
          backgroundColor: const Color(0xFF6B3F69),
        ),
      );

      if (user['role'] == 'Client') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ClientDashboard(user: user)));
      } else if (user['role'] == 'Worker') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => WorkerDashboard(user: user)));
      }
      
    } else {
      final message = result['message'] ?? '';
      if (message == 'ACCOUNT_BANNED') {
        _showBannedDialog(l10n); 
      } else {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.isNotEmpty ? message : l10n.loginFailed), 
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final l10n = AppLocalizations.of(context)!;

      try {
        final result = await MysqlApiService.login(email, password);

        // --- NEW: Save or Clear credentials based on checkbox ---
        if (result['success'] == true || result['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setString('saved_email', email);
            await prefs.setString('saved_password', password);
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('saved_email');
            await prefs.remove('saved_password');
            await prefs.setBool('remember_me', false);
          }
        }

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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    final l10n = AppLocalizations.of(context)!;

    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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
            Text(l10n.accountBanned, style: const TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(
          l10n.bannedMessage,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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

  Widget _buildLanguageToggle() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: Colors.white, size: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (String languageCode) async {
        appLocale.value = Locale(languageCode);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', languageCode);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              Text('🇺🇸', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Text('English'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'ms',
          child: Row(
            children: [
              Text('🇲🇾', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Text('Bahasa Melayu'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF6B3F69), 
                  Color(0xFF8D5F8C), 
                  Color(0xFFDDC3C3), 
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                      'CARECONNECT', 
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
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
                                l10n.signIn, 
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B3F69),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),
                              
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(fontSize: 18),
                                decoration: InputDecoration(
                                  labelText: l10n.emailLabel, 
                                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8D5F8C)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return l10n.pleaseEnterEmail; 
                                  if (!value.contains('@')) return l10n.enterValidEmail; 
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                style: const TextStyle(fontSize: 18),
                                decoration: InputDecoration(
                                  labelText: l10n.passwordLabel, 
                                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8D5F8C)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return l10n.pleaseEnterPassword; 
                                  if (value.length < 6) return l10n.min6Chars; 
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),

                              Theme(
                                data: ThemeData(unselectedWidgetColor: const Color(0xFF8D5F8C)),
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    l10n.rememberMe, 
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
                                      l10n.loginBtn, 
                                      style: const TextStyle(
                                        fontSize: 20, 
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.white
                                      ),
                                    ),
                              ),

                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: const Color(0xFF8D5F8C).withOpacity(0.5))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      l10n.or, 
                                      style: const TextStyle(
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

                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleGoogleSignIn,
                                icon: Image.network(
                                  'https://developers.google.com/static/identity/images/g-logo.png',
                                  height: 22,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.login, color: Color(0xFF6B3F69));
                                  },
                                ),
                                label: Text(
                                  l10n.signInWithGoogle, 
                                  style: const TextStyle(
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
                        l10n.newToCareConnect, 
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
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                child: _buildLanguageToggle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}