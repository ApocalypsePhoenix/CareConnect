import 'package:flutter/material.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for general fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Additional Carer Controllers
  final _icController = TextEditingController();
  final _addressController = TextEditingController();

  // Carer Specific State
  String _selectedRole = 'Client'; 
  String? _selectedGender;
  bool _termsConfirmed = false;

  // Professional Information State
  final Map<String, bool> _profInfo = {
    'Mobility Service': false,
    'Physiotherapy/Rehabilitation': false,
    'Daily Assistance/Nursing Care': false,
  };

  void _handleSignUp() {
    if (_formKey.currentState!.validate()) {
      if (!_termsConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please confirm the terms and conditions')),
        );
        return;
      }
      
      final email = _emailController.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing $_selectedRole registration for $email...'),
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
              Color(0xFF6B3F69), // Dark Purple
              Color(0xFF8D5F8C), // Medium Purple
              Color(0xFFDDC3C3), // Light Pink-Grey
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branding Icon
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'JOIN CARECONNECT',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                
                // ELEVATED CARD
                Card(
                  elevation: 15,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  color: Colors.white.withOpacity(0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B3F69),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 25),
                          
                          // Role Selection Toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildRoleButton('Client'),
                              const SizedBox(width: 15),
                              _buildRoleButton('Carer'),
                            ],
                          ),
                          const SizedBox(height: 25),

                          // Common Fields: Name
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                            validator: (v) => v!.isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 15),

                          // Carer Specific: IC / Passport
                          if (_selectedRole == 'Carer') ...[
                            _buildTextField(
                              controller: _icController,
                              label: 'I/C or Passport Number',
                              icon: Icons.badge_outlined,
                              validator: (v) => v!.isEmpty ? 'ID required' : null,
                            ),
                            const SizedBox(height: 15),
                          ],

                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_android_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Phone required' : null,
                          ),
                          const SizedBox(height: 15),

                          // Carer Specific: Gender Dropdown
                          if (_selectedRole == 'Carer') ...[
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: const Icon(Icons.wc, color: Color(0xFF8D5F8C)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: ['Male', 'Female', 'Other'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedGender = val),
                              validator: (v) => v == null ? 'Select gender' : null,
                            ),
                            const SizedBox(height: 15),
                            
                            // Carer Specific: Address
                            _buildTextField(
                              controller: _addressController,
                              label: 'Full Address',
                              icon: Icons.home_outlined,
                              maxLines: 2,
                              validator: (v) => v!.isEmpty ? 'Address required' : null,
                            ),
                            const SizedBox(height: 15),
                          ],
                          
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
                          ),
                          const SizedBox(height: 15),
                          
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                          ),
                          const SizedBox(height: 15),

                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            icon: Icons.lock_reset_outlined,
                            isPassword: true,
                            validator: (v) => v != _passwordController.text ? 'Mismatch' : null,
                          ),

                          // Carer Specific: Professional Info & Uploads
                          if (_selectedRole == 'Carer') ...[
                            const SizedBox(height: 25),
                            const Text(
                              'Professional Information',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69)),
                            ),
                            const SizedBox(height: 10),
                            ..._profInfo.keys.map((String key) {
                              return CheckboxListTile(
                                title: Text(key, style: const TextStyle(fontSize: 14)),
                                value: _profInfo[key],
                                activeColor: const Color(0xFF6B3F69),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (bool? value) {
                                  setState(() => _profInfo[key] = value!);
                                },
                              );
                            }).toList(),

                            const SizedBox(height: 20),
                            const Text(
                              'Certificate Document Upload',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69)),
                            ),
                            const SizedBox(height: 10),
                            _buildUploadButton('Profile Picture', Icons.image, 'Image required'),
                            _buildUploadButton('I/C or Passport', Icons.picture_as_pdf, 'PDF required'),
                            _buildUploadButton('Driving License', Icons.picture_as_pdf, 'PDF required'),
                            _buildUploadButton('Certifications', Icons.picture_as_pdf, 'PDF required'),
                          ],

                          const SizedBox(height: 20),
                          
                          // Terms and Conditions
                          Row(
                            children: [
                              Checkbox(
                                value: _termsConfirmed,
                                activeColor: const Color(0xFF6B3F69),
                                onChanged: (v) => setState(() => _termsConfirmed = v!),
                              ),
                              const Expanded(
                                child: Text(
                                  'I confirm all information and documents are true.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          
                          ElevatedButton(
                            onPressed: _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B3F69),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 8,
                            ),
                            child: const Text(
                              'SIGN UP', 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    "Already have an account? Sign In",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 16, 
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C), size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }

  Widget _buildUploadButton(String label, IconData icon, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        onPressed: () {
          // Trigger file picker logic
        },
        icon: Icon(icon, size: 20, color: const Color(0xFF8D5F8C)),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.black87, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          side: const BorderSide(color: Color(0xFFDDC3C3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildRoleButton(String role) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
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
}