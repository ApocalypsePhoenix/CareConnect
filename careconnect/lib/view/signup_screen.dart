import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/mysql_api_service.dart';
import 'login_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED: Localization Import

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
  String? selectedCondition; 

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

  // --- General Profile Image (Top Avatar) ---
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // --- Controllers for Section 1: Personal Information ---
  final _nameController = TextEditingController();
  final _icController = TextEditingController();
  final _ageController = TextEditingController(); 
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedGender;
  String? _selectedRace; 
  String? _selectedLanguage; 

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

  // --- Worker Documents (Images & PDFs) ---
  File? _passportImage; 
  File? _icFile;
  File? _licenseFile;
  File? _certFile;

  // --- Recipient Management (CLIENT) ---
  bool _isRegisteringForSelf = true;
  List<RecipientData> _recipients = [RecipientData()];

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

  Future<void> _pickProfileImage(AppLocalizations l10n) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, 
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.failedToPick(e.toString()))));
    }
  }

  Future<void> _pickPassportImage(AppLocalizations l10n) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, 
      );
      if (pickedFile != null) {
        setState(() {
          _passportImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.failedToPick(e.toString()))));
    }
  }

  Future<void> _pickDocumentFile(String docType, AppLocalizations l10n) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'], 
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          if (docType == 'IC') _icFile = File(result.files.single.path!);
          if (docType == 'License') _licenseFile = File(result.files.single.path!);
          if (docType == 'Cert') _certFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.failedToPick(e.toString()))));
    }
  }

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

  Future<void> _handleGoogleSignUp(AppLocalizations l10n) async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // FORCE Google Account Picker to display every single time.
      // Signing out first clears the cached session and resets the native dialog picker.
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // Safe to ignore if there was no active cached account
      }
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser != null) {
        setState(() {
          _emailController.text = googleUser.email; 
          if (_nameController.text.isEmpty) {
            _nameController.text = googleUser.displayName ?? "";
          }
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.googleAccountLinked)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $error')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addRecipient() {
    setState(() => _recipients.add(RecipientData()));
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
      _pageController.animateToPage(_currentSection, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _previousSection() {
    if (_currentSection > 0) {
      setState(() => _currentSection--);
      _pageController.animateToPage(_currentSection, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<void> _handleSignUp(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordsDoNotMatch)));
      return;
    }

    if (_selectedRole == 'Worker' && !_termsConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pleaseConfirmTerms)));
      return;
    }

    setState(() => _isLoading = true);

    // Convert Images & PDFs to Base64 Strings if picked
    String? base64Profile, base64Passport, base64Ic, base64License, base64Cert;
    
    if (_profileImage != null) base64Profile = base64Encode(await _profileImage!.readAsBytes());
    if (_passportImage != null) base64Passport = base64Encode(await _passportImage!.readAsBytes());
    if (_icFile != null) base64Ic = base64Encode(await _icFile!.readAsBytes());
    if (_licenseFile != null) base64License = base64Encode(await _licenseFile!.readAsBytes());
    if (_certFile != null) base64Cert = base64Encode(await _certFile!.readAsBytes());

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
      "race": _selectedRace ?? 'Malay', 
      "spoken_language": _selectedLanguage ?? 'Malay', 
      "address": _addressController.text,
      "email": _emailController.text,
      "password": _passwordController.text,
      "role": _selectedRole, // Role stays 'Client' or 'Worker' for DB
      "profile_image": base64Profile, 
      "passport_image": base64Passport,
      "ic_image": base64Ic,
      "license_image": base64License,
      "cert_image": base64Cert,
      "recipients": recipientsList,
      "worker_services": _selectedRole == 'Worker' ? _profInfo : null,
    };

    final result = await MysqlApiService.registerClient(registrationData);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: const Color(0xFF6B3F69)));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Initialized localization

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
                _buildHeader(l10n),
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
                                _buildSection1(l10n),
                                _buildSection2(l10n),
                                _selectedRole == 'Worker' ? _buildSection3Worker(l10n) : _buildSection3Client(l10n),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildNavigationButtons(l10n),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen())),
                  child: Text(l10n.alreadyHaveAccount, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickProfileImage(l10n),
          child: Container(
            width: 85, 
            height: 85,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: _profileImage != null
                ? ClipOval(child: Image.file(_profileImage!, fit: BoxFit.cover, width: 85, height: 85))
                : const Center(child: Icon(Icons.person_add_alt_1_outlined, size: 45, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 10),
        Text(l10n.signUpHeader(_selectedRole.toUpperCase()), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
        Text(l10n.sectionXofY(_currentSection + 1, _totalSections), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRoleToggle() {
    // Note: Role stays exactly "Client" or "Worker" internally for DB stability
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
        child: Text(role.toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSection1(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.personalInfo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 15),
          _buildTextField(controller: _nameController, label: l10n.fullName, icon: Icons.person_outline, l10n: l10n),
          const SizedBox(height: 12),
          _buildTextField(controller: _icController, label: l10n.icPassport, icon: Icons.badge_outlined, l10n: l10n),
          const SizedBox(height: 12),
          _buildTextField(controller: _ageController, label: l10n.yourAge, icon: Icons.cake_outlined, keyboardType: TextInputType.number, l10n: l10n),
          const SizedBox(height: 12),
          _buildTextField(controller: _phoneController, label: l10n.phoneNumber, icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone, l10n: l10n),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: _inputDecoration(l10n.gender, Icons.wc),
            items: [
              DropdownMenuItem(value: 'Male', child: Text(l10n.male)),
              DropdownMenuItem(value: 'Female', child: Text(l10n.female)),
            ],
            onChanged: (val) => setState(() => _selectedGender = val),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedRace,
            decoration: _inputDecoration(l10n.race, Icons.groups),
            items: [
              DropdownMenuItem(value: 'Malay', child: Text(l10n.malay)),
              DropdownMenuItem(value: 'Chinese', child: Text(l10n.chinese)),
              DropdownMenuItem(value: 'Indian', child: Text(l10n.indian)),
            ],
            onChanged: (val) => setState(() => _selectedRace = val),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: _inputDecoration(l10n.primaryLanguage, Icons.language),
            items: [
              DropdownMenuItem(value: 'Malay', child: Text(l10n.malay)),
              DropdownMenuItem(value: 'English', child: Text(l10n.english)),
              DropdownMenuItem(value: 'Mandarin', child: Text(l10n.mandarin)),
              DropdownMenuItem(value: 'Tamil', child: Text(l10n.tamil)),
            ],
            onChanged: (val) => setState(() => _selectedLanguage = val),
          ),
          const SizedBox(height: 12),
          _buildTextField(controller: _addressController, label: l10n.currentAddress, icon: Icons.home_outlined, maxLines: 2, l10n: l10n),
        ],
      ),
    );
  }

  Widget _buildSection2(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.accountSetup, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : () => _handleGoogleSignUp(l10n),
          icon: const Icon(Icons.login, color: Color(0xFF6B3F69)),
          label: Text(l10n.continueWithGoogle, style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Color(0xFF6B3F69)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(l10n.or, style: const TextStyle(color: Colors.grey, fontSize: 12))),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        _buildTextField(controller: _emailController, label: l10n.emailLabel, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, l10n: l10n),
        const SizedBox(height: 15),
        _buildTextField(controller: _passwordController, label: l10n.password, icon: Icons.lock_outline, isPassword: true, l10n: l10n),
        const SizedBox(height: 15),
        _buildTextField(controller: _confirmPasswordController, label: l10n.confirmPassword, icon: Icons.lock_reset_outlined, isPassword: true, l10n: l10n),
        const Spacer(),
        Text(l10n.termsAgreement, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSection3Client(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.careRecipientInfo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          _buildRecipientToggle(l10n),
          const SizedBox(height: 15),
          ..._recipients.asMap().entries.map((entry) => _buildRecipientForm(entry.key, entry.value, l10n)),
          if (!_isRegisteringForSelf)
            TextButton.icon(
              onPressed: _addRecipient,
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6B3F69)),
              label: Text(l10n.addAnotherRecipient, style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSection3Worker(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.professionalInfo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          _buildServiceCheckboxes(l10n),
          const SizedBox(height: 20),
          Text(l10n.certificateDocuments, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          
          _buildUploadItem(l10n.passportPicture, Icons.portrait_outlined, _passportImage, () => _pickPassportImage(l10n), l10n),
          _buildUploadItem(l10n.icPdf, Icons.picture_as_pdf_outlined, _icFile, () => _pickDocumentFile('IC', l10n), l10n),
          _buildUploadItem(l10n.drivingLicensePdf, Icons.picture_as_pdf_outlined, _licenseFile, () => _pickDocumentFile('License', l10n), l10n),
          _buildUploadItem(l10n.certificationsPdf, Icons.picture_as_pdf_outlined, _certFile, () => _pickDocumentFile('Cert', l10n), l10n),
          
          const SizedBox(height: 15),
          _buildTermsCheckbox(l10n),
        ],
      ),
    );
  }

  Widget _buildRecipientToggle(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.3), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          _buildToggleButton(l10n.registeringSelf, _isRegisteringForSelf, () {
            setState(() {
              _isRegisteringForSelf = true;
              _recipients = [RecipientData()];
            });
          }),
          _buildToggleButton(l10n.registeringOthers, !_isRegisteringForSelf, () {
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

  Widget _buildRecipientForm(int index, RecipientData data, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: const Color(0xFFDDC3C3)), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          if (_isRegisteringForSelf) ...[
            Text(l10n.healthInformation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6B3F69))),
            const SizedBox(height: 8),
          ],
          if (!_isRegisteringForSelf) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.recipientNumber(index + 1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6B3F69))),
                if (_recipients.length > 1) IconButton(onPressed: () => _removeRecipient(index), icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20)),
              ],
            ),
            _buildTextField(controller: data.nameController, label: l10n.fullName, icon: Icons.person_search_outlined, l10n: l10n),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 3, child: _buildTextField(controller: data.ageController, label: l10n.age, icon: Icons.cake_outlined, keyboardType: TextInputType.number, l10n: l10n)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: data.selectedRelationship,
                    decoration: _inputDecoration(l10n.relationship, Icons.people_outline),
                    items: [
                      DropdownMenuItem(value: 'Parent', child: Text(l10n.parent, style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Grandparent', child: Text(l10n.grandparent, style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Spouse', child: Text(l10n.spouse, style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Other', child: Text(l10n.other, style: const TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) => setState(() => data.selectedRelationship = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: data.selectedCondition,
            decoration: _inputDecoration(l10n.medicalCondition, Icons.medical_information_outlined),
            items: [
              DropdownMenuItem(value: 'High Blood Pressure', child: Text(l10n.highBloodPressure, style: const TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'Heart Disease & Stroke', child: Text(l10n.heartDisease, style: const TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'Diabetes', child: Text(l10n.diabetes, style: const TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'Others', child: Text(l10n.others, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (val) => setState(() => data.selectedCondition = val),
            validator: (v) => v == null ? l10n.pleaseSelectCondition : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(controller: data.needsController, label: l10n.specialNeeds, icon: Icons.note_alt_outlined, maxLines: 2, l10n: l10n),
        ],
      ),
    );
  }

  // Helper method to safely translate Map Keys for UI without changing DB values
  String _getServiceTranslation(String key, AppLocalizations l10n) {
    if (key == 'Mobility Service') return l10n.mobilityService;
    if (key == 'Physiotherapy/Rehabilitation') return l10n.physiotherapy;
    return l10n.nursingCare;
  }

  Widget _buildServiceCheckboxes(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: _profInfo.keys.map((key) => CheckboxListTile(
              title: Text(_getServiceTranslation(key, l10n), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              value: _profInfo[key],
              activeColor: const Color(0xFF6B3F69),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _profInfo[key] = v!),
            )).toList(),
      ),
    );
  }

  Widget _buildTermsCheckbox(AppLocalizations l10n) {
    return Row(
      children: [
        Checkbox(value: _termsConfirmed, activeColor: const Color(0xFF6B3F69), onChanged: (v) => setState(() => _termsConfirmed = v!)),
        Expanded(child: Text(l10n.confirmInfoTrue, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B3F69)))),
      ],
    );
  }

  Widget _buildNavigationButtons(AppLocalizations l10n) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)));
    return Row(
      children: [
        if (_currentSection > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousSection,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: const Color(0xFF6B3F69)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: Text(l10n.back, style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
            ),
          ),
        if (_currentSection > 0) const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: (_currentSection == _totalSections - 1) ? () => _handleSignUp(l10n) : _nextSection,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: Text((_currentSection == _totalSections - 1) ? l10n.signUp : l10n.next, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, int maxLines = 1, TextInputType keyboardType = TextInputType.text, required AppLocalizations l10n}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(label, icon),
      validator: (v) => v!.isEmpty ? l10n.requiredText : null,
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

  Widget _buildUploadItem(String label, IconData icon, File? selectedFile, VoidCallback onTap, AppLocalizations l10n) {
    bool isUploaded = selectedFile != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isUploaded ? Colors.green.withOpacity(0.1) : Colors.white,
            border: Border.all(color: isUploaded ? Colors.green : const Color(0xFFDDC3C3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isUploaded ? Colors.green : const Color(0xFF8D5F8C)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isUploaded ? '$label ${l10n.uploaded}' : label, 
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold,
                    color: isUploaded ? Colors.green[700] : Colors.black87
                  )
                )
              ),
              Icon(
                isUploaded ? Icons.check_circle : Icons.add_circle_outline, 
                size: 20, 
                color: isUploaded ? Colors.green : const Color(0xFFA376A2)
              ),
            ],
          ),
        ),
      ),
    );
  }
}