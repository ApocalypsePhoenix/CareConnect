import 'package:flutter/material.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentSection = 0;

  // Role Selection (Requirement: Both Client and Carer sides)
  String _selectedRole = 'Client'; 

  // Controllers for Section 1: Personal Information
  final _nameController = TextEditingController();
  final _icController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedGender;

  // Controllers for Section 2: Account Information
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Controllers for Section 3: Professional & Documents (Carer only)
  final Map<String, bool> _profInfo = {
    'Mobility Service': false,
    'Physiotherapy/Rehabilitation': false,
    'Daily Assistance/Nursing Care': false,
  };
  bool _termsConfirmed = false;

  int get _totalSections => _selectedRole == 'Carer' ? 3 : 2;

  void _nextSection() {
    if (_currentSection < _totalSections - 1) {
      setState(() {
        _currentSection++;
      });
      _pageController.animateToPage(
        _currentSection,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousSection() {
    if (_currentSection > 0) {
      setState(() {
        _currentSection--;
      });
      _pageController.animateToPage(
        _currentSection,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleSignUp() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRole == 'Carer' && !_termsConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please confirm information is true')),
        );
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing $_selectedRole Sign Up...'),
          backgroundColor: const Color(0xFF6B3F69),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              children: [
                // Header Branding
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.person_add_alt_1_outlined, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_selectedRole.toUpperCase()} REGISTRATION',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  'Section ${_currentSection + 1} of $_totalSections',
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 25),

                // Main Form Card with standardized size
                Card(
                  elevation: 15,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  color: Colors.white.withOpacity(0.98),
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Role Selection Toggle (Only visible in Section 1)
                          if (_currentSection == 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildRoleButton('Client'),
                                const SizedBox(width: 15),
                                _buildRoleButton('Carer'),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Standardized container height for all sections
                          SizedBox(
                            height: 480, 
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildSection1(),
                                _buildSection2(),
                                if (_selectedRole == 'Carer') _buildSection3(),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Navigation Buttons
                          Row(
                            children: [
                              if (_currentSection > 0)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _previousSection,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      side: const BorderSide(color: Color(0xFF6B3F69)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                    child: const Text('BACK', style: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              if (_currentSection > 0) const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: (_currentSection == _totalSections - 1) ? _handleSignUp : _nextSection,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6B3F69),
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                  child: Text(
                                    (_currentSection == _totalSections - 1) ? 'SIGN UP' : 'NEXT',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
                  child: const Text(
                    "Already have an account? Sign In",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Role Toggle Buttons
  Widget _buildRoleButton(String role) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _currentSection = 0;
          _pageController.jumpToPage(0);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B3F69) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? const Color(0xFF6B3F69) : const Color(0xFFA376A2),
            width: 2,
          ),
        ),
        child: Text(
          role,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B3F69),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Section 1: Personal Information
  Widget _buildSection1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
        const SizedBox(height: 15),
        _buildTextField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline),
        const SizedBox(height: 12),
        _buildTextField(controller: _icController, label: 'I/C or Passport Number', icon: Icons.badge_outlined),
        const SizedBox(height: 12),
        _buildTextField(controller: _phoneController, label: 'Phone Number', icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: _inputDecoration('Gender', Icons.wc),
          items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (val) => setState(() => _selectedGender = val),
        ),
        const SizedBox(height: 12),
        _buildTextField(controller: _addressController, label: 'Address', icon: Icons.home_outlined, maxLines: 2),
      ],
    );
  }

  // Section 2: Account Information
  Widget _buildSection2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Account Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
        const SizedBox(height: 20),
        _buildTextField(controller: _emailController, label: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 15),
        _buildTextField(controller: _passwordController, label: 'Password', icon: Icons.lock_outline, isPassword: true),
        const SizedBox(height: 15),
        _buildTextField(controller: _confirmPasswordController, label: 'Confirm Password', icon: Icons.lock_reset_outlined, isPassword: true),
        if (_selectedRole == 'Client') ...[
          const Spacer(),
          const Text(
            'By clicking sign up, you agree to our terms and conditions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
        ]
      ],
    );
  }

  // Section 3: Professional Info & Documents (Redesigned)
  Widget _buildSection3() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Professional Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          // Services Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDDC3C3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: _profInfo.keys.map((key) => CheckboxListTile(
                title: Text(key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                value: _profInfo[key],
                activeColor: const Color(0xFF6B3F69),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _profInfo[key] = v!),
              )).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Certificate Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          // Document Grid-like list
          _buildUploadItem('Profile Picture', Icons.camera_alt_outlined, 'IMAGE'),
          _buildUploadItem('I/C or Passport', Icons.badge_outlined, 'PDF'),
          _buildUploadItem('Driving License', Icons.drive_eta_outlined, 'PDF'),
          _buildUploadItem('Certifications', Icons.workspace_premium_outlined, 'PDF'),
          const SizedBox(height: 15),
          // Confirmation Checkbox
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              children: [
                SizedBox(
                  height: 24, width: 24,
                  child: Checkbox(
                    value: _termsConfirmed,
                    activeColor: const Color(0xFF6B3F69),
                    onChanged: (v) => setState(() => _termsConfirmed = v!),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'I confirm all information and documents are true.', 
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B3F69))
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C), size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }

  Widget _buildUploadItem(String label, IconData icon, String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () { /* Trigger file picker */ },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDDC3C3)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
            ]
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8D5F8C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF8D5F8C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(type, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFFA376A2)),
            ],
          ),
        ),
      ),
    );
  }
}