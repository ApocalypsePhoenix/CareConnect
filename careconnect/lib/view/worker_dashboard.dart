import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 
import 'find_client_screen.dart';
import '../services/mysql_api_service.dart';
import 'dart:async';
import 'booking_history_screen.dart'; 
import 'settingworker_screen.dart';
import 'rating_review_screen.dart'; 
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED: Localization Import

class WorkerDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const WorkerDashboard({super.key, required this.user});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  late Map<String, dynamic> _currentUser;
  Map<String, dynamic>? _activeService;
  bool _isLoadingService = true;
  bool _isUpdatingStatus = false; 

  Map<String, dynamic>? _latestHistoryItem;
  bool _isLoadingHistory = true;

  Timer? _autoRefreshTimer; 

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _fetchActiveService();
    _fetchLatestHistory(); 
    
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchActiveService(isBackground: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLatestHistory() async {
    final result = await MysqlApiService.getBookingHistory(workerId: _currentUser['id'].toString());
    if (mounted) {
      setState(() {
        if (result['success'] == true && (result['history'] as List).isNotEmpty) {
          _latestHistoryItem = result['history'][0]; 
        } else {
          _latestHistoryItem = null;
        }
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _fetchActiveService({bool isBackground = false}) async {
    if (!isBackground) setState(() => _isLoadingService = true);
    
    final result = await MysqlApiService.getActiveService(workerId: _currentUser['id'].toString());
    
    if (mounted) {
      setState(() {
        if (!isBackground) _isLoadingService = false;
        
        bool hadActiveService = _activeService != null;
        String? oldBookingId = _activeService?['id']?.toString();

        if (result['success'] == true && result['has_service'] == true) {
          _activeService = result['service'];
        } else {
          if (hadActiveService && oldBookingId != null && isBackground && !_isUpdatingStatus) {
            _checkWhyItDisappeared(oldBookingId);
          }
          _activeService = null;
        }
      });
    }
  }

  Future<void> _checkWhyItDisappeared(String bookingId) async {
    final statusResult = await MysqlApiService.checkBookingStatus(bookingId);
    if (mounted && statusResult['success'] == true) {
      final l10n = AppLocalizations.of(context)!; // Grab translations for the popup
      
      if (statusResult['status'] == 'Cancelled') {
        _showStatusPopup(l10n.serviceTerminated, l10n.clientCancelledBooking, Colors.red, Icons.cancel);
      } else if (statusResult['status'] == 'Completed') {
        await _fetchLatestHistory(); 
        if (_latestHistoryItem != null) {
          _showEarningsPopup(_latestHistoryItem!, l10n);
        } else {
          _showStatusPopup(l10n.serviceCompleted, l10n.paymentCredited, Colors.green, Icons.check_circle);
        }
      } else if (statusResult['status'] == 'Pending') {
        _showStatusPopup(l10n.requestDeclined, l10n.clientDeclinedRequest, Colors.orange, Icons.person_off);
      }
      _fetchLatestHistory(); 
    }
  }

  void _showStatusPopup(String title, String message, Color color, IconData icon) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 15),
            Text(title, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text(l10n.ok, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      )
    );
  }

  void _showEarningsPopup(Map<String, dynamic> historyItem, AppLocalizations l10n) {
    double serviceAmount = 0.0;
    String serviceType = historyItem['service_needed'] ?? '';
    String durationStr = historyItem['expected_duration'] ?? '1 hour';
    int hours = int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    if (serviceType == 'Mobility Service') {
      double baseFee = 15.0; 
      double hourlyRate = 10.0; 
      double distanceFee = 0.0;
      if (historyItem['pickup_lat'] != null && historyItem['dropoff_lat'] != null) {
        double pLat = double.parse(historyItem['pickup_lat'].toString());
        double pLng = double.parse(historyItem['pickup_lng'].toString());
        double dLat = double.parse(historyItem['dropoff_lat'].toString());
        double dLng = double.parse(historyItem['dropoff_lng'].toString());
        double distanceInMeters = Geolocator.distanceBetween(pLat, pLng, dLat, dLng);
        distanceFee = (distanceInMeters / 1000) * 1.50; 
      }
      serviceAmount = baseFee + (hours * hourlyRate) + distanceFee;
    } else if (serviceType == 'Physiotherapy/Rehabilitation') {
      serviceAmount = hours * 50.0;
    } else {
      serviceAmount = hours * 30.0;
    }

    double adminFee = serviceAmount * 0.03; 
    double workerEarns = serviceAmount - adminFee;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet, size: 50, color: Colors.green),
              ),
              const SizedBox(height: 15),
              Text(l10n.paymentReceived, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 5),
              Text(l10n.addedToWallet, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              
              const SizedBox(height: 20),
              Text('+ RM ${workerEarns.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black87)),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l10n.clientPaid, style: const TextStyle(color: Colors.black87)), Text('RM ${serviceAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                    const Divider(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l10n.platformFee, style: const TextStyle(color: Colors.redAccent, fontSize: 13)), Text('- RM ${adminFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13))]),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    // --- TRIGGER RATING POPUP ---
                    await showDialog(
                      context: context,
                      barrierDismissible: false, 
                      builder: (context) => RatingReviewScreen(
                        bookingId: historyItem['id'].toString(), 
                        reviewerId: widget.user['id'].toString(),   
                        revieweeId: historyItem['client_id'].toString(), 
                        revieweeName: historyItem['client_name'] ?? 'your Client', 
                        reviewerRole: widget.user['role'],          
                      ),
                    );

                    _fetchActiveService(isBackground: false); 
                    _fetchLatestHistory();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(l10n.awesome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  Future<bool> _verifyLocation(double targetLat, double targetLng, String locationName, AppLocalizations l10n) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError(l10n.enableGpsToVerify);
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError(l10n.locationPermissionsRequired);
        return false;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
    );

    double distanceInMeters = Geolocator.distanceBetween(position.latitude, position.longitude, targetLat, targetLng);

    if (distanceInMeters > 50) {
      _showError(l10n.tooFarAway(distanceInMeters.toInt(), locationName));
      return false;
    }

    return true; 
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4))
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_activeService == null || _isUpdatingStatus) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isUpdatingStatus = true);
    
    if (newStatus == 'Arrived') {
      if (_activeService!['pickup_lat'] != null && _activeService!['pickup_lng'] != null) {
        double pLat = double.parse(_activeService!['pickup_lat'].toString());
        double pLng = double.parse(_activeService!['pickup_lng'].toString());
        
        bool isAtLocation = await _verifyLocation(pLat, pLng, l10n.pickupLocationName, l10n);
        if (!isAtLocation) {
          setState(() => _isUpdatingStatus = false);
          return; 
        }
      }
    } else if (newStatus == 'Pending_Payment' && _activeService!['service_needed'] == 'Mobility Service') {
      if (_activeService!['dropoff_lat'] != null && _activeService!['dropoff_lng'] != null) {
        double dLat = double.parse(_activeService!['dropoff_lat'].toString());
        double dLng = double.parse(_activeService!['dropoff_lng'].toString());
        
        bool isAtLocation = await _verifyLocation(dLat, dLng, l10n.dropoffLocationName, l10n);
        if (!isAtLocation) {
          setState(() => _isUpdatingStatus = false);
          return; 
        }
      }
    }

    final result = await MysqlApiService.updateServiceStatus(_activeService!['id'].toString(), newStatus);
    
    if (mounted) {
      setState(() => _isUpdatingStatus = false);
      
      if (result['success'] == true) {
        _fetchActiveService(isBackground: false); 
      } else {
        _showError(l10n.failedUpdateStatus);
      }
    }
  }

  Future<void> _cancelService() async {
    if (_activeService == null || _isUpdatingStatus) return;
    final l10n = AppLocalizations.of(context)!;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelJob, style: const TextStyle(color: Colors.red)),
        content: Text(l10n.cancelJobConfirmDesc),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.noKeepIt, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.yesCancel, style: const TextStyle(color: Colors.white)),
          )
        ]
      )
    ) ?? false;

    if (confirm) {
      setState(() => _isUpdatingStatus = true);
      
      final result = await MysqlApiService.cancelService(_activeService!['id'].toString(), 'Worker');
      
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
        if (result['success'] == true) {
          _showStatusPopup(l10n.jobCancelled, l10n.jobCancelledSuccess, Colors.red, Icons.cancel);
          _fetchActiveService(isBackground: false); 
          _fetchLatestHistory(); 
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Initialized localization

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120, 
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6B3F69), Color(0xFF8D5F8C)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 20), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: (_currentUser['profile_image'] != null && _currentUser['profile_image'].toString().isNotEmpty)
                                      ? NetworkImage('https://arcadiusengine.xyz/careconnect/${_currentUser['profile_image']}')
                                      : null,
                                  child: (_currentUser['profile_image'] == null || _currentUser['profile_image'].toString().isEmpty)
                                      ? const Icon(Icons.person, color: Colors.white, size: 30) 
                                      : null,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l10n.welcomeBackName(''), style: const TextStyle(color: Colors.white70, fontSize: 16)), // Fallback usage
                                      Text(
                                        _currentUser['name'], 
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: IconButton(
                              icon: const Icon(Icons.notifications_none, color: Colors.white), 
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFindClientCard(l10n),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.activeServices, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF6B3F69)),
                        onPressed: () => _fetchActiveService(isBackground: false), 
                      )
                    ],
                  ),
                  const SizedBox(height: 5),
                  
                  if (_isLoadingService)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
                  else if (_activeService != null)
                    _buildActiveJobCard(l10n)
                  else
                    _buildEmptyActiveServiceCard(l10n),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.bookingHistory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingHistoryScreen(user: _currentUser)))
                                     .then((_) => _fetchLatestHistory()); 
                        }, 
                        child: Text(l10n.viewAll)
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBookingHistoryCard(l10n),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF6B3F69),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        currentIndex: 0,
        type: BottomNavigationBarType.fixed, 
        onTap: (int index) {
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => FindClientScreen(user: _currentUser)))
                     .then((_) => _fetchActiveService(isBackground: false)); 
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => BookingHistoryScreen(user: _currentUser)))
                     .then((_) => _fetchLatestHistory()); 
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => SettingWorkerScreen(user: _currentUser)))
                     .then((updatedUser) {
              if (updatedUser != null) {
                setState(() => _currentUser = Map<String, dynamic>.from(updatedUser));
              }
            });
          }
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), label: l10n.home),
          BottomNavigationBarItem(icon: const Icon(Icons.person_search_outlined), label: l10n.clientsNav),
          BottomNavigationBarItem(icon: const Icon(Icons.history_outlined), label: l10n.bookingHistory.split(' ')[0]), // Rough fallback
          BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), label: l10n.settings),
        ],
      ),
    );
  }

  Widget _buildFindClientCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFDDC3C3).withOpacity(0.3),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFDDC3C3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.readyToWork, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                const SizedBox(height: 5),
                Text(l10n.browseCareRequests, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => FindClientScreen(user: _currentUser)))
                             .then((_) => _fetchActiveService(isBackground: false)); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B3F69),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.findClients, style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.assignment_ind_outlined, size: 60, color: Color(0xFF8D5F8C)),
        ],
      ),
    );
  }

  Widget _buildActiveJobCard(AppLocalizations l10n) {
    String currentStatus = _activeService!['status'] ?? 'Pending_Approval';
    String serviceType = _activeService!['service_needed'] ?? '';
    
    String nextStatus = '';
    String buttonText = '';
    IconData buttonIcon = Icons.check;

    if (currentStatus == 'Pending_Approval') {
      nextStatus = '';
      buttonText = l10n.waitingClientApproval;
      buttonIcon = Icons.hourglass_empty;
    } else if (currentStatus == 'Accepted') {
      nextStatus = 'On_The_Way';
      buttonText = l10n.startJourney;
      buttonIcon = Icons.directions_car;
    } else if (currentStatus == 'On_The_Way') {
      nextStatus = 'Arrived';
      buttonText = l10n.markArrived;
      buttonIcon = Icons.location_on;
    } else if (currentStatus == 'Arrived') {
      nextStatus = 'In_Progress';
      buttonText = serviceType == 'Mobility Service' ? l10n.startTripDropoff : l10n.startService;
      buttonIcon = serviceType == 'Mobility Service' ? Icons.route : Icons.medical_services;
    } else if (currentStatus == 'In_Progress') {
      nextStatus = 'Pending_Payment';
      buttonText = l10n.completeService;
      buttonIcon = Icons.payment;
    } else if (currentStatus == 'Pending_Payment') {
      nextStatus = '';
      buttonText = l10n.waitingClientPay;
      buttonIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(25), 
        border: Border.all(color: Colors.green.shade200, width: 2),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(_activeService!['service_needed'], style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Text(currentStatus.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 15),
          Text(_activeService!['patient_name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          Row(children: [
            const Icon(Icons.phone, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(_activeService!['client_phone'] ?? l10n.noPhoneProvided, style: const TextStyle(fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.pickupLocation(_activeService!['pickup_location'] ?? ''), style: const TextStyle(fontSize: 14))),
          ]),
          if (_activeService!['dropoff_location'] != null && _activeService!['dropoff_location'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.local_hospital, size: 16, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.dropoffLocation(_activeService!['dropoff_location'] ?? ''), style: const TextStyle(fontSize: 14))),
            ]),
          ],
         
          const Divider(height: 30),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isUpdatingStatus || currentStatus == 'Pending_Approval' || currentStatus == 'Pending_Payment') ? null : () => _updateStatus(nextStatus),
              icon: _isUpdatingStatus 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : Icon(buttonIcon, color: Colors.white),
              label: Text(
                _isUpdatingStatus ? l10n.verifying : buttonText, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentStatus == 'In_Progress' 
                  ? Colors.green 
                  : (currentStatus == 'Pending_Approval' || currentStatus == 'Pending_Payment')
                    ? Colors.orange 
                    : const Color(0xFF6B3F69),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: (_isUpdatingStatus || currentStatus == 'Pending_Payment') ? null : _cancelService,
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              label: Text(l10n.cancelJob, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyActiveServiceCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          const Icon(Icons.work_outline, size: 30, color: Color(0xFF8D5F8C)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.noActiveJobsWorker, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(l10n.ongoingServicesWorkerDesc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingHistoryCard(AppLocalizations l10n) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => BookingHistoryScreen(user: _currentUser)))
                 .then((_) => _fetchLatestHistory()); 
      },
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(25), 
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: _isLoadingHistory 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
          : _latestHistoryItem == null 
            ? Row(
                children: [
                  const Icon(Icons.history, size: 30, color: Colors.blueAccent),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.noPastHistory, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(l10n.historyDesc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _latestHistoryItem!['status'] == 'Completed' ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(
                      _latestHistoryItem!['status'] == 'Completed' ? Icons.check_circle : Icons.cancel, 
                      color: _latestHistoryItem!['status'] == 'Completed' ? Colors.green : Colors.red
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.latestJob, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(_latestHistoryItem!['service_needed'] ?? 'Service', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('${_latestHistoryItem!['formatted_date']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
      ),
    );
  }
}