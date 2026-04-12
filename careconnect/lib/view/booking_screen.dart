import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'location_search_screen.dart'; 

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String initialLocation; 

  const BookingScreen({super.key, required this.user, this.initialLocation = ''});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String? _selectedService;
  String? _careTarget; 
  
  bool _isLoadingRecipients = true;
  bool _isSubmitting = false; // Tracks if booking is currently sending to database
  
  Map<String, dynamic>? _selfRecipient;
  List<dynamic> _otherRecipients = [];
  dynamic _selectedOtherRecipient;

  // Controllers for the UI
  late TextEditingController _primaryLocationController; 
  final TextEditingController _dropoffController = TextEditingController(); 
  
  // Hold the actual Coordinates (Geocoding logic!)
  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;

  String? _expectedDuration;
  String? _preferredLanguage;
  String? _preferredGender;
  String? _preferredRace; // NEW

  final List<String> _services = ['Mobility Service', 'Physiotherapy/Rehabilitation', 'Daily Assistance/Nursing Care'];
  final List<String> _durations = ['1 hour', '2 hours', '3 hours', '4 hours', '5 hours+'];
  
  // UPDATED: Added 'Any' to all preferences and cleaned up the lists
  final List<String> _languages = ['Any', 'Malay', 'English', 'Mandarin', 'Tamil'];
  final List<String> _genders = ['Any', 'Male', 'Female']; 
  final List<String> _races = ['Any', 'Malay', 'Chinese', 'Indian']; // NEW

  @override
  void initState() {
    super.initState();
    _primaryLocationController = TextEditingController(text: widget.initialLocation.isNotEmpty ? widget.initialLocation : widget.user['address']);
    _fetchRecipientsData();
  }

  @override
  void dispose() {
    _primaryLocationController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecipientsData() async {
    final result = await MysqlApiService.getRecipients(int.parse(widget.user['id'].toString()));
    if (mounted) {
      setState(() {
        if (result['success']) {
          final allRecipients = result['recipients'] as List;
          try {
            _selfRecipient = allRecipients.firstWhere((r) => r['relationship'].toString().toLowerCase() == 'self');
          } catch (e) {
            _selfRecipient = null;
          }
          _otherRecipients = allRecipients.where((r) => r['relationship'].toString().toLowerCase() != 'self').toList();
          if (_otherRecipients.length == 1) _selectedOtherRecipient = _otherRecipients.first;
        }
        _isLoadingRecipients = false;
      });
    }
  }

  // Opens the LocationSearch Screen
  Future<void> _openLocationSearch(String title, TextEditingController controller, bool isDropoff) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationSearchScreen(title: title)),
    );

    // If the user selected a location on the next screen
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        // 1. Update the UI text box
        controller.text = result['address'];
        
        // 2. Store the actual Coordinates for the backend mapping
        if (isDropoff) {
          _dropoffLat = result['lat'];
          _dropoffLng = result['lng'];
        } else {
          _pickupLat = result['lat'];
          _pickupLng = result['lng'];
        }
      });
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedService == null) return _showError('Please select a service.');
    if (_careTarget == null) return _showError('Please specify who this booking is for.');
    if (_careTarget == 'Others' && _selectedOtherRecipient == null) return _showError('Please select a care recipient.');
    if (_primaryLocationController.text.trim().isEmpty) return _showError('Please select the location.');
    if (_selectedService == 'Mobility Service' && _dropoffController.text.trim().isEmpty) return _showError('Please select the drop-off location.');
    
    // UPDATED: Included _preferredRace in the validation check
    if (_expectedDuration == null || _preferredLanguage == null || _preferredGender == null || _preferredRace == null) return _showError('Please complete all preferences.');

    setState(() {
      _isSubmitting = true; // Show loading spinner
    });

    // Bundle all the data to send to the PHP API
    final bookingData = {
      'client_id': widget.user['id'].toString(),
      'patient_name': _careTarget == 'Self' ? widget.user['name'] : _selectedOtherRecipient?['name'] ?? '',
      'patient_age': _careTarget == 'Self' ? widget.user['age'].toString() : _selectedOtherRecipient?['age'].toString() ?? '',
      'medical_condition': _careTarget == 'Self' ? (_selfRecipient?['medical_condition'] ?? 'Not specified') : _selectedOtherRecipient?['medical_condition'] ?? 'Not specified',
      'special_needs': _careTarget == 'Self' ? (_selfRecipient?['special_needs'] ?? '') : _selectedOtherRecipient?['special_needs'] ?? '',
      'service_needed': _selectedService,
      'pickup_location': _primaryLocationController.text,
      'pickup_lat': _pickupLat,
      'pickup_lng': _pickupLng,
      'dropoff_location': _dropoffController.text,
      'dropoff_lat': _dropoffLat,
      'dropoff_lng': _dropoffLng,
      'expected_duration': _expectedDuration,
      'preferred_language': _preferredLanguage,
      'preferred_gender': _preferredGender,
      'preferred_race': _preferredRace, // NEW
    };

    // Send it to the live database
    final result = await MysqlApiService.submitBooking(bookingData);

    if (mounted) {
      setState(() {
        _isSubmitting = false; // Hide loading spinner
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking Confirmed! System has broadcasted your request to available workers.'), backgroundColor: Colors.green)
        );
        Navigator.pop(context); // Go back to dashboard
      } else {
        _showError(result['message'] ?? 'Failed to submit booking. Please try again.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Book a Service', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6B3F69),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingRecipients 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                  const SizedBox(height: 10),
                  _buildDropdown(
                    value: _selectedService,
                    hint: 'Choose a service...',
                    icon: Icons.medical_services_outlined,
                    options: _services,
                    onChanged: (val) => setState(() => _selectedService = val)
                  ),
                  
                  if (_selectedService != null) ...[
                    const Divider(height: 40, thickness: 1),
                    const Text('Client & Recipient Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                    const SizedBox(height: 10),
                    
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFF8D5F8C), size: 30),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Booked By:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(widget.user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(widget.user['phone'], style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    _buildDropdown(
                      value: _careTarget,
                      hint: 'Who is this booking for?',
                      icon: Icons.family_restroom,
                      options: ['Self', 'Others'],
                      onChanged: (val) {
                        setState(() {
                          _careTarget = val!;
                          if (_careTarget == 'Others' && _otherRecipients.isEmpty) _showError('No recipients added yet.');
                        });
                      }
                    ),
                    const SizedBox(height: 15),

                    if (_careTarget == 'Self') 
                      _buildPatientDetailsCard(_selfRecipient ?? {'medical_condition': 'Not specified', 'special_needs': 'Not specified'})
                    else if (_careTarget == 'Others') ...[
                      if (_otherRecipients.isNotEmpty) ...[
                        if (_otherRecipients.length > 1) ...[
                          _buildRecipientDropdown(),
                          const SizedBox(height: 10),
                        ],
                        if (_selectedOtherRecipient != null) _buildPatientDetailsCard(_selectedOtherRecipient),
                      ] else 
                        const Padding(padding: EdgeInsets.all(8.0), child: Text('No recipients found. Please add one.', style: TextStyle(color: Colors.red)))
                    ],

                    const Divider(height: 40, thickness: 1),
                    // LOCATION BUTTONS
                    const Text('Location Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                    const SizedBox(height: 10),

                    if (_selectedService == 'Mobility Service') ...[
                      _buildClickableLocationField(
                        label: 'Current Location', 
                        controller: _primaryLocationController,
                        onTap: () => _openLocationSearch('Set Pickup Location', _primaryLocationController, false),
                      ),
                      const SizedBox(height: 15),
                      _buildClickableLocationField(
                        label: 'Medical Facility (Drop-off)', 
                        controller: _dropoffController,
                        icon: Icons.local_hospital,
                        onTap: () => _openLocationSearch('Set Destination', _dropoffController, true),
                      ),
                    ] else ...[
                      _buildClickableLocationField(
                        label: 'Location for Worker to Come', 
                        controller: _primaryLocationController,
                        onTap: () => _openLocationSearch('Set Location', _primaryLocationController, false),
                      ),
                    ],

                    const Divider(height: 40, thickness: 1),
                    const Text('Booking Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                    const SizedBox(height: 10),

                    _buildDropdown(value: _expectedDuration, hint: 'Expected Duration', icon: Icons.timer_outlined, options: _durations, onChanged: (val) => setState(() => _expectedDuration = val)),
                    const SizedBox(height: 15),
                    _buildDropdown(value: _preferredGender, hint: 'Preferred Gender', icon: Icons.wc, options: _genders, onChanged: (val) => setState(() => _preferredGender = val)),
                    const SizedBox(height: 15),
                    // NEW: Preferred Race Dropdown
                    _buildDropdown(value: _preferredRace, hint: 'Preferred Race', icon: Icons.groups, options: _races, onChanged: (val) => setState(() => _preferredRace = val)),
                    const SizedBox(height: 15),
                    // UPDATED: Preferred Language
                    _buildDropdown(value: _preferredLanguage, hint: 'Preferred Language', icon: Icons.language, options: _languages, onChanged: (val) => setState(() => _preferredLanguage = val)),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitBooking, // Disable if submitting
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B3F69),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isSubmitting 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Confirm Booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildPatientDetailsCard(dynamic patientData) {
    String patientName = patientData['name'] ?? widget.user['name'];
    String patientAge = patientData['age']?.toString() ?? widget.user['age']?.toString() ?? '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Patient Medical Information', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          Text('Patient: $patientName ($patientAge yrs)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text('Condition: ${patientData['medical_condition'] ?? 'Not specified'}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text('Special Needs: ${patientData['special_needs'] ?? 'Not specified'}', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRecipientDropdown() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: _selectedOtherRecipient,
          hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 15), child: Text('Select Care Recipient')),
          isExpanded: true,
          items: _otherRecipients.map((recipient) {
            return DropdownMenuItem<dynamic>(
              value: recipient,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Text('${recipient['name']} (${recipient['relationship']})')),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedOtherRecipient = val),
        ),
      ),
    );
  }

  Widget _buildDropdown({required String? value, required String hint, required IconData icon, required List<String> options, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5)),
      ),
      hint: Text(hint, style: TextStyle(color: Colors.grey.shade500)),
      isExpanded: true,
      items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildClickableLocationField({required String label, required TextEditingController controller, required VoidCallback onTap, IconData icon = Icons.location_on}) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer( // Prevents keyboard from popping up here
        child: TextField(
          controller: controller,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C)),
            suffixIcon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey), // Arrow indicates it opens a new page
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ),
    );
  }
}