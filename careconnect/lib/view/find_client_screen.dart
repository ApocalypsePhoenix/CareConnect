import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mysql_api_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED LOCALIZATION

class FindClientScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const FindClientScreen({super.key, required this.user});

  @override
  State<FindClientScreen> createState() => _FindClientScreenState();
}

class _FindClientScreenState extends State<FindClientScreen> {
  bool _isOnline = false; 
  bool _isLoading = false;
  bool _isBusy = false; // Tracks if the worker currently has an active job
  Timer? _pollingTimer; // Timer to fetch live data
  
  double? _currentLat; 
  double? _currentLng; 

  List<Map<String, dynamic>> _incomingRequests = [];
  
  // Memory to prevent declined requests from popping back up
  static final Set<int> _ignoredRequestIds = {};

  @override
  void initState() {
    super.initState();
    _checkIfBusy(); 
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); 
    super.dispose();
  }

  // --- Ask for GPS Permission & Get Location ---
  Future<bool> _determinePosition(AppLocalizations l10n) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.enableGpsToVerify), backgroundColor: Colors.redAccent));
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.locationPermissionsRequired), backgroundColor: Colors.redAccent));
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.locationPermissionsRequired), backgroundColor: Colors.redAccent));
      return false;
    } 

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _currentLat = position.latitude;
    _currentLng = position.longitude;
    return true;
  }

  Future<void> _checkIfBusy() async {
    setState(() => _isLoading = true);
    final result = await MysqlApiService.getAvailableRequests(widget.user['id'].toString(), 0.0, 0.0);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true && result['is_busy'] == true) {
          _isBusy = true;
          _isOnline = false; // Force offline
        }
      });
    }
  }

  Future<void> _toggleVisibility(bool value, AppLocalizations l10n) async {
    if (_isBusy) return;

    setState(() => _isLoading = true);

    if (value == true) {
      bool hasLocation = await _determinePosition(l10n);
      if (!hasLocation) {
        setState(() => _isLoading = false);
        return; 
      }
    }

    setState(() => _isOnline = value);

    await MysqlApiService.updateWorkerVisibility(widget.user['id'].toString(), _isOnline);
    
    setState(() => _isLoading = false);

    if (_isOnline) {
      _fetchLiveRequests();
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _fetchLiveRequests();
      });
    } else {
      _pollingTimer?.cancel();
      setState(() => _incomingRequests.clear());
    }
  }

  Future<void> _fetchLiveRequests() async {
    if (!_isOnline || _currentLat == null || _currentLng == null) return;

    final result = await MysqlApiService.getAvailableRequests(widget.user['id'].toString(), _currentLat!, _currentLng!);
    if (mounted && result['success'] == true) {
      setState(() {
        if (result['is_busy'] == true) {
          _isBusy = true;
          _isOnline = false;
          _incomingRequests.clear();
          _pollingTimer?.cancel();
        } else {
          final allFetchedRequests = List<Map<String, dynamic>>.from(result['requests'] ?? []);
          _incomingRequests = allFetchedRequests.where((req) {
            return !_ignoredRequestIds.contains(int.parse(req['id'].toString()));
          }).toList();
        }
      });
    }
  }

  // Helper method to safely translate Map Keys for UI without changing DB values
  String _getServiceTranslation(String key, AppLocalizations l10n) {
    if (key == 'Mobility Service') return l10n.mobilityService;
    if (key == 'Physiotherapy/Rehabilitation') return l10n.physiotherapy;
    if (key == 'Daily Assistance/Nursing Care') return l10n.nursingCare;
    return key;
  }

  // Helper method to translate database hours
  String _getDurationTranslation(String key, AppLocalizations l10n) {
    if (key.contains('1')) return l10n.hour1;
    if (key.contains('2')) return l10n.hours2;
    if (key.contains('3')) return l10n.hours3;
    if (key.contains('4')) return l10n.hours4;
    if (key.contains('5')) return l10n.hours5;
    return key;
  }

  // --- UPDATED: Beautiful Detailed Request Bottom Sheet (Self vs Recipient Logic & Payment) ---
  void _showRequestDetails(Map<String, dynamic> request, AppLocalizations l10n) {
    final clientName = request['client_name']?.toString() ?? 'Client';
    final clientPhone = request['client_phone']?.toString() ?? l10n.noPhoneProvided;
    final clientImage = request['client_image'];
    
    final patientName = request['patient_name']?.toString() ?? 'Patient';
    final patientAge = request['patient_age']?.toString() ?? '?';
    final condition = request['medical_condition']?.toString() ?? 'Not specified';
    final needs = request['special_needs']?.toString() ?? 'None';
    
    final service = request['service_needed']?.toString() ?? 'N/A';
    final translatedService = _getServiceTranslation(service, l10n);
    final location = request['location']?.toString() ?? 'N/A';
    final date = request['date']?.toString() ?? 'N/A';

    // Format Duration safely with translation
    final durationText = _getDurationTranslation(request['duration']?.toString() ?? '', l10n);

    // Format Payment
    final paymentText = request['payment'] != null ? 'RM ${request['payment']}' : 'RM 0.00';

    // LOGIC: Is the client booking for themselves?
    bool isSelf = clientName.trim().toLowerCase() == patientName.trim().toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 20),
            
            // --- 1. CLIENT INFO HEADER (The person who booked) ---
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (clientImage != null && clientImage.toString().isNotEmpty)
                      ? NetworkImage('https://arcadiusengine.xyz/careconnect/$clientImage')
                      : null,
                  child: (clientImage == null || clientImage.toString().isEmpty)
                      ? const Icon(Icons.person, size: 35, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.bookedBy, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text(clientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 5),
                          Text(clientPhone, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- 2. PATIENT INFO CARD (Self vs Recipient Logic) ---
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFDDC3C3).withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFDDC3C3).withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.medical_information, color: Color(0xFF8D5F8C), size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.patientDetails, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      const Spacer(),
                      // Dynamic Badge (Self vs Recipient)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelf ? Colors.green.shade100 : Colors.blue.shade100, 
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Text(
                          isSelf ? l10n.selfBadge : l10n.recipientBadge, 
                          style: TextStyle(fontSize: 10, color: isSelf ? Colors.green : Colors.blue, fontWeight: FontWeight.bold)
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  // Only show patient name if it's a different person (Recipient)
                  if (!isSelf) ...[
                    Text(l10n.patientNameLabel(patientName), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                  ],
                  
                  Text(l10n.ageYearsOld(patientAge), style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(l10n.conditionLabel(condition), style: const TextStyle(fontSize: 13)),
                  if (needs.isNotEmpty && needs != 'Not specified') ...[
                    const SizedBox(height: 4),
                    Text(l10n.specialNeedsLabel(needs), style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // --- 3. JOB DETAILS ---
            _buildDetailRow(Icons.medical_services_outlined, l10n.serviceNeededLabel, translatedService),
            _buildDetailRow(Icons.timer_outlined, l10n.expectedDurationLabel, durationText),
            _buildDetailRow(Icons.location_on_outlined, l10n.locationLabel, location),
            _buildDetailRow(Icons.calendar_today_outlined, l10n.dateTimeLabel, date),
            
            // ADDED PAYMENT HIGHLIGHT
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.expectedPaymentLabel, style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(paymentText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAction(int.parse(request['id'].toString()), 'Rejected', l10n);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.decline, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAction(int.parse(request['id'].toString()), 'Accepted', l10n);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.acceptRequest, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF8D5F8C), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _handleAction(int requestId, String action, AppLocalizations l10n) async {
    setState(() {
      _incomingRequests.removeWhere((req) => int.parse(req['id'].toString()) == requestId);
      if (action == 'Rejected') {
        _ignoredRequestIds.add(requestId);
      }
    });
    
    if (action == 'Accepted') {
      final result = await MysqlApiService.respondToRequest(requestId.toString(), widget.user['id'].toString(), action);
      
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _isBusy = true;
            _isOnline = false;
            _pollingTimer?.cancel();
            _incomingRequests.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.jobAcceptedSuccess), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to accept.'), backgroundColor: Colors.redAccent));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.requestDeclinedSuccess), backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // TRANSLATION ENGINE LOADED

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.findClientsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6B3F69),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (!_isBusy)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? l10n.youAreOnline : l10n.youAreOffline,
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: _isOnline ? Colors.green : Colors.grey.shade700
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isOnline ? l10n.scanningForJobs : l10n.goOnlineToReceive,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch(
                    value: _isOnline,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade400,
                    onChanged: (val) => _toggleVisibility(val, l10n),
                  ),
                ],
              ),
            ),          
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
              : _isBusy 
                ? _buildBusyState(l10n) 
                : !_isOnline
                  ? _buildOfflineState(l10n)
                  : _incomingRequests.isEmpty
                    ? _buildEmptyRequestsState(l10n)
                    : _buildRequestList(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBusyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_history, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text(l10n.activeJobWarning, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            Text(
              l10n.activeJobWarningDesc, 
              textAlign: TextAlign.center, 
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B3F69),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.returnToDashboard, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_off_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(l10n.currentlyOffline, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          Text(l10n.toggleToReceiveRequests, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyRequestsState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_outlined, size: 80, color: const Color(0xFF8D5F8C).withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(l10n.scanningRequestsTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          Text(l10n.keepScreenOpen, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRequestList(AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _incomingRequests.length,
      itemBuilder: (context, index) {
        final request = _incomingRequests[index];
        final clientImage = request['client_image'];
        final clientName = request['client_name']?.toString() ?? 'Client';
        final patientName = request['patient_name']?.toString() ?? 'Patient';
        
        final bool isSelf = clientName.trim().toLowerCase() == patientName.trim().toLowerCase();

        // Format Duration
        final durationText = _getDurationTranslation(request['duration']?.toString() ?? '', l10n);

        // Format Payment
        final paymentText = request['payment'] != null ? 'RM ${request['payment']}' : 'RM 0.00';
        
        // Translate the service pill safely
        final rawService = request['service_needed']?.toString() ?? '';
        final displayService = rawService.isNotEmpty ? _getServiceTranslation(rawService, l10n) : '';

        return Card(
          elevation: 4,
          shadowColor: Colors.black12,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            onTap: () => _showRequestDetails(request, l10n), 
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // TEXT SHRINKING APPLIED HERE WITH FITTED BOX
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(displayService, style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(request['distance'] != null ? l10n.kmAway(double.parse(request['distance'].toString()).toStringAsFixed(1)) : l10n.newRequest, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 15),
                    
                  // Client Picture + Distinct Patient Badge Layout
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: (clientImage != null && clientImage.toString().isNotEmpty)
                            ? NetworkImage('https://arcadiusengine.xyz/careconnect/$clientImage')
                            : null,
                        child: (clientImage == null || clientImage.toString().isEmpty)
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            // Self vs Recipient clear UI in the list
                            if (isSelf)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                                child: Text(l10n.bookingForSelf, style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              )
                            else
                              Text(l10n.bookingForRecipient(patientName), style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(request['location']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13))
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text(request['date']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),

                  const SizedBox(height: 15),
                  // Green Payment and Duration Banner
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(durationText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.payments_outlined, size: 18, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(paymentText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 25),
                  Center(
                    child: Text(l10n.tapToViewDetails, style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold, fontSize: 13)),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}