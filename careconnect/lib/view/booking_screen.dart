import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 
import '../services/mysql_api_service.dart';
import 'location_search_screen.dart'; 
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 

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
  bool _isSubmitting = false; 
  
  Map<String, dynamic>? _selfRecipient;
  List<dynamic> _otherRecipients = [];
  dynamic _selectedOtherRecipient;

  late TextEditingController _primaryLocationController; 
  final TextEditingController _dropoffController = TextEditingController(); 
  
  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;

  String? _expectedDuration;
  String? _preferredLanguage;
  String? _preferredGender;
  String? _preferredRace; 

  final List<String> _services = ['Mobility Service', 'Physiotherapy/Rehabilitation', 'Daily Assistance/Nursing Care'];
  final List<String> _durations = ['1 hour', '2 hours', '3 hours', '4 hours', '5 hours+'];
  final List<String> _languages = ['Any', 'Malay', 'English', 'Mandarin', 'Tamil'];
  final List<String> _genders = ['Any', 'Male', 'Female']; 
  final List<String> _races = ['Any', 'Malay', 'Chinese', 'Indian']; 

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

  Future<void> _openLocationSearch(String title, TextEditingController controller, bool isDropoff) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => LocationSearchScreen(title: title)));
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        controller.text = result['address'];
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

  double _calculateEstimatedPrice() {
    if (_selectedService == null || _expectedDuration == null) return 0.0;
    
    int hours = int.tryParse(_expectedDuration!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    
    if (_selectedService == 'Mobility Service') {
      double baseFee = 15.0;
      double hourlyRate = 10.0;
      double distanceFee = 0.0;
      
      if (_pickupLat != null && _dropoffLat != null) {
        double distMeters = Geolocator.distanceBetween(_pickupLat!, _pickupLng!, _dropoffLat!, _dropoffLng!);
        distanceFee = (distMeters / 1000) * 1.50; // RM 1.50 per KM
      }
      return baseFee + (hours * hourlyRate) + distanceFee;
    } else if (_selectedService == 'Physiotherapy/Rehabilitation') {
      return hours * 50.0;
    } else {
      return hours * 30.0;
    }
  }

  Future<void> _submitBooking(AppLocalizations l10n) async {
    if (_selectedService == null) return _showError(l10n.pleaseSelectService);
    if (_careTarget == null) return _showError(l10n.pleaseSpecifyCareTarget);
    if (_careTarget == 'Others' && _selectedOtherRecipient == null) return _showError(l10n.pleaseSelectRecipient);
    if (_primaryLocationController.text.trim().isEmpty) return _showError(l10n.pleaseSelectLocation);
    if (_selectedService == 'Mobility Service' && _dropoffController.text.trim().isEmpty) return _showError(l10n.pleaseSelectDropoff);
    if (_expectedDuration == null || _preferredLanguage == null || _preferredGender == null || _preferredRace == null) return _showError(l10n.pleaseCompletePreferences);

    setState(() => _isSubmitting = true); 

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
      'preferred_race': _preferredRace, 
    };

    final result = await MysqlApiService.submitBooking(bookingData);

    if (mounted) {
      setState(() => _isSubmitting = false); 
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.bookingConfirmedMsg), backgroundColor: Colors.green));
        Navigator.pop(context); 
      } else {
        _showError(result['message'] ?? l10n.failedSubmitBooking);
      }
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));

  String _getServiceTranslation(String key, AppLocalizations l10n) {
    if (key == 'Mobility Service') return l10n.mobilityService;
    if (key == 'Physiotherapy/Rehabilitation') return l10n.physiotherapy;
    if (key == 'Daily Assistance/Nursing Care') return l10n.nursingCare;
    return key;
  }

  String _getGenericTranslation(String key, AppLocalizations l10n) {
    if (key == 'Any') return l10n.anyOption; 
    if (key == 'Male') return l10n.male;
    if (key == 'Female') return l10n.female;
    if (key == 'Malay') return l10n.malay;
    if (key == 'Chinese') return l10n.chinese;
    if (key == 'Indian') return l10n.indian;
    if (key == 'English') return l10n.english;
    if (key == 'Mandarin') return l10n.mandarin;
    if (key == 'Tamil') return l10n.tamil;
    return key;
  }

  String _getDurationTranslation(String key, AppLocalizations l10n) {
    if (key == '1 hour') return l10n.hour1;
    if (key == '2 hours') return l10n.hours2;
    if (key == '3 hours') return l10n.hours3;
    if (key == '4 hours') return l10n.hours4;
    if (key == '5 hours+') return l10n.hours5;
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    double estimatedPrice = _calculateEstimatedPrice(); 

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.bookServiceTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  Text(l10n.selectService, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                  const SizedBox(height: 10),
                  _buildTranslatedDropdown(
                    value: _selectedService,
                    hint: l10n.chooseServiceHint,
                    icon: Icons.medical_services_outlined,
                    options: _services,
                    isService: true,
                    onChanged: (val) => setState(() => _selectedService = val),
                    l10n: l10n
                  ),
                  
                  if (_selectedService != null) ...[
                    const Divider(height: 40, thickness: 1),
                    Text(l10n.clientRecipientDetails, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
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
                              Text(l10n.bookedBy, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                      hint: l10n.whoIsBookingFor,
                      icon: Icons.family_restroom,
                      options: ['Self', 'Others'],
                      visualOptions: [l10n.self, l10n.othersOption], 
                      onChanged: (val) {
                        setState(() {
                          _careTarget = val!;
                          if (_careTarget == 'Others' && _otherRecipients.isEmpty) _showError(l10n.noRecipientsFound);
                        });
                      }
                    ),
                    const SizedBox(height: 15),

                    if (_careTarget == 'Self') 
                      _buildPatientDetailsCard(_selfRecipient ?? {'medical_condition': 'Not specified', 'special_needs': 'Not specified'}, l10n)
                    else if (_careTarget == 'Others') ...[
                      if (_otherRecipients.isNotEmpty) ...[
                        if (_otherRecipients.length > 1) ...[
                          _buildRecipientDropdown(l10n),
                          const SizedBox(height: 10),
                        ],
                        if (_selectedOtherRecipient != null) _buildPatientDetailsCard(_selectedOtherRecipient, l10n),
                      ] else 
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(l10n.noRecipientsFound, style: const TextStyle(color: Colors.red)))
                    ],

                    const Divider(height: 40, thickness: 1),
                    Text(l10n.locationDetails, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                    const SizedBox(height: 10),

                    if (_selectedService == 'Mobility Service') ...[
                      _buildClickableLocationField(
                        label: l10n.currentLocation, 
                        controller: _primaryLocationController,
                        onTap: () => _openLocationSearch(l10n.setPickupLocation, _primaryLocationController, false),
                      ),
                      const SizedBox(height: 15),
                      _buildClickableLocationField(
                        label: l10n.medicalFacilityDropoff, 
                        controller: _dropoffController,
                        icon: Icons.local_hospital,
                        onTap: () => _openLocationSearch(l10n.setDestination, _dropoffController, true),
                      ),
                    ] else ...[
                      _buildClickableLocationField(
                        label: l10n.locationForWorker, 
                        controller: _primaryLocationController,
                        onTap: () => _openLocationSearch(l10n.setLocation, _primaryLocationController, false),
                      ),
                    ],

                    const Divider(height: 40, thickness: 1),
                    Text(l10n.bookingPreferences, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      value: _expectedDuration, 
                      hint: l10n.expectedDuration, 
                      icon: Icons.timer_outlined, 
                      options: _durations, 
                      visualOptions: _durations.map((d) => _getDurationTranslation(d, l10n)).toList(), 
                      onChanged: (val) => setState(() => _expectedDuration = val)
                    ),
                    const SizedBox(height: 15),
                    _buildTranslatedDropdown(value: _preferredGender, hint: l10n.preferredGender, icon: Icons.wc, options: _genders, isService: false, onChanged: (val) => setState(() => _preferredGender = val), l10n: l10n),
                    const SizedBox(height: 15),
                    _buildTranslatedDropdown(value: _preferredRace, hint: l10n.preferredRace, icon: Icons.groups, options: _races, isService: false, onChanged: (val) => setState(() => _preferredRace = val), l10n: l10n),
                    const SizedBox(height: 15),
                    _buildTranslatedDropdown(value: _preferredLanguage, hint: l10n.preferredLanguage, icon: Icons.language, options: _languages, isService: false, onChanged: (val) => setState(() => _preferredLanguage = val), l10n: l10n),

                    const SizedBox(height: 30),
                    
                    if (estimatedPrice > 0)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.green.shade200, width: 2)
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.estimatedPrice, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                Text(l10n.excludesPlatformFee, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                              ],
                            ),
                            Text('RM ${estimatedPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _submitBooking(l10n), 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B3F69),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isSubmitting 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(l10n.confirmBooking, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPatientDetailsCard(dynamic patientData, AppLocalizations l10n) {
    String patientName = patientData['name'] ?? widget.user['name'];
    String patientAge = patientData['age']?.toString() ?? widget.user['age']?.toString() ?? '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.patientMedicalInfo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          Text(l10n.patientLabel(patientName, patientAge), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text('${l10n.conditionLabel('')} ${patientData['medical_condition'] ?? 'Not specified'}', style: const TextStyle(fontSize: 13)), 
          const SizedBox(height: 4),
          Text('${l10n.specialNeedsLabel('')} ${patientData['special_needs'] ?? 'Not specified'}', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRecipientDropdown(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: _selectedOtherRecipient,
          hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Text(l10n.selectCareRecipient)),
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

  Widget _buildDropdown({required String? value, required String hint, required IconData icon, required List<String> options, required List<String> visualOptions, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5)),
      ),
      hint: Text(hint, style: TextStyle(color: Colors.grey.shade500)),
      isExpanded: true,
      items: List.generate(options.length, (index) {
        return DropdownMenuItem(value: options[index], child: Text(visualOptions[index]));
      }),
      onChanged: onChanged,
    );
  }

  Widget _buildTranslatedDropdown({required String? value, required String hint, required IconData icon, required List<String> options, required bool isService, required Function(String?) onChanged, required AppLocalizations l10n}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF6B3F69), width: 1.5)),
      ),
      hint: Text(hint, style: TextStyle(color: Colors.grey.shade500)),
      isExpanded: true,
      items: options.map((opt) {
        String translatedText = isService ? _getServiceTranslation(opt, l10n) : _getGenericTranslation(opt, l10n);
        return DropdownMenuItem(value: opt, child: Text(translatedText));
      }).toList(),
      onChanged: onChanged,
    );
  }

  // EDITED: Changed maxLines from 2 to 1 for precise One-Row layout
  Widget _buildClickableLocationField({required String label, required TextEditingController controller, required VoidCallback onTap, IconData icon = Icons.location_on}) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          maxLines: 1, // Only 1 row now
          minLines: 1,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF8D5F8C)),
            suffixIcon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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