import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';

class RecipientScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const RecipientScreen({super.key, required this.user});

  @override
  State<RecipientScreen> createState() => _RecipientScreenState();
}

class _RecipientScreenState extends State<RecipientScreen> {
  List<dynamic> _recipients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecipients();
  }

  Future<void> _fetchRecipients() async {
    setState(() => _isLoading = true);
    final result = await MysqlApiService.getRecipients(int.parse(widget.user['id'].toString()));
    if (mounted) {
      setState(() {
        if (result['success']) {
          _recipients = result['recipients'];
        }
        _isLoading = false;
      });
    }
  }

  void _showAddRecipientDialog() {
    // TODO: Build your actual form to insert a new recipient into the database
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Recipient'),
        content: const Text('Add your form fields (Name, Relationship, Age, etc.) here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add recipient functionality coming soon!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Method to show all details of a specific recipient
  void _showRecipientDetails(Map<String, dynamic> recipient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFDDC3C3).withOpacity(0.5),
              radius: 24,
              child: Text(
                recipient['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                recipient['name']?.toString() ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69), fontSize: 22),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 30),
              _buildDetailRow(Icons.family_restroom, 'Relationship', recipient['relationship']),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.cake, 'Age', recipient['age']),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.medical_services, 'Medical Conditions', recipient['medical_condition']),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.note_alt_outlined, 'Notes', recipient['special_needs']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context); // Close the detail dialog first
              
              // Push the new full-screen Edit page
              final bool? updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditRecipientScreen(recipient: recipient),
                ),
              );

              // If the user saved changes, refresh the list
              if (updated == true) {
                _fetchRecipients();
              }
            },
            icon: const Icon(Icons.edit, size: 18, color: Colors.white),
            label: const Text('Edit', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B3F69),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to build consistent detail rows in the dialog
  Widget _buildDetailRow(IconData icon, String label, dynamic value) {
    final String displayValue = (value == null || value.toString().trim().isEmpty) 
        ? 'Not specified' 
        : value.toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                displayValue,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Care Recipients', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6B3F69),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
          : _recipients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No recipients found.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add new recipient here!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddRecipientDialog,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Add Recipient', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B3F69),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recipients.length,
                  itemBuilder: (context, index) {
                    final recipient = _recipients[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFDDC3C3).withOpacity(0.5),
                          child: Text(
                            recipient['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                            style: const TextStyle(
                                color: Color(0xFF6B3F69), fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          recipient['name']?.toString() ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Relationship: ${recipient['relationship']}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => _showRecipientDetails(recipient), // Tapping opens the detail dialog
                      ),
                    );
                  },
                ),
      floatingActionButton: _recipients.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddRecipientDialog,
              backgroundColor: const Color(0xFF6B3F69),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add New', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

// ----------------------------------------------------------------------
// NEW EDIT RECIPIENT SCREEN (Matches your screenshot UI)
// ----------------------------------------------------------------------
class EditRecipientScreen extends StatefulWidget {
  final Map<String, dynamic> recipient;

  const EditRecipientScreen({super.key, required this.recipient});

  @override
  State<EditRecipientScreen> createState() => _EditRecipientScreenState();
}

class _EditRecipientScreenState extends State<EditRecipientScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _specialNeedsController;

  String? _selectedRelationship;
  String? _selectedMedicalCondition;
  bool _isSaving = false;

  final List<String> _relationshipOptions = [
    'Parent', 
    'Grandparent', 
    'Spouse', 
    'Others'
  ];

  final List<String> _medicalOptions = [
    'High blood pressure', 
    'Heart diseases and stroke', 
    'Diabetes', 
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    // Convert everything strictly to String to avoid the "type 'int' is not a subtype of type 'String'" cast error
    _nameController = TextEditingController(text: widget.recipient['name']?.toString() ?? '');
    _ageController = TextEditingController(text: widget.recipient['age']?.toString() ?? '');
    _specialNeedsController = TextEditingController(text: widget.recipient['special_needs']?.toString() ?? '');

    // Safely assign relationship value matching one of the dropdown options
    String existingRel = widget.recipient['relationship']?.toString().toLowerCase().trim() ?? '';
    try {
      _selectedRelationship = _relationshipOptions.firstWhere(
        (opt) => opt.toLowerCase() == existingRel,
      );
    } catch (e) {
      _selectedRelationship = 'Others'; // Fallback if no match is found
    }

    // Safely assign medical condition matching one of the dropdown options
    String existingMed = widget.recipient['medical_condition']?.toString().toLowerCase().trim() ?? '';
    try {
      _selectedMedicalCondition = _medicalOptions.firstWhere(
        (opt) => opt.toLowerCase() == existingMed,
      );
    } catch (e) {
      _selectedMedicalCondition = 'Others'; // Fallback if no match is found
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _specialNeedsController.dispose();
    super.dispose();
  }

  Future<void> _saveRecipient() async {
    setState(() => _isSaving = true);
    
    // Convert ID to string defensively
    String safeId = widget.recipient['id']?.toString() ?? '';
    
    if (safeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Recipient ID is missing.'), backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
      return;
    }

    // Call the API service to update the database
    final success = await MysqlApiService.updateRecipient(
      id: safeId,
      name: _nameController.text,
      relationship: _selectedRelationship ?? 'Others',
      age: _ageController.text,
      medicalCondition: _selectedMedicalCondition ?? 'Others',
      specialNeeds: _specialNeedsController.text,
    );
    
    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipient updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Pop and return true so the previous screen knows to refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update recipient.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B3F69),
        title: const Text('Edit Care Recipient Details', style: TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Full Name'),
            _buildTextField(
              controller: _nameController,
              hintText: 'e.g. John Doe',
            ),
            const SizedBox(height: 20),

            _buildLabel('Relationship'),
            _buildDropdown(
              value: _selectedRelationship,
              options: _relationshipOptions,
              onChanged: (val) => setState(() => _selectedRelationship = val),
            ),
            const SizedBox(height: 20),

            _buildLabel('Age'),
            _buildTextField(
              controller: _ageController,
              hintText: 'e.g. 65',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            _buildLabel('Medical Conditions'),
            _buildDropdown(
              value: _selectedMedicalCondition,
              options: _medicalOptions,
              onChanged: (val) => setState(() => _selectedMedicalCondition = val),
            ),
            const SizedBox(height: 20),

            _buildLabel('Special Needs (Optional)'),
            _buildTextField(
              controller: _specialNeedsController,
              hintText: 'Any specific requirements or notes...',
              maxLines: 4,
            ),
            const SizedBox(height: 40),

            // Full-width Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRecipient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B3F69),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24, height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text(
                        'Save', 
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Label builder
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
      ),
    );
  }

  // Text field builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5),
        ),
      ),
    );
  }

  // Dropdown builder
  Widget _buildDropdown({
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5),
        ),
      ),
      isExpanded: true,
      items: options.map((String opt) {
        return DropdownMenuItem<String>(
          value: opt,
          child: Text(opt, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}