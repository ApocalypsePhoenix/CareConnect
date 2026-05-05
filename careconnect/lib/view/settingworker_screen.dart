import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:url_launcher/url_launcher.dart';
import '../services/mysql_api_service.dart';
import 'login_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED
import '../main.dart'; // ADDED: Connects to the Global Magic Switch

class SettingWorkerScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SettingWorkerScreen({super.key, required this.user});

  @override
  State<SettingWorkerScreen> createState() => _SettingWorkerScreenState();
}

class _SettingWorkerScreenState extends State<SettingWorkerScreen> {
  late TextEditingController _nameController;
  late TextEditingController _icController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _ageController;
  
  String? _selectedGender;
  String? _selectedRace;
  String? _selectedLanguage;

  late Map<String, bool> _profInfo;

  // Image & Document States
  File? _newProfileImage;
  File? _passportImage; 
  File? _icFile;
  File? _licenseFile;
  File? _certFile;

  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  // Helper to view existing documents
  Future<void> _viewDocument(String? url, bool isImage, AppLocalizations l10n) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noDocumentUploaded)));
      return;
    }
    
    final fullUrl = 'https://arcadiusengine.xyz/careconnect/$url';
    
    if (isImage) {
      showDialog(
        context: context, 
        builder: (c) => AlertDialog(
          contentPadding: const EdgeInsets.all(10),
          content: Image.network(fullUrl),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.close, style: const TextStyle(color: Color(0xFF6B3F69))))],
        )
      );
    } else {
      final encodedUrl = Uri.encodeComponent(fullUrl);
      final googleViewerUrl = 'https://docs.google.com/viewer?url=$encodedUrl';
      final uri = Uri.parse(googleViewerUrl);
      
      try {
        bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document. No compatible app found.')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening document: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']?.toString() ?? '');
    _icController = TextEditingController(text: widget.user['ic_number']?.toString() ?? '');
    _phoneController = TextEditingController(text: widget.user['phone']?.toString() ?? '');
    _addressController = TextEditingController(text: widget.user['address']?.toString() ?? '');
    _ageController = TextEditingController(text: widget.user['age']?.toString() ?? '');
    
    _selectedGender = widget.user['gender']?.toString();
    _selectedRace = widget.user['race']?.toString();
    _selectedLanguage = widget.user['spoken_language']?.toString();

    _profInfo = {
      'Mobility Service': widget.user['mobility_service'] == 1 || widget.user['mobility_service'] == '1',
      'Physiotherapy/Rehabilitation': widget.user['physio_service'] == 1 || widget.user['physio_service'] == '1',
      'Daily Assistance/Nursing Care': widget.user['nursing_service'] == 1 || widget.user['nursing_service'] == '1',
    };

    _icController.addListener(_onIcChanged);
  }

  @override
  void dispose() {
    _icController.removeListener(_onIcChanged);
    _nameController.dispose();
    _icController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    super.dispose();
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

  Future<void> _pickImage(AppLocalizations l10n) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null) setState(() => _newProfileImage = File(pickedFile.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.failedToPick(e.toString()))));
    }
  }

  Future<void> _pickPassportImage(AppLocalizations l10n) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null) setState(() => _passportImage = File(pickedFile.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.failedToPick(e.toString()))));
    }
  }

  Future<void> _pickDocumentFile(String docType, AppLocalizations l10n) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.single.path != null) {
        setState(() {
          if (docType == 'IC') _icFile = File(result.files.single.path!);
          if (docType == 'License') _licenseFile = File(result.files.single.path!);
          if (docType == 'Cert') _certFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.failedToPick(e.toString()))));
    }
  }

  Future<void> _saveProfile(AppLocalizations l10n) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nameCannotBeEmpty)));
      return;
    }

    setState(() => _isSaving = true);

    String? base64Image, base64Passport, base64Ic, base64License, base64Cert;
    
    if (_newProfileImage != null) base64Image = base64Encode(await _newProfileImage!.readAsBytes());
    if (_passportImage != null) base64Passport = base64Encode(await _passportImage!.readAsBytes());
    if (_icFile != null) base64Ic = base64Encode(await _icFile!.readAsBytes());
    if (_licenseFile != null) base64License = base64Encode(await _licenseFile!.readAsBytes());
    if (_certFile != null) base64Cert = base64Encode(await _certFile!.readAsBytes());

    // Check if services were modified compared to what's currently in widget.user
    bool servicesChanged = false;
    bool oldMob = widget.user['mobility_service'] == 1 || widget.user['mobility_service'] == '1';
    bool oldPhy = widget.user['physio_service'] == 1 || widget.user['physio_service'] == '1';
    bool oldNur = widget.user['nursing_service'] == 1 || widget.user['nursing_service'] == '1';
    
    if (_profInfo['Mobility Service'] != oldMob || _profInfo['Physiotherapy/Rehabilitation'] != oldPhy || _profInfo['Daily Assistance/Nursing Care'] != oldNur) {
      servicesChanged = true;
    }

    final updateData = {
      'id': widget.user['id'],
      'name': _nameController.text,
      'ic_number': _icController.text,
      'gender': _selectedGender,
      'race': _selectedRace ?? 'Malay',
      'spoken_language': _selectedLanguage ?? 'Malay',
      'phone': _phoneController.text,
      'address': _addressController.text,
      'age': _ageController.text,
      'profile_image_base64': base64Image,
      'passport_image_base64': base64Passport, 
      'ic_image_base64': base64Ic,
      'license_image_base64': base64License,
      'cert_image_base64': base64Cert,
      'worker_services': _profInfo, 
    };

    final result = await MysqlApiService.updateProfile(updateData);

    setState(() => _isSaving = false);

    if (mounted) {
      if (result['success']) {
        bool uploadedDocs = base64Passport != null || base64Ic != null || base64License != null || base64Cert != null;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((uploadedDocs || servicesChanged)
              ? l10n.profileUpdatedAdminReview 
              : l10n.profileUpdated), 
            backgroundColor: Colors.green
          )
        );
        Navigator.pop(context, result['user']); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      }
    }
  }

  void _showChangePasswordDialog(AppLocalizations l10n) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdatingPassword = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(l10n.changePassword, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(label: l10n.currentPassword, controller: oldPasswordController, icon: Icons.lock_outline, isPassword: true, l10n: l10n),
                  const SizedBox(height: 10),
                  _buildTextField(label: l10n.newPassword, controller: newPasswordController, icon: Icons.lock_reset, isPassword: true, l10n: l10n),
                  const SizedBox(height: 10),
                  _buildTextField(label: l10n.confirmNewPassword, controller: confirmPasswordController, icon: Icons.check_circle_outline, isPassword: true, l10n: l10n),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isUpdatingPassword ? null : () async {
                    if (oldPasswordController.text.isEmpty || newPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fillAllFields)));
                      return;
                    }
                    if (newPasswordController.text != confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordsDoNotMatch)));
                      return;
                    }

                    setDialogState(() => isUpdatingPassword = true);

                    final result = await MysqlApiService.changePassword(
                      widget.user['id'].toString(),
                      oldPasswordController.text,
                      newPasswordController.text,
                    );

                    setDialogState(() => isUpdatingPassword = false);

                    if (mounted) {
                      if (result['success']) {
                        Navigator.pop(context); 
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordUpdated), backgroundColor: Colors.green));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: isUpdatingPassword ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(l10n.update, style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showLogoutDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(l10n.logout, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(l10n.logoutConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.no, style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); 
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: Text(l10n.yes),
            ),
          ],
        );
      },
    );
  }

  // Helper method to safely translate Map Keys for UI without changing DB values
  String _getServiceTranslation(String key, AppLocalizations l10n) {
    if (key == 'Mobility Service') return l10n.mobilityService;
    if (key == 'Physiotherapy/Rehabilitation') return l10n.physiotherapy;
    return l10n.nursingCare;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // TRANSLATION ENGINE LOADED

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.workerSettings, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6B3F69),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFDDC3C3).withOpacity(0.5),
                    backgroundImage: _newProfileImage != null
                        ? FileImage(_newProfileImage!) as ImageProvider
                        : (widget.user['profile_image'] != null && widget.user['profile_image'].toString().isNotEmpty)
                            ? NetworkImage('https://arcadiusengine.xyz/careconnect/${widget.user['profile_image']}')
                            : null,
                    child: (_newProfileImage == null && (widget.user['profile_image'] == null || widget.user['profile_image'].toString().isEmpty))
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                  GestureDetector(
                    onTap: () => _pickImage(l10n),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFF6B3F69), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Text(widget.user['email'], style: const TextStyle(color: Colors.grey, fontSize: 14))),
            const SizedBox(height: 30),

            // ==============================================================
            // APP LANGUAGE SWITCHER
            // ==============================================================
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: const Icon(Icons.language, color: Color(0xFF6B3F69)),
                title: Text(l10n.appLanguage, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: ValueListenableBuilder<Locale>(
                  valueListenable: appLocale,
                  builder: (context, currentLocale, child) {
                    return DropdownButton<String>(
                      value: currentLocale.languageCode,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
                        DropdownMenuItem(value: 'ms', child: Text(l10n.languageMalay)),
                      ],
                      onChanged: (String? newLanguageCode) {
                        if (newLanguageCode != null) {
                          appLocale.value = Locale(newLanguageCode);
                        }
                      },
                    );
                  }
                ),
              ),
            ),
            const SizedBox(height: 30),
            // ==============================================================

            Text(l10n.personalInfo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 15),
            _buildTextField(label: l10n.fullName, controller: _nameController, icon: Icons.person_outline, l10n: l10n),
            const SizedBox(height: 16),
            _buildTextField(label: l10n.icNumber, controller: _icController, icon: Icons.badge_outlined, l10n: l10n),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(flex: 2, child: _buildTextField(label: l10n.age, controller: _ageController, icon: Icons.cake_outlined, keyboardType: TextInputType.number, l10n: l10n)),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: _buildDropdown(
                  label: l10n.gender, 
                  value: _selectedGender, 
                  icon: Icons.wc, 
                  items: ['Male', 'Female'], 
                  onChanged: (val) => setState(() => _selectedGender = val),
                  l10n: l10n,
                )),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildDropdown(
                  label: l10n.race, 
                  value: _selectedRace, 
                  icon: Icons.groups, 
                  items: ['Malay', 'Chinese', 'Indian'], 
                  onChanged: (val) => setState(() => _selectedRace = val),
                  l10n: l10n,
                )),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdown(
                  label: l10n.language, 
                  value: _selectedLanguage, 
                  icon: Icons.language, 
                  items: ['Malay', 'English', 'Mandarin', 'Tamil'], 
                  onChanged: (val) => setState(() => _selectedLanguage = val),
                  l10n: l10n,
                )),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTextField(label: l10n.phoneNumber, controller: _phoneController, icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone, l10n: l10n),
            const SizedBox(height: 16),
            _buildTextField(label: l10n.address, controller: _addressController, icon: Icons.home_outlined, maxLines: 2, l10n: l10n),
            const SizedBox(height: 30),

            Text(l10n.professionalInfo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: _profInfo.keys.map((key) => CheckboxListTile(
                      title: Text(_getServiceTranslation(key, l10n), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      value: _profInfo[key],
                      activeColor: const Color(0xFF6B3F69),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => _profInfo[key] = v!),
                    )).toList(),
              ),
            ),
            const SizedBox(height: 30),

            // DOCUMENT RE-UPLOAD SECTION
            Text(l10n.updateCertificates, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 5),
            Text(l10n.adminReviewNotice, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            
            _buildUploadItem(l10n.passportPicture, Icons.portrait_outlined, _passportImage, widget.user['profile_pic_url'], true, () => _pickPassportImage(l10n), l10n),
            _buildUploadItem(l10n.icPdf, Icons.picture_as_pdf_outlined, _icFile, widget.user['ic_doc_url'], false, () => _pickDocumentFile('IC', l10n), l10n),
            _buildUploadItem(l10n.drivingLicensePdf, Icons.picture_as_pdf_outlined, _licenseFile, widget.user['license_doc_url'], false, () => _pickDocumentFile('License', l10n), l10n),
            _buildUploadItem(l10n.certificationsPdf, Icons.picture_as_pdf_outlined, _certFile, widget.user['cert_doc_url'], false, () => _pickDocumentFile('Cert', l10n), l10n),
            
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _saveProfile(l10n),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(l10n.saveChanges, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showChangePasswordDialog(l10n),
                    icon: const Icon(Icons.lock_reset, color: Color(0xFF6B3F69)),
                    label: Text(l10n.password, style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Color(0xFF6B3F69)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context, l10n),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: Text(l10n.logout, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required IconData icon, TextInputType keyboardType = TextInputType.text, int maxLines = 1, bool isPassword = false, required AppLocalizations l10n}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5)),
      ),
    );
  }

  Widget _buildDropdown({required String label, required String? value, required IconData icon, required List<String> items, required Function(String?) onChanged, required AppLocalizations l10n}) {
    return DropdownButtonFormField<String>(
      value: value,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5)),
      ),
      // Visually translate the items while keeping the actual string value safe!
      items: items.map((i) {
        String display = i;
        if (i == 'Male') display = l10n.male;
        if (i == 'Female') display = l10n.female;
        if (i == 'Malay') display = l10n.malay;
        if (i == 'Chinese') display = l10n.chinese;
        if (i == 'Indian') display = l10n.indian;
        if (i == 'English') display = l10n.english;
        if (i == 'Mandarin') display = l10n.mandarin;
        if (i == 'Tamil') display = l10n.tamil;
        return DropdownMenuItem(value: i, child: Text(display, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildUploadItem(String label, IconData icon, File? selectedNewFile, String? existingUrl, bool isImage, VoidCallback onUpload, AppLocalizations l10n) {
    bool hasNewFile = selectedNewFile != null;
    bool hasExisting = existingUrl != null && existingUrl.toString().isNotEmpty;
    bool isReady = hasNewFile || hasExisting;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 15),
                  Text('$label ${l10n.options}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6B3F69))),
                  const SizedBox(height: 10),
                  
                  if (hasExisting && !hasNewFile)
                    ListTile(
                      leading: const Icon(Icons.visibility, color: Colors.blue),
                      title: Text(l10n.viewCurrentDocument),
                      onTap: () {
                        Navigator.pop(context);
                        _viewDocument(existingUrl, isImage, l10n);
                      },
                    ),
                  
                  ListTile(
                    leading: Icon(hasNewFile ? Icons.edit : Icons.upload_file, color: Colors.green),
                    title: Text(hasNewFile ? l10n.changeSelectedFile : l10n.uploadNewDocument),
                    onTap: () {
                      Navigator.pop(context);
                      onUpload();
                    },
                  ),
                  
                  if (hasNewFile)
                    ListTile(
                      leading: const Icon(Icons.undo, color: Colors.orange),
                      title: Text(l10n.cancelNewUpload),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          if (label.contains('Passport') || label.contains('Pasport')) _passportImage = null;
                          if (label.contains('I/C') || label.contains('K/P')) _icFile = null;
                          if (label.contains('License') || label.contains('Lesen')) _licenseFile = null;
                          if (label.contains('Certifications') || label.contains('Sijil')) _certFile = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isReady ? Colors.green.withOpacity(0.1) : Colors.white,
            border: Border.all(color: isReady ? Colors.green : const Color(0xFFDDC3C3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isReady ? Colors.green : const Color(0xFF8D5F8C)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasNewFile 
                    ? '$label ${l10n.readyToUpload}' 
                    : hasExisting ? '$label ${l10n.uploaded}' : label, 
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isReady ? Colors.green[700] : Colors.black87)
                )
              ),
              Icon(hasNewFile ? Icons.cloud_upload : (hasExisting ? Icons.check_circle : Icons.add_circle_outline), size: 20, color: isReady ? Colors.green : const Color(0xFFA376A2)),
            ],
          ),
        ),
      ),
    );
  }
}