import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:url_launcher/url_launcher.dart';
import '../services/mysql_api_service.dart';
import 'login_screen.dart';

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
  Future<void> _viewDocument(String? url, bool isImage) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No document currently uploaded.')));
      return;
    }
    
    final fullUrl = 'https://arcadiusengine.xyz/careconnect/$url';
    
    if (isImage) {
      // Show images directly in the app
      showDialog(
        context: context, 
        builder: (c) => AlertDialog(
          contentPadding: const EdgeInsets.all(10),
          content: Image.network(fullUrl),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close', style: TextStyle(color: Color(0xFF6B3F69))))],
        )
      );
    } else {
      // FIX: Wrap the PDF URL in Google Docs Viewer so mobile browsers render it beautifully
      // instead of printing out raw PDF binary text!
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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null) setState(() => _newProfileImage = File(pickedFile.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _pickPassportImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null) setState(() => _passportImage = File(pickedFile.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick passport image: $e')));
    }
  }

  Future<void> _pickDocumentFile(String docType) async {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick document: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
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
              ? 'Profile updated! Changes sent for Admin review.' 
              : 'Profile updated successfully!'), 
            backgroundColor: Colors.green
          )
        );
        Navigator.pop(context, result['user']); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      }
    }
  }

  void _showChangePasswordDialog() {
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
              title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(label: 'Current Password', controller: oldPasswordController, icon: Icons.lock_outline, isPassword: true),
                  const SizedBox(height: 10),
                  _buildTextField(label: 'New Password', controller: newPasswordController, icon: Icons.lock_reset, isPassword: true),
                  const SizedBox(height: 10),
                  _buildTextField(label: 'Confirm New Password', controller: confirmPasswordController, icon: Icons.check_circle_outline, isPassword: true),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isUpdatingPassword ? null : () async {
                    if (oldPasswordController.text.isEmpty || newPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields.')));
                      return;
                    }
                    if (newPasswordController.text != confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match.')));
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: isUpdatingPassword ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Update', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); 
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Worker Settings', style: TextStyle(color: Colors.white)),
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
                    onTap: _pickImage,
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

            const Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 15),
            _buildTextField(label: 'Full Name', controller: _nameController, icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField(label: 'I/C Number', controller: _icController, icon: Icons.badge_outlined),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(flex: 2, child: _buildTextField(label: 'Age', controller: _ageController, icon: Icons.cake_outlined, keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: _buildDropdown(label: 'Gender', value: _selectedGender, icon: Icons.wc, items: ['Male', 'Female'], onChanged: (val) => setState(() => _selectedGender = val))),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildDropdown(label: 'Race', value: _selectedRace, icon: Icons.groups, items: ['Malay', 'Chinese', 'Indian'], onChanged: (val) => setState(() => _selectedRace = val))),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdown(label: 'Language', value: _selectedLanguage, icon: Icons.language, items: ['Malay', 'English', 'Mandarin', 'Tamil'], onChanged: (val) => setState(() => _selectedLanguage = val))),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTextField(label: 'Phone Number', controller: _phoneController, icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField(label: 'Address', controller: _addressController, icon: Icons.home_outlined, maxLines: 2),
            const SizedBox(height: 30),

            const Text('Professional Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
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
            const SizedBox(height: 30),

            // DOCUMENT RE-UPLOAD SECTION
            const Text('Update Certificates / Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 5),
            const Text('Changing services or uploading new documents will send your profile for Admin review. You can continue working in the meantime.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            
            _buildUploadItem('Passport Style Picture', Icons.portrait_outlined, _passportImage, widget.user['profile_pic_url'], true, _pickPassportImage),
            _buildUploadItem('I/C or Passport (PDF)', Icons.picture_as_pdf_outlined, _icFile, widget.user['ic_doc_url'], false, () => _pickDocumentFile('IC')),
            _buildUploadItem('Driving License (PDF)', Icons.picture_as_pdf_outlined, _licenseFile, widget.user['license_doc_url'], false, () => _pickDocumentFile('License')),
            _buildUploadItem('Certifications (PDF)', Icons.picture_as_pdf_outlined, _certFile, widget.user['cert_doc_url'], false, () => _pickDocumentFile('Cert')),
            
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showChangePasswordDialog,
                    icon: const Icon(Icons.lock_reset, color: Color(0xFF6B3F69)),
                    label: const Text('Password', style: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Color(0xFF6B3F69)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

  Widget _buildTextField({required String label, required TextEditingController controller, required IconData icon, TextInputType keyboardType = TextInputType.text, int maxLines = 1, bool isPassword = false}) {
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

  Widget _buildDropdown({required String label, required String? value, required IconData icon, required List<String> items, required Function(String?) onChanged}) {
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
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildUploadItem(String label, IconData icon, File? selectedNewFile, String? existingUrl, bool isImage, VoidCallback onUpload) {
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
                  Text('$label Options', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6B3F69))),
                  const SizedBox(height: 10),
                  
                  if (hasExisting && !hasNewFile)
                    ListTile(
                      leading: const Icon(Icons.visibility, color: Colors.blue),
                      title: const Text('View Current Document'),
                      onTap: () {
                        Navigator.pop(context);
                        _viewDocument(existingUrl, isImage);
                      },
                    ),
                  
                  ListTile(
                    leading: Icon(hasNewFile ? Icons.edit : Icons.upload_file, color: Colors.green),
                    title: Text(hasNewFile ? 'Change Selected File' : 'Upload New Document'),
                    onTap: () {
                      Navigator.pop(context);
                      onUpload();
                    },
                  ),
                  
                  if (hasNewFile)
                    ListTile(
                      leading: const Icon(Icons.undo, color: Colors.orange),
                      title: const Text('Cancel New Upload (Keep Old)'),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          if (label.contains('Passport')) _passportImage = null;
                          if (label.contains('I/C')) _icFile = null;
                          if (label.contains('License')) _licenseFile = null;
                          if (label.contains('Certifications')) _certFile = null;
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
                    ? '$label (Ready to Upload)' 
                    : hasExisting ? '$label (Uploaded)' : label, 
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