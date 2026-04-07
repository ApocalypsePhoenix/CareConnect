import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mysql_api_service.dart';

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
  
  double? _currentLat; // Store worker's latitude
  double? _currentLng; // Store worker's longitude

  List<Map<String, dynamic>> _incomingRequests = [];
  
  // FIXED: Added 'static' so the memory survives even if the worker goes back to the Dashboard!
  static final Set<int> _ignoredRequestIds = {};

  @override
  void initState() {
    super.initState();
    _checkIfBusy(); // Check if they have an active job the moment they open the screen
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // Important: Stop the timer when they leave the screen
    super.dispose();
  }

  // --- Ask for GPS Permission & Get Location ---
  Future<bool> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable GPS location services.'), backgroundColor: Colors.redAccent));
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.'), backgroundColor: Colors.redAccent));
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.'), backgroundColor: Colors.redAccent));
      return false;
    } 

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _currentLat = position.latitude;
    _currentLng = position.longitude;
    return true;
  }

  // --- Check if worker has an active job before letting them go online ---
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

  // Toggle visibility status
  Future<void> _toggleVisibility(bool value) async {
    if (_isBusy) return; // Prevent toggling if they are busy

    setState(() {
      _isLoading = true;
    });

    // If trying to go online, fetch GPS location first!
    if (value == true) {
      bool hasLocation = await _determinePosition();
      if (!hasLocation) {
        setState(() => _isLoading = false);
        return; // Abort going online if no GPS
      }
    }

    setState(() {
      _isOnline = value;
    });

    // Tell the database the worker is online
    await MysqlApiService.updateWorkerVisibility(widget.user['id'].toString(), _isOnline);
    
    setState(() => _isLoading = false);

    if (_isOnline) {
      // 1. Fetch immediately
      _fetchLiveRequests();
      // 2. Start a timer to check for new bookings every 10 seconds
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _fetchLiveRequests();
      });
    } else {
      // If offline, stop the timer and clear the screen
      _pollingTimer?.cancel();
      setState(() {
        _incomingRequests.clear();
      });
    }
  }

  Future<void> _fetchLiveRequests() async {
    if (!_isOnline || _currentLat == null || _currentLng == null) return;

    // Pass the worker's current coordinates to the API
    final result = await MysqlApiService.getAvailableRequests(widget.user['id'].toString(), _currentLat!, _currentLng!);
    if (mounted && result['success'] == true) {
      setState(() {
        // If the backend says they are busy (they accepted a job on another device, etc)
        if (result['is_busy'] == true) {
          _isBusy = true;
          _isOnline = false;
          _incomingRequests.clear();
          _pollingTimer?.cancel();
        } else {
          // Filter out any jobs that this worker has previously declined
          final allFetchedRequests = List<Map<String, dynamic>>.from(result['requests'] ?? []);
          _incomingRequests = allFetchedRequests.where((req) {
            return !_ignoredRequestIds.contains(int.parse(req['id'].toString()));
          }).toList();
        }
      });
    }
  }

  // Bottom sheet details
  void _showRequestDetails(Map<String, dynamic> request) {
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
            Text('Request from ${request['client_name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 15),
            
            _buildDetailRow(Icons.medical_services_outlined, 'Service', request['service_needed']?.toString() ?? 'N/A'),
            _buildDetailRow(Icons.location_on_outlined, 'Location', request['location']?.toString() ?? 'N/A'),
            _buildDetailRow(Icons.calendar_today_outlined, 'Date & Time', request['date']?.toString() ?? 'N/A'),
            _buildDetailRow(Icons.info_outline, 'Special Needs', request['details']?.toString() ?? 'None'),
            
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAction(int.parse(request['id'].toString()), 'Rejected');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Decline', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAction(int.parse(request['id'].toString()), 'Accepted');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Accept Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Future<void> _handleAction(int requestId, String action) async {
    // 1. Remove it from the screen instantly for a snappy UI
    setState(() {
      _incomingRequests.removeWhere((req) => int.parse(req['id'].toString()) == requestId);
      
      // Memorize the rejected ID so it won't come back on next refresh
      if (action == 'Rejected') {
        _ignoredRequestIds.add(requestId);
      }
    });
    
    // 2. If they accept, tell the database!
    if (action == 'Accepted') {
      final result = await MysqlApiService.respondToRequest(
        requestId.toString(), 
        widget.user['id'].toString(), 
        action
      );
      
      if (mounted) {
        if (result['success'] == true) {
          // THEY ACCEPTED! Lock the screen immediately.
          setState(() {
            _isBusy = true;
            _isOnline = false;
            _pollingTimer?.cancel();
            _incomingRequests.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job Accepted! Please check your Active Services.'), backgroundColor: Colors.green)
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to accept.'), backgroundColor: Colors.redAccent)
          );
        }
      }
    } else {
      // If rejected locally, just show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request declined. It has been removed from your list.'), backgroundColor: Colors.orange)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Find Clients', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6B3F69),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Visibility Toggle Banner (Hidden if busy)
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
                          _isOnline ? 'You are Online' : 'You are Offline',
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: _isOnline ? Colors.green : Colors.grey.shade700
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isOnline ? 'Scanning database for incoming jobs...' : 'Go online to receive care requests.',
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
                    onChanged: _toggleVisibility,
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 20),

          // Request List / States
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
              : _isBusy 
                ? _buildBusyState() // <--- Shows if they have an active job
                : !_isOnline
                  ? _buildOfflineState()
                  : _incomingRequests.isEmpty
                    ? _buildEmptyRequestsState()
                    : _buildRequestList(),
          ),
        ],
      ),
    );
  }

  // --- Block the worker if they have an ongoing service ---
  Widget _buildBusyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_history, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text('You have an Active Job', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            const Text(
              'You cannot go online or accept new requests until your current service is completed.', 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context), // Sends them back to dashboard
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B3F69),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Return to Dashboard', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_off_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text('Currently Offline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          const Text('Toggle the switch above to start\nreceiving job requests from clients.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyRequestsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_outlined, size: 80, color: const Color(0xFF8D5F8C).withOpacity(0.5)),
          const SizedBox(height: 20),
          const Text('Scanning for requests...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
          const SizedBox(height: 10),
          const Text('Keep this screen open. Incoming\nrequests will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRequestList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _incomingRequests.length,
      itemBuilder: (context, index) {
        final request = _incomingRequests[index];
        return Card(
          elevation: 4,
          shadowColor: Colors.black12,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            onTap: () => _showRequestDetails(request), 
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                        child: Text(request['service_needed']?.toString() ?? '', style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Text(request['distance'] != null ? '${double.parse(request['distance'].toString()).toStringAsFixed(1)} km away' : 'New Request', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(request['client_name']?.toString() ?? 'Client', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
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
                  const Divider(height: 30),
                  const Center(
                    child: Text('Tap to view details & Accept', style: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold, fontSize: 13)),
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