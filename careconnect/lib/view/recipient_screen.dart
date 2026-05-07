import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED LOCALIZATION

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

  // --- LOCAL TRANSLATION HELPER (Saves you from editing the dictionary!) ---
  String _getLocalText(String key, String lang) {
    if (lang == 'ms') {
      switch (key) {
        case 'Delete Recipient': return 'Padam Penerima';
        case 'DeleteConfirm': return 'Adakah anda pasti mahu memadam penerima penjagaan ini? Tindakan ini tidak boleh dipulihkan.';
        case 'Delete': return 'Padam';
        case 'Edit': return 'Sunting';
        case 'Add New Care Recipient': return 'Tambah Penerima Penjagaan Baru';
        case 'Edit Care Recipient Details': return 'Sunting Butiran Penerima';
        case 'egName': return 'cth. Ahmad Bin Abu';
        case 'egAge': return 'cth. 65';
        case 'notesHint': return 'Sebarang keperluan khusus atau nota...';
        case 'Save': return 'Simpan';
        case 'Add new recipient here!': return 'Tambah penerima baru di sini!';
        case 'Notes': return 'Nota';
        case '(Optional)': return '(Pilihan)'; // <--- Added this translation!
      }
    }
    // English Defaults
    switch (key) {
      case 'DeleteConfirm': return 'Are you sure you want to delete this care recipient? This action cannot be undone.';
      case 'egName': return 'e.g. John Doe';
      case 'egAge': return 'e.g. 65';
      case 'notesHint': return 'Any specific requirements or notes...';
      case '(Optional)': return '(Optional)'; // <--- Added this translation!
      default: return key;
    }
    return key;
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteRecipient(String id, AppLocalizations l10n, String lang) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_getLocalText('Delete Recipient', lang), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(_getLocalText('DeleteConfirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_getLocalText('Delete', lang), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      setState(() => _isLoading = true);
      
      final success = await MysqlApiService.deleteRecipient(id);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipient deleted successfully!'), backgroundColor: Colors.green),
          );
          _fetchRecipients(); 
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete recipient.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showAddRecipientDialog(AppLocalizations l10n, String lang) {
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
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(_getLocalText('Add New Care Recipient', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildLabel(l10n.fullName),
                    _buildTextField(
                      controller: nameController,
                      hintText: _getLocalText('egName', lang),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel(l10n.relationship),
                    _buildTranslatedDropdown(
                      value: selectedRelationship,
                      options: relationshipOptions,
                      isMedical: false,
                      l10n: l10n,
                      onChanged: (val) => setState(() => selectedRelationship = val),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel(l10n.age),
                    _buildTextField(
                      controller: ageController,
                      hintText: _getLocalText('egAge', lang),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),

                    _buildLabel(l10n.medicalCondition),
                    _buildTranslatedDropdown(
                      value: selectedMedicalCondition,
                      options: medicalOptions,
                      isMedical: true,
                      l10n: l10n,
                      onChanged: (val) => setState(() => selectedMedicalCondition = val),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('${l10n.specialNeeds} ${_getLocalText('(Optional)', lang)}'),
                    _buildTextField(
                      controller: specialNeedsController,
                      hintText: _getLocalText('notesHint', lang),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

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
                              Navigator.pop(context); 
                              _fetchRecipients(); 
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
                            : Text(
                                _getLocalText('Save', lang), 
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
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

  void _showRecipientDetails(Map<String, dynamic> recipient, AppLocalizations l10n, String lang) {
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  recipient['name']?.toString() ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69), fontSize: 22),
                ),
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
              _buildDetailRow(Icons.family_restroom, l10n.relationship, _getTranslatedRelation(recipient['relationship'] ?? 'Others', l10n)),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.cake, l10n.age, recipient['age']),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.medical_services, l10n.medicalCondition, _getTranslatedMedical(recipient['medical_condition'] ?? 'Others', l10n)),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.note_alt_outlined, _getLocalText('Notes', lang), recipient['special_needs']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              _deleteRecipient(recipient['id'].toString(), l10n, lang); 
            },
            child: Text(_getLocalText('Delete', lang), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); 
              _showEditRecipientPopup(recipient, l10n, lang); 
            },
            icon: const Icon(Icons.edit, size: 18, color: Colors.white),
            label: Text(_getLocalText('Edit', lang), style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B3F69),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditRecipientPopup(Map<String, dynamic> recipient, AppLocalizations l10n, String lang) {
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
                            Navigator.pop(context); 
                            _showRecipientDetails(recipient, l10n, lang); 
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(_getLocalText('Edit Care Recipient Details', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildLabel(l10n.fullName),
                    _buildTextField(
                      controller: nameController,
                      hintText: _getLocalText('egName', lang),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel(l10n.relationship),
                    _buildTranslatedDropdown(
                      value: selectedRelationship,
                      options: relationshipOptions,
                      isMedical: false,
                      l10n: l10n,
                      onChanged: (val) => setState(() => selectedRelationship = val),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel(l10n.age),
                    _buildTextField(
                      controller: ageController,
                      hintText: _getLocalText('egAge', lang),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),

                    _buildLabel(l10n.medicalCondition),
                    _buildTranslatedDropdown(
                      value: selectedMedicalCondition,
                      options: medicalOptions,
                      isMedical: true,
                      l10n: l10n,
                      onChanged: (val) => setState(() => selectedMedicalCondition = val),
                    ),
                    const SizedBox(height: 15),

                    _buildLabel('${l10n.specialNeeds} ${_getLocalText('(Optional)', lang)}'),
                    _buildTextField(
                      controller: specialNeedsController,
                      hintText: _getLocalText('notesHint', lang),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

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
                              Navigator.pop(context); 
                              _fetchRecipients(); 
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
                            : Text(
                                _getLocalText('Save', lang), 
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
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

  // --- VISUAL TRANSLATION HANDLERS ---
  String _getTranslatedMedical(String val, AppLocalizations l10n) {
    if (val == 'High blood pressure') return l10n.highBloodPressure;
    if (val == 'Heart diseases and stroke') return l10n.heartDisease;
    if (val == 'Diabetes') return l10n.diabetes;
    if (val == 'Others') return l10n.others;
    return val;
  }

  String _getTranslatedRelation(String val, AppLocalizations l10n) {
    if (val == 'Parent') return l10n.parent;
    if (val == 'Grandparent') return l10n.grandparent;
    if (val == 'Spouse') return l10n.spouse;
    if (val == 'Others') return l10n.others;
    return val;
  }

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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
      ),
    );
  }

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

  Widget _buildTranslatedDropdown({
    required String? value,
    required List<String> options,
    required bool isMedical,
    required AppLocalizations l10n,
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
        String display = isMedical ? _getTranslatedMedical(opt, l10n) : _getTranslatedRelation(opt, l10n);
        return DropdownMenuItem<String>(
          value: opt,
          child: Text(display, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode; // Used for local translator

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.careRecipients, style: const TextStyle(color: Colors.white)),
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
                      Text(
                        l10n.noRecipientsFound,
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getLocalText('Add new recipient here!', lang),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showAddRecipientDialog(l10n, lang),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(l10n.addNew, style: const TextStyle(color: Colors.white)),
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
                        title: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            recipient['name']?.toString() ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${l10n.relationship}: ${_getTranslatedRelation(recipient['relationship'] ?? 'Others', l10n)}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => _showRecipientDetails(recipient, l10n, lang), 
                      ),
                    );
                  },
                ),
      floatingActionButton: _recipients.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddRecipientDialog(l10n, lang),
              backgroundColor: const Color(0xFF6B3F69),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(l10n.addNew, style: const TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}