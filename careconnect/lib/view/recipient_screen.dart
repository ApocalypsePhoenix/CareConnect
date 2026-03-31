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
          // Filter out the recipient if the relationship is 'Self'
          _recipients = (result['recipients'] as List)
              .where((recipient) => recipient['relationship'].toString().toLowerCase() != 'self')
              .toList();
        }
        _isLoading = false;
      });
    }
  }

  void _showAddRecipientDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController ageController = TextEditingController();
    TextEditingController specialNeedsController = TextEditingController();

    final List<String> relationshipOptions = ['Parent', 'Grandparent', 'Spouse', 'Others'];
    final List<String> medicalOptions = ['High blood pressure', 'Heart diseases and stroke', 'Diabetes', 'Others'];

    String? selectedRelationship;
    String? selectedMedicalCondition;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(20),
              backgroundColor: const Color(0xFFF8F9FA),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Add New Care Recipient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Full Name'),
                    _buildTextField(
                      controller: nameController,
                      hintText: 'e.g. John Doe',
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('Relationship'),
                    _buildDropdown(
                      value: selectedRelationship,
                      options: relationshipOptions,
                      onChanged: (val) => setState(() => selectedRelationship = val),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('Age'),
                    _buildTextField(
                      controller: ageController,
                      hintText: 'e.g. 65',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('Medical Conditions'),
                    _buildDropdown(
                      value: selectedMedicalCondition,
                      options: medicalOptions,
                      onChanged: (val) => setState(() => selectedMedicalCondition = val),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('Special Needs (Optional)'),
                    _buildTextField(
                      controller: specialNeedsController,
                      hintText: 'Any specific requirements or notes...',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Full-width Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a name.'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setState(() => isSaving = true);
                          
                          // Call the API service to insert into the database
                          final success = await MysqlApiService.addRecipient(
                            userId: int.parse(widget.user['id'].toString()),
                            name: nameController.text,
                            relationship: selectedRelationship ?? 'Others',
                            age: ageController.text,
                            medicalCondition: selectedMedicalCondition ?? 'Others',
                            specialNeeds: specialNeedsController.text,
                          );

                          setState(() => isSaving = false);

                          if (mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Recipient added successfully!'), backgroundColor: Colors.green),
                              );
                              Navigator.pop(context); // Close the popup
                              _fetchRecipients(); // Refresh your list
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to add recipient.'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B3F69),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSaving
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
                  ],
                ),
              ),
            );
          }
        );
      }
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
            onPressed: () {
              Navigator.pop(context); // Close the detail dialog first
              _showEditRecipientPopup(recipient); // Open the edit popup instead of full screen
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

  // Edit Recipient Popup
  void _showEditRecipientPopup(Map<String, dynamic> recipient) {
    TextEditingController nameController = TextEditingController(text: recipient['name']?.toString() ?? '');
    TextEditingController ageController = TextEditingController(text: recipient['age']?.toString() ?? '');
    TextEditingController specialNeedsController = TextEditingController(text: recipient['special_needs']?.toString() ?? '');

    final List<String> relationshipOptions = ['Parent', 'Grandparent', 'Spouse', 'Others'];
    final List<String> medicalOptions = ['High blood pressure', 'Heart diseases and stroke', 'Diabetes', 'Others'];

    String? selectedRelationship;
    String existingRel = recipient['relationship']?.toString().toLowerCase().trim() ?? '';
    try {
      selectedRelationship = relationshipOptions.firstWhere((opt) => opt.toLowerCase() == existingRel);
    } catch (e) {
      selectedRelationship = 'Others';
    }

    String? selectedMedicalCondition;
    String existingMed = recipient['medical_condition']?.toString().toLowerCase().trim() ?? '';
    try {
      selectedMedicalCondition = medicalOptions.firstWhere((opt) => opt.toLowerCase() == existingMed);
    } catch (e) {
      selectedMedicalCondition = 'Others';
    }

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(20),
              backgroundColor: const Color(0xFFF8F9FA),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Navigator.pop(context); // Close edit dialog
                            _showRecipientDetails(recipient); // Go back to details
                          },
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Edit Care Recipient Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Full Name'),
                    _buildTextField(
                      controller: nameController,
                      hintText: 'e.g. John Doe',
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('Relationship'),
                    _buildDropdown(
                      value: selectedRelationship,
                      options: relationshipOptions,
                      onChanged: (val) => setState(() => selectedRelationship = val),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('Age'),
                    _buildTextField(
                      controller: ageController,
                      hintText: 'e.g. 65',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('Medical Conditions'),
                    _buildDropdown(
                      value: selectedMedicalCondition,
                      options: medicalOptions,
                      onChanged: (val) => setState(() => selectedMedicalCondition = val),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('Special Needs (Optional)'),
                    _buildTextField(
                      controller: specialNeedsController,
                      hintText: 'Any specific requirements or notes...',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Full-width Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          setState(() => isSaving = true);
                          
                          String safeId = recipient['id']?.toString() ?? '';
                          if (safeId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error: Recipient ID is missing.'), backgroundColor: Colors.red),
                            );
                            setState(() => isSaving = false);
                            return;
                          }

                          // Call the API service to update the database
                          final success = await MysqlApiService.updateRecipient(
                            id: safeId,
                            name: nameController.text,
                            relationship: selectedRelationship ?? 'Others',
                            age: ageController.text,
                            medicalCondition: selectedMedicalCondition ?? 'Others',
                            specialNeeds: specialNeedsController.text,
                          );

                          setState(() => isSaving = false);

                          if (mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Recipient updated successfully!'), backgroundColor: Colors.green),
                              );
                              Navigator.pop(context); // Close the popup
                              _fetchRecipients(); // Refresh your list
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to update recipient.'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B3F69),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSaving
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
                  ],
                ),
              ),
            );
          }
        );
      }
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