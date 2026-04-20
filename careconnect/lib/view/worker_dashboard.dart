import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 
import 'find_client_screen.dart';
import '../services/mysql_api_service.dart';
import 'dart:async';
import 'booking_history_screen.dart'; 
import 'settingworker_screen.dart';

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

  // NEW: State for the latest history item
  Map<String, dynamic>? _latestHistoryItem;
  bool _isLoadingHistory = true;

  //Timer for auto-refreshing the active service
  Timer? _autoRefreshTimer; 

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _fetchActiveService();
    _fetchLatestHistory(); // Fetch history when dashboard opens
    
    // Start the background timer to fetch active services every 5 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchActiveService(isBackground: true);
    });
  }

  //To not forget to stop the timer when the screen is closed!
  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Fetch only the latest history item for the dashboard card
  Future<void> _fetchLatestHistory() async {
    final result = await MysqlApiService.getBookingHistory(workerId: _currentUser['id'].toString());
    if (mounted) {
      setState(() {
        if (result['success'] == true && (result['history'] as List).isNotEmpty) {
          _latestHistoryItem = result['history'][0]; // Grab the most recent one
        } else {
          _latestHistoryItem = null;
        }
        _isLoadingHistory = false;
      });
    }
  }

  //Detects if the client cancelled the job in the background
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
          // Job disappeared! Did the client cancel it while we weren't looking?
          if (hadActiveService && oldBookingId != null && isBackground && !_isUpdatingStatus) {
            _checkWhyItDisappeared(oldBookingId);
          }
          _activeService = null;
        }
      });
    }
  }

  //Ask the database what happened to that booking that disappeared from the worker's screen
  Future<void> _checkWhyItDisappeared(String bookingId) async {
    final statusResult = await MysqlApiService.checkBookingStatus(bookingId);
    if (mounted && statusResult['success'] == true) {
      if (statusResult['status'] == 'Cancelled') {
        _showStatusPopup('Service Terminated', 'The client has cancelled this booking. The service is now terminated.', Colors.red, Icons.cancel);
      } else if (statusResult['status'] == 'Completed') {
        _showStatusPopup('Service Completed', 'This service has been marked as successfully completed.', Colors.green, Icons.check_circle);
      } else if (statusResult['status'] == 'Pending') {
        _showStatusPopup('Request Declined', 'The client declined your request to take this job. You are back in the available pool.', Colors.orange, Icons.person_off);
      }
      _fetchLatestHistory(); // Update history card since a job just finished/cancelled!
    }
  }

  //Popup Dialog
  void _showStatusPopup(String title, String message, Color color, IconData icon) {
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
                child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      )
    );
  }

  //GPS Geofencing Logic to Prevent Cheating
  Future<bool> _verifyLocation(double targetLat, double targetLng, String locationName) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Please enable GPS to verify your location.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permissions are required to update status.');
        return false;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude, 
      position.longitude, 
      targetLat, 
      targetLng
    );

    if (distanceInMeters > 50) {
      _showError('You are ${distanceInMeters.toInt()} meters away from the $locationName. You must be closer (within 50m) to update your status!');
      return false;
    }

    return true; 
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4))
    );
  }

  //Dynamic Status Updater with GPS checks to prevent cheating
  Future<void> _updateStatus(String newStatus) async {
    if (_activeService == null || _isUpdatingStatus) return;

    setState(() => _isUpdatingStatus = true);
    
    if (newStatus == 'Arrived') {
      if (_activeService!['pickup_lat'] != null && _activeService!['pickup_lng'] != null) {
        double pLat = double.parse(_activeService!['pickup_lat'].toString());
        double pLng = double.parse(_activeService!['pickup_lng'].toString());
        
        bool isAtLocation = await _verifyLocation(pLat, pLng, 'pickup location');
        if (!isAtLocation) {
          setState(() => _isUpdatingStatus = false);
          return; 
        }
      }
    } else if (newStatus == 'Completed' && _activeService!['service_needed'] == 'Mobility Service') {
      if (_activeService!['dropoff_lat'] != null && _activeService!['dropoff_lng'] != null) {
        double dLat = double.parse(_activeService!['dropoff_lat'].toString());
        double dLng = double.parse(_activeService!['dropoff_lng'].toString());
        
        bool isAtLocation = await _verifyLocation(dLat, dLng, 'drop-off location');
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
        if (newStatus == 'Completed') {
          _showStatusPopup('Great Job!', 'You have successfully completed this service.', Colors.green, Icons.check_circle);
          _fetchLatestHistory(); // Update history immediately
        }
        _fetchActiveService(isBackground: false); 
      } else {
        _showError('Failed to update status. Please try again.');
      }
    }
  }

  //Cancel Job Logic
  Future<void> _cancelService() async {
    if (_activeService == null || _isUpdatingStatus) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to cancel this job? The service will be permanently terminated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, Keep it', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
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
          _showStatusPopup('Job Cancelled', 'You have cancelled the job. The service is now terminated.', Colors.red, Icons.cancel);
          _fetchActiveService(isBackground: false); 
          _fetchLatestHistory(); // Update history immediately
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                                      const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 16)),
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
                  _buildFindClientCard(),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
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
                    _buildActiveJobCard()
                  else
                    _buildEmptyActiveServiceCard(),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Booking History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingHistoryScreen(user: _currentUser)))
                                   .then((_) => _fetchLatestHistory()); // Refresh when coming back
                        }, 
                        child: const Text('View All')
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBookingHistoryCard(),
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
            // 2. CHANGE INDEX 3 TO OPEN THE NEW SCREEN
            Navigator.push(context, MaterialPageRoute(builder: (context) => SettingWorkerScreen(user: _currentUser)))
                     .then((updatedUser) {
              if (updatedUser != null) {
                setState(() => _currentUser = Map<String, dynamic>.from(updatedUser));
              }
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_search_outlined), label: 'Clients'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildFindClientCard() {
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
                const Text('Ready to work?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                const SizedBox(height: 5),
                const Text('Browse available care requests and find clients near you.', style: TextStyle(fontSize: 13, color: Colors.black54)),
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
                  child: const Text('Find Clients', style: TextStyle(color: Colors.white)),
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

  Widget _buildActiveJobCard() {
    String currentStatus = _activeService!['status'] ?? 'Pending_Approval';
    String serviceType = _activeService!['service_needed'] ?? '';
    
    String nextStatus = '';
    String buttonText = '';
    IconData buttonIcon = Icons.check;

    if (currentStatus == 'Pending_Approval') {
      nextStatus = '';
      buttonText = 'Waiting for Client Approval...';
      buttonIcon = Icons.hourglass_empty;
    } else if (currentStatus == 'Accepted') {
      nextStatus = 'On_The_Way';
      buttonText = 'Start Journey (On The Way)';
      buttonIcon = Icons.directions_car;
    } else if (currentStatus == 'On_The_Way') {
      nextStatus = 'Arrived';
      buttonText = 'Mark as Arrived (GPS Check)';
      buttonIcon = Icons.location_on;
    } else if (currentStatus == 'Arrived') {
      nextStatus = 'In_Progress';
      buttonText = serviceType == 'Mobility Service' ? 'Start Trip to Drop-off' : 'Start Service';
      buttonIcon = serviceType == 'Mobility Service' ? Icons.route : Icons.medical_services;
    } else if (currentStatus == 'In_Progress') {
      nextStatus = 'Completed';
      buttonText = 'Complete Service';
      buttonIcon = Icons.check_circle;
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
            Text(_activeService!['client_phone'] ?? 'No phone provided', style: const TextStyle(fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text('Pickup: ${_activeService!['pickup_location']}', style: const TextStyle(fontSize: 14))),
          ]),
          if (_activeService!['dropoff_location'] != null && _activeService!['dropoff_location'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.local_hospital, size: 16, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text('Dropoff: ${_activeService!['dropoff_location']}', style: const TextStyle(fontSize: 14))),
            ]),
          ],
          
          const Divider(height: 30),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isUpdatingStatus || currentStatus == 'Pending_Approval') ? null : () => _updateStatus(nextStatus),
              icon: _isUpdatingStatus 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : Icon(buttonIcon, color: Colors.white),
              label: Text(
                _isUpdatingStatus ? 'Verifying...' : buttonText, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentStatus == 'In_Progress' 
                  ? Colors.green 
                  : currentStatus == 'Pending_Approval' 
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
              onPressed: _isUpdatingStatus ? null : _cancelService,
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              label: const Text('Cancel Job', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyActiveServiceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
      child: const Row(
        children: [
          Icon(Icons.work_outline, size: 30, color: Color(0xFF8D5F8C)),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Active Jobs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Ongoing care services you provide will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingHistoryCard() {
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
                        const Text('No Past History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Text('Tap "View All" or the History tab to see your completed and cancelled jobs.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                        const Text('Latest Job', style: TextStyle(color: Colors.grey, fontSize: 12)),
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