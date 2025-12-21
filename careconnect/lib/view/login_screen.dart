import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // State variable for Remember Me functionality
  bool _rememberMe = false;

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      
      // In a real application, you would save the email to local storage 
      // (like shared_preferences) if _rememberMe is true.
      debugPrint('Remember Me is set to: $_rememberMe');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authenticating $email...'), 
          backgroundColor: const Color(0xFF6B3F69),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                // WTMS Style: Floating Branding Icon
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
                          const Text(
                            'Sign In',
                            style: TextStyle(
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
                            style: const TextStyle(fontSize: 18),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8D5F8C)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter email';
                              if (!value.contains('@')) return 'Enter a valid email';
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
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8D5F8C)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter password';
                              if (value.length < 6) return 'Minimum 6 characters required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // REMEMBER ME CHECKBOX [Requirement: Accessibility Support]
                          Theme(
                            data: ThemeData(unselectedWidgetColor: const Color(0xFF8D5F8C)),
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                "Remember Me",
                                style: TextStyle(color: Color(0xFF6B3F69), fontSize: 16),
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
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B3F69),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 8,
                            ),
                            child: const Text(
                              'LOGIN', 
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                    // Navigate to Registration Screen
                  },
                  child: const Text(
                    "New to CareConnect? Sign Up",
                    style: TextStyle(
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