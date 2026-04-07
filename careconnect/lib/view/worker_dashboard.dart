import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 
import 'find_client_screen.dart';
import '../services/mysql_api_service.dart';
import 'dart:async'; // NEW: Imported for Timer

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

  // NEW: Timer for auto-refreshing the active service
  Timer? _autoRefreshTimer; 

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _fetchActiveService();
    
    // NEW: Start the background timer to fetch active services every 5 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchActiveService(isBackground: true);
    });
  }

  // NEW: Don't forget to stop the timer when the screen is closed!
  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // UPDATED: Detects if the client cancelled the job in the background
  Future<void> _fetchActiveService({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoadingService = true);
    }
    
    final result = await MysqlApiService.getActiveService(workerId: _currentUser['id'].toString());
    
    if (mounted) {
      setState(() {
        if (!isBackground) {
          _isLoadingService = false;
        }
        
        bool hadActiveService = _activeService != null;

        if (result['success'] == true && result['has_service'] == true) {
          _activeService = result['service'];
        } else {
          // NEW: If the job disappears and the worker wasn't the one updating it, the client cancelled!
          if (hadActiveService && isBackground && !_isUpdatingStatus) {
            _showClientCancelledAlert();
          }
          _activeService = null;
        }
      });
    }
  }

  // --- NEW: Alert Dialog for Client Cancellation ---
  void _showClientCancelledAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Job Cancelled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('The client has cancelled this booking. You have been placed back into the available pool for new requests.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69)),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          )
        ]
      )
    );
  }

  // --- GPS Geofencing Logic to Prevent Cheating ---
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

    // Get the worker's current live location
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    // Calculate distance in meters between Worker and Client
    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude, 
      position.longitude, 
      targetLat, 
      targetLng
    );

    // If they are more than 50 meters away, block them!
    if (distanceInMeters > 50) {
      _showError('You are ${distanceInMeters.toInt()} meters away from the $locationName. You must be closer (within 50m) to update your status!');
      return false;
    }

    return true; // They are close enough!
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4))
    );
  }

  // --- Dynamic Status Updater ---
  Future<void> _updateStatus(String newStatus) async {
    if (_activeService == null || _isUpdatingStatus) return;

    setState(() => _isUpdatingStatus = true);
    
    // --- ANTI-CHEAT: GPS CHECKS ---
    if (newStatus == 'Arrived') {
      // Make sure we have the coordinates from the database
      if (_activeService!['pickup_lat'] != null && _activeService!['pickup_lng'] != null) {
        double pLat = double.parse(_activeService!['pickup_lat'].toString());
        double pLng = double.parse(_activeService!['pickup_lng'].toString());
        
        bool isAtLocation = await _verifyLocation(pLat, pLng, 'pickup location');
        if (!isAtLocation) {
          setState(() => _isUpdatingStatus = false);
          return; // Abort status update if they are cheating!
        }
      }
    } else if (newStatus == 'Completed' && _activeService!['service_needed'] == 'Mobility Service') {
      // For mobility, check if they actually reached the drop-off location!
      if (_activeService!['dropoff_lat'] != null && _activeService!['dropoff_lng'] != null) {
        double dLat = double.parse(_activeService!['dropoff_lat'].toString());
        double dLng = double.parse(_activeService!['dropoff_lng'].toString());
        
        bool isAtLocation = await _verifyLocation(dLat, dLng, 'drop-off location');
        if (!isAtLocation) {
          setState(() => _isUpdatingStatus = false);
          return; // Abort status update!
        }
      }
    }

    // If GPS checks pass, update the database
    final result = await MysqlApiService.updateServiceStatus(_activeService!['id'].toString(), newStatus);
    
    if (mounted) {
      setState(() => _isUpdatingStatus = false);
      
      if (result['success'] == true) {
        if (newStatus == 'Completed') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Great job! Service marked as completed.'), backgroundColor: Colors.green)
          );
        }
        _fetchActiveService(isBackground: false); // Refresh the card to get the new status
      } else {
        _showError('Failed to update status. Please try again.');
      }
    }
  }

  // --- NEW: Cancel Job Logic ---
  Future<void> _cancelService() async {
    if (_activeService == null || _isUpdatingStatus) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to cancel this job? It will be returned to the client\'s pending requests.'),
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job cancelled successfully.'), backgroundColor: Colors.green));
          _fetchActiveService(isBackground: false); // Manually refresh UI
        } else {
          _showError(result['message'] ?? 'Failed to cancel job.');
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
                        onPressed: () => _fetchActiveService(isBackground: false), // Allows manual refresh with loading spinner
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
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PlaceholderHistoryScreen()));
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PlaceholderHistoryScreen()));
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingWorkerScreen()));
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
    String currentStatus = _activeService!['status'] ?? 'Accepted';
    String serviceType = _activeService!['service_needed'] ?? '';
    
    String nextStatus = '';
    String buttonText = '';
    IconData buttonIcon = Icons.check;

    if (currentStatus == 'Accepted') {
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
              onPressed: _isUpdatingStatus ? null : () => _updateStatus(nextStatus),
              icon: _isUpdatingStatus 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : Icon(buttonIcon, color: Colors.white),
              label: Text(
                _isUpdatingStatus ? 'Verifying...' : buttonText, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentStatus == 'In_Progress' ? Colors.green : const Color(0xFF6B3F69),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          // NEW: Cancel Job Button
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, size: 30, color: Colors.green),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Past History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Your completed jobs and past clients will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderHistoryScreen extends StatelessWidget {
  const PlaceholderHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking History'), backgroundColor: const Color(0xFF6B3F69), foregroundColor: Colors.white),
      body: const Center(child: Text('Worker History Screen Coming Soon!')),
    );
  }
}

class SettingWorkerScreen extends StatelessWidget {
  const SettingWorkerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Settings'), backgroundColor: const Color(0xFF6B3F69), foregroundColor: Colors.white),
      body: const Center(child: Text('Worker Settings Screen Coming Soon!')),
    );
  }
}