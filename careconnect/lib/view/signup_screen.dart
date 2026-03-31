import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/mysql_api_service.dart';
import 'login_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class RecipientData {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final needsController = TextEditingController();
  String? selectedRelationship;
  String? selectedCondition; // Added to store the dropdown selection

  void dispose() {
    nameController.dispose();
    ageController.dispose();
    needsController.dispose();
  }
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentSection = 0;
  bool _isLoading = false;

  String _selectedRole = 'Client'; 

  // --- Profile Image ---
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // --- Controllers for Section 1: Personal Information ---
  final _nameController = TextEditingController();
  final _icController = TextEditingController();
  final _ageController = TextEditingController(); 
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedGender;

  // --- Controllers for Section 2: Account Information ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // --- Controllers for Section 3 (WORKER) ---
  final Map<String, bool> _profInfo = {
    'Mobility Service': false,
    'Physiotherapy/Rehabilitation': false,
    'Daily Assistance/Nursing Care': false,
  };
  bool _termsConfirmed = false;

  // --- Recipient Management (CLIENT) ---
  bool _isRegisteringForSelf = true;
  List<RecipientData> _recipients = [RecipientData()];

  // Medical conditions for the dropdown
  final List<String> _medicalConditions = [
    'High Blood Pressure',
    'Heart Disease & Stroke',
    'Diabetes',
    'Others'
  ];

  int get _totalSections => 3;

  @override
  void initState() {
    super.initState();
    _icController.addListener(_onIcChanged);
  }

  @override
  void dispose() {
    _icController.removeListener(_onIcChanged);
    _nameController.dispose();
    _icController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var r in _recipients) r.dispose();
    super.dispose();
  }

  // Pick Profile Image Logic
  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // Compress the image slightly to save bandwidth
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

 // Malaysian MyKad Auto-Detection Logic
  void _onIcChanged() {
    String ic = _icController.text.replaceAll('-', '');
    if (ic.length == 12) {
      int lastDigit = int.parse(ic.substring(11));
      String detectedGender = (lastDigit % 2 == 0) ? 'Female' : 'Male';

      int yearShort = int.parse(ic.substring(0, 2));
      int currentYearFull = DateTime.now().year;
      int currentYearShort = currentYearFull % 100;

      int birthYear = (yearShort > currentYearShort + 2) ? 1900 + yearShort : 2000 + yearShort;
      int detectedAge = currentYearFull - birthYear;

      setState(() {
        _selectedGender = detectedGender;
        _ageController.text = detectedAge.toString();
      });
    }
  }

  // Google Sign-Up Logic
  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser != null) {
        setState(() {
          _emailController.text = googleUser.email; 
          if (_nameController.text.isEmpty) {
            _nameController.text = googleUser.displayName ?? "";
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google account linked! Please set a password for CareConnect.'))
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $error'))
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addRecipient() {
    setState(() {
      _recipients.add(RecipientData());
    });
  }

  void _removeRecipient(int index) {
    if (_recipients.length > 1) {
      setState(() {
        _recipients[index].dispose();
        _recipients.removeAt(index);
      });
    }
  }

  void _nextSection() {
    if (_currentSection < _totalSections - 1) {
      setState(() => _currentSection++);
      _pageController.animateToPage(_currentSection,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _previousSection() {
    if (_currentSection > 0) {
      setState(() => _currentSection--);
      _pageController.animateToPage(_currentSection,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    if (_selectedRole == 'Worker' && !_termsConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm information is true')));
      return;
    }

    setState(() => _isLoading = true);

    // Convert Image to Base64 String if an image was picked
    String? base64Image;
    if (_profileImage != null) {
      List<int> imageBytes = await _profileImage!.readAsBytes();
      base64Image = base64Encode(imageBytes);
    }

    List<Map<String, dynamic>> recipientsList = [];
    if (_selectedRole == 'Client') {
      if (_isRegisteringForSelf) {
        recipientsList.add({
          "name": _nameController.text,
          "age": _ageController.text.isEmpty ? "0" : _ageController.text, 
          "relationship": "Self",
          "medical_condition": _recipients[0].selectedCondition ?? "Others",
          "special_needs": _recipients[0].needsController.text,
        });
      } else {
        for (var r in _recipients) {
          recipientsList.add({
            "name": r.nameController.text,
            "age": r.ageController.text,
            "relationship": r.selectedRelationship,
            "medical_condition": r.selectedCondition ?? "Others",
            "special_needs": r.needsController.text,
          });
        }
      }
    }

    final registrationData = {
      "name": _nameController.text,
      "ic_number": _icController.text,
      "age": _ageController.text,
      "phone": _phoneController.text,
      "gender": _selectedGender,
      "address": _addressController.text,
      "email": _emailController.text,
      "password": _passwordController.text,
      "role": _selectedRole,
      "profile_image": base64Image, // Include Base64 image in payload
      "recipients": recipientsList,
      "worker_services": _selectedRole == 'Worker' ? _profInfo : null,
    };

    final result = await MysqlApiService.registerClient(registrationData);

    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: const Color(0xFF6B3F69)));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
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
            colors: [Color(0xFF6B3F69), Color(0xFF8D5F8C), Color(0xFFDDC3C3)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 25),
                Card(
                  elevation: 15,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  color: Colors.white.withOpacity(0.98),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_currentSection == 0) _buildRoleToggle(),
                          SizedBox(
                            height: 520, 
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildSection1(),
                                _buildSection2(),
                                _selectedRole == 'Worker' ? _buildSection3Worker() : _buildSection3Client(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildNavigationButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
                  child: const Text("Already have an account? Sign In",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickProfileImage,
          child: Container(
            width: 85, // Fixed width/height to ensure circular clipping
            height: 85,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: _profileImage != null
                ? ClipOval(
                    child: Image.file(
                      _profileImage!,
                      fit: BoxFit.cover,
                      width: 85,
                      height: 85,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.person_add_alt_1_outlined, size: 45, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text('${_selectedRole.toUpperCase()} REGISTRATION',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
        Text('Section ${_currentSection + 1} of $_totalSections',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRoleToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_buildRoleButton('Client'), const SizedBox(width: 15), _buildRoleButton('Worker')],
      ),
    );
  }

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
          border: Border.all(color: isSelected ? const Color(0xFF6B3F69) : const Color(0xFFA376A2), width: 2),
        ),
        child: Text(role, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSection1() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 15),
          _buildTextField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline),
          const SizedBox(height: 12),
          _buildTextField(controller: _icController, label: 'I/C or Passport Number', icon: Icons.badge_outlined),
          const SizedBox(height: 12),
          _buildTextField(controller: _ageController, label: 'Your Age', icon: Icons.cake_outlined, keyboardType: TextInputType.number),
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
          _buildTextField(controller: _addressController, label: 'Current Address', icon: Icons.home_outlined, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildSection2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Account Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _handleGoogleSignUp,
          icon: const Icon(Icons.login, color: Color(0xFF6B3F69)),
          label: const Text('Continue with Google', style: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Color(0xFF6B3F69)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text("OR", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        _buildTextField(controller: _emailController, label: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 15),
        _buildTextField(controller: _passwordController, label: 'Password', icon: Icons.lock_outline, isPassword: true),
        const SizedBox(height: 15),
        _buildTextField(controller: _confirmPasswordController, label: 'Confirm Password', icon: Icons.lock_reset_outlined, isPassword: true),
        const Spacer(),
        const Text('By continuing, you agree to our terms and conditions.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSection3Client() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Care Recipient Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          _buildRecipientToggle(),
          const SizedBox(height: 15),
          ..._recipients.asMap().entries.map((entry) => _buildRecipientForm(entry.key, entry.value)),
          if (!_isRegisteringForSelf)
            TextButton.icon(
              onPressed: _addRecipient,
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6B3F69)),
              label: const Text('Add Another Recipient', style: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSection3Worker() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Professional Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          _buildServiceCheckboxes(),
          const SizedBox(height: 20),
          const Text('Certificate Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          _buildUploadItem('Profile Picture', Icons.camera_alt_outlined, 'IMAGE'),
          _buildUploadItem('I/C or Passport', Icons.badge_outlined, 'PDF'),
          _buildUploadItem('Driving License', Icons.drive_eta_outlined, 'PDF'),
          _buildUploadItem('Certifications', Icons.workspace_premium_outlined, 'PDF'),
          const SizedBox(height: 15),
          _buildTermsCheckbox(),
        ],
      ),
    );
  }

  Widget _buildRecipientToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.3), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          _buildToggleButton('Registering Self', _isRegisteringForSelf, () {
            setState(() {
              _isRegisteringForSelf = true;
              _recipients = [RecipientData()];
            });
          }),
          _buildToggleButton('Registering Others', !_isRegisteringForSelf, () {
            setState(() => _isRegisteringForSelf = false);
          }),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: active ? const Color(0xFF6B3F69) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: active ? Colors.white : const Color(0xFF6B3F69), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildRecipientForm(int index, RecipientData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: const Color(0xFFDDC3C3)), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          if (_isRegisteringForSelf) ...[
            const Text("Your Health Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6B3F69))),
            const SizedBox(height: 8),
          ],
          if (!_isRegisteringForSelf) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recipient #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6B3F69))),
                if (_recipients.length > 1) IconButton(onPressed: () => _removeRecipient(index), icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20)),
              ],
            ),
            _buildTextField(controller: data.nameController, label: "Full Name", icon: Icons.person_search_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 3, child: _buildTextField(controller: data.ageController, label: "Age", icon: Icons.cake_outlined, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: data.selectedRelationship,
                    decoration: _inputDecoration('Relationship', Icons.people_outline),
                    items: ['Parent', 'Grandparent', 'Spouse', 'Other'].map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() => data.selectedRelationship = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Replaced TextField with DropdownButtonFormField for Medical Condition
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: data.selectedCondition,
            decoration: _inputDecoration('Medical Condition', Icons.medical_information_outlined),
            items: _medicalConditions.map((condition) => DropdownMenuItem(
              value: condition,
              child: Text(condition, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (val) => setState(() => data.selectedCondition = val),
            validator: (v) => v == null ? 'Please select a condition' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(controller: data.needsController, label: "Special Needs", icon: Icons.note_alt_outlined, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildServiceCheckboxes() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: _profInfo.keys.map((key) => CheckboxListTile(
              title: Text(key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              value: _profInfo[key],
              activeColor: const Color(0xFF6B3F69),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _profInfo[key] = v!),
            )).toList(),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(value: _termsConfirmed, activeColor: const Color(0xFF6B3F69), onChanged: (v) => setState(() => _termsConfirmed = v!)),
        const Expanded(child: Text('I confirm all information and documents are true.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B3F69)))),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)));
    return Row(
      children: [
        if (_currentSection > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousSection,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: Color(0xFF6B3F69)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text('BACK', style: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
            ),
          ),
        if (_currentSection > 0) const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: (_currentSection == _totalSections - 1) ? _handleSignUp : _nextSection,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: Text((_currentSection == _totalSections - 1) ? 'SIGN UP' : 'NEXT', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
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
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C), size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildUploadItem(String label, IconData icon, String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Placeholder for file picking logic
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFDDC3C3)), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF8D5F8C)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFFA376A2)),
            ],
          ),
        ),
      ),
    );
  }
}