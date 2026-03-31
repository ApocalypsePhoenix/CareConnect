import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/mysql_api_service.dart';
import 'login_screen.dart';

class SettingClientScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SettingClientScreen({super.key, required this.user});

  @override
  State<SettingClientScreen> createState() => _SettingClientScreenState();
}

class _SettingClientScreenState extends State<SettingClientScreen> {
  late TextEditingController _nameController;
  late TextEditingController _icController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _ageController;
  String? _selectedGender;

  File? _newProfileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing user data
    _nameController = TextEditingController(text: widget.user['name']?.toString() ?? '');
    _icController = TextEditingController(text: widget.user['ic_number']?.toString() ?? '');
    _phoneController = TextEditingController(text: widget.user['phone']?.toString() ?? '');
    _addressController = TextEditingController(text: widget.user['address']?.toString() ?? '');
    _ageController = TextEditingController(text: widget.user['age']?.toString() ?? '');
    _selectedGender = widget.user['gender']?.toString();

    // Listen to IC changes for auto-detect
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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (pickedFile != null) {
        setState(() {
          _newProfileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _isSaving = true);

    String? base64Image;
    if (_newProfileImage != null) {
      List<int> imageBytes = await _newProfileImage!.readAsBytes();
      base64Image = base64Encode(imageBytes);
    }

    final updateData = {
      'id': widget.user['id'],
      'name': _nameController.text,
      'ic_number': _icController.text,
      'gender': _selectedGender,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'age': _ageController.text,
      'profile_image_base64': base64Image,
    };

    final result = await MysqlApiService.updateProfile(updateData);

    setState(() => _isSaving = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
        // Pass the updated user object back to the dashboard
        Navigator.pop(context, result['user']); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      }
    }
  }

  // Method to display the logout confirmation popup
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            // "No" Button - Closes the popup
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
              },
              child: const Text('No', style: TextStyle(color: Colors.grey)),
            ),
            // "Yes" Button - Logs out and navigates to Login Screen
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog first
                
                // Navigate to Login Screen and remove all previous routes 
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
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
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6B3F69),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Picture
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
                      decoration: const BoxDecoration(
                        color: Color(0xFF6B3F69),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(widget.user['email'], style: const TextStyle(color: Colors.grey, fontSize: 14)), // Read-only email
            const SizedBox(height: 30),

            // Form Fields
            _buildTextField(label: 'Full Name', controller: _nameController, icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField(label: 'I/C Number', controller: _icController, icon: Icons.badge_outlined),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(label: 'Age', controller: _ageController, icon: Icons.cake_outlined, keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: const Icon(Icons.wc, color: Color(0xFF8D5F8C)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5),
                      ),
                    ),
                    items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTextField(label: 'Phone Number', controller: _phoneController, icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField(label: 'Address', controller: _addressController, icon: Icons.home_outlined, maxLines: 2),
            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B3F69),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            
            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5),
        ),
      ),
    );
  }
}