import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'recipient_screen.dart';
import 'settingclient_screen.dart'; 
import 'booking_screen.dart';
import 'dart:async';

class ClientDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const ClientDashboard({super.key, required this.user});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  List<dynamic> _recipients = [];
  bool _isLoadingRecipients = true;
  
  Map<String, dynamic>? _activeService;
  bool _isLoadingService = true;
  
  late Map<String, dynamic> _currentUser;
  
  // NEW: Timer for auto-refreshing the live tracker
  Timer? _autoRefreshTimer; 
  bool _isCancelling = false; // NEW: tracks cancellation loading state

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _fetchRecipients();
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

  Future<void> _fetchRecipients() async {
    final result = await MysqlApiService.getRecipients(int.parse(_currentUser['id'].toString()));
    if (mounted) {
      setState(() {
        if (result['success']) {
          _recipients = (result['recipients'] as List)
              .where((recipient) => recipient['relationship'].toString().toLowerCase() != 'self')
              .toList();
        }
        _isLoadingRecipients = false;
      });
    }
  }

  // UPDATED: Now accepts an optional 'isBackground' parameter to hide the loading spinner
  Future<void> _fetchActiveService({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoadingService = true);
    }
    
    final result = await MysqlApiService.getActiveService(clientId: _currentUser['id'].toString());
    
    if (mounted) {
      setState(() {
        if (!isBackground) {
          _isLoadingService = false;
        }
        
        bool hadActiveService = _activeService != null;

        if (result['success'] == true && result['has_service'] == true) {
          _activeService = result['service'];
        } else {
          // UPDATED: Ensure we don't show the alert if the client is the one who cancelled it
          if (hadActiveService && isBackground && !_isCancelling) {
             _showCompletionOrCancellationAlert();
          }
          _activeService = null;
        }
      });
    }
  }

  // --- NEW: Alert Dialog for Service Updates ---
  void _showCompletionOrCancellationAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Service Update', style: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
        content: const Text('Your active service has been completed by the worker, or it was cancelled. Please check your Booking History for details!'),
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

  // --- NEW: Cancel Booking Logic ---
  Future<void> _cancelService() async {
    if (_activeService == null || _isCancelling) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to cancel this booking? The assigned worker will be released.'),
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
      setState(() => _isCancelling = true);
      
      final result = await MysqlApiService.cancelService(_activeService!['id'].toString(), 'Client');
      
      if (mounted) {
        setState(() => _isCancelling = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled successfully.'), backgroundColor: Colors.green));
          _fetchActiveService(isBackground: false); // Manually refresh UI
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to cancel booking.'), backgroundColor: Colors.red));
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
            expandedHeight: 160,
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
                                      const Text('Hello,', style: TextStyle(color: Colors.white70, fontSize: 16)),
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
                  _buildBookNowCard(),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Care Recipients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => RecipientScreen(user: _currentUser)))
                                   .then((_) => _fetchRecipients());
                        }, 
                        child: const Text('Add New')
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _isLoadingRecipients 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
                    : _recipients.isEmpty 
                      ? _buildEmptyRecipients()
                      : _buildRecipientsList(),

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
                    _buildEmptyBookingStatusCard(),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Booking History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PlaceholderClientHistoryScreen()));
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => BookingScreen(user: _currentUser)))
                     .then((_) => _fetchActiveService(isBackground: false));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => RecipientScreen(user: _currentUser)))
                     .then((_) => _fetchRecipients());
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => SettingClientScreen(user: _currentUser)))
                     .then((updatedUser) {
              if (updatedUser != null) {
                setState(() => _currentUser = Map<String, dynamic>.from(updatedUser));
              }
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Recipients'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildBookNowCard() {
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
                const Text('Need professional care?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                const SizedBox(height: 5),
                const Text('Book a trained worker to assist your loved ones today.', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => BookingScreen(user: _currentUser)))
                             .then((_) => _fetchActiveService(isBackground: false));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B3F69),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Book a Worker', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.volunteer_activism, size: 60, color: Color(0xFF8D5F8C)),
        ],
      ),
    );
  }

  Widget _buildEmptyRecipients() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: const Column(
        children: [
          Icon(Icons.people_outline, size: 40, color: Colors.grey),
          const SizedBox(height: 10),
          Text('No recipients added yet', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecipientsList() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recipients.length,
        itemBuilder: (context, index) {
          final recipient = _recipients[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFDDC3C3).withOpacity(0.5),
                  child: Text(recipient['name'][0], style: const TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(recipient['name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(recipient['relationship'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- PIZZA HUT STYLE TRACKER ---
  Widget _buildActiveJobCard() {
    String currentStatus = _activeService!['status'] ?? 'Accepted';
    String serviceType = _activeService!['service_needed'] ?? '';
    
    int statusIndex = 0;
    if (currentStatus == 'On_The_Way') statusIndex = 1;
    if (currentStatus == 'Arrived') statusIndex = 2;
    if (currentStatus == 'In_Progress') statusIndex = 3;

    List<String> stepTitles = [];
    if (serviceType == 'Mobility Service') {
      stepTitles = ['Assigned', 'Heading\nto Pickup', 'Arrived\nat Pickup', 'Heading\nto Drop-off'];
    } else {
      stepTitles = ['Assigned', 'On The\nWay', 'Arrived\nat Client', 'Service\nOngoing'];
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
                child: const Text('Worker Assigned', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Text(currentStatus.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 15),
          
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (_activeService!['worker_image'] != null && _activeService!['worker_image'].toString().isNotEmpty)
                    ? NetworkImage('https://arcadiusengine.xyz/careconnect/${_activeService!['worker_image']}')
                    : null,
                child: (_activeService!['worker_image'] == null || _activeService!['worker_image'].toString().isEmpty)
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activeService!['worker_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Service: ${_activeService!['service_needed']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              )
            ],
          ),
          
          const Divider(height: 20),
          
          Row(children: [
            const Icon(Icons.phone, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(_activeService!['worker_phone'] ?? 'No phone provided', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ]),

          const SizedBox(height: 20),
          
          // Progress Tracker UI
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Delivery Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrackerStep(stepTitles[0], Icons.assignment_ind, statusIndex == 0, statusIndex > 0),
                    _buildTrackerLine(statusIndex > 0),
                    _buildTrackerStep(stepTitles[1], Icons.directions_car, statusIndex == 1, statusIndex > 1),
                    _buildTrackerLine(statusIndex > 1),
                    _buildTrackerStep(stepTitles[2], Icons.location_on, statusIndex == 2, statusIndex > 2),
                    _buildTrackerLine(statusIndex > 2),
                    _buildTrackerStep(stepTitles[3], serviceType == 'Mobility Service' ? Icons.route : Icons.medical_services, statusIndex == 3, statusIndex > 3),
                  ],
                ),
              ],
            ),
          ),

          // NEW: Cancel Button added to Client Tracker Card
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _isCancelling ? null : _cancelService,
              icon: _isCancelling 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                : const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Booking', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // Helper Widget: Individual Tracker Step
  Widget _buildTrackerStep(String title, IconData icon, bool isActive, bool isPassed) {
    Color color = isPassed || isActive ? const Color(0xFF6B3F69) : Colors.grey.shade400;
    return Expanded(
      flex: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.15) : (isPassed ? color : Colors.white),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isActive ? 2 : 1),
            ),
            child: Icon(icon, color: isPassed ? Colors.white : color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            title, 
            style: TextStyle(fontSize: 10, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.normal), 
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper Widget: Connecting Line
  Widget _buildTrackerLine(bool isPassed) {
    return Expanded(
      flex: 1,
      child: Container(
        margin: const EdgeInsets.only(top: 18),
        height: 3,
        color: isPassed ? const Color(0xFF6B3F69) : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildEmptyBookingStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
      child: const Row(
        children: [
          Icon(Icons.history_outlined, size: 30, color: Color(0xFF8D5F8C)),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Active Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Ongoing care services will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                Text('Your completed care requests and past bookings will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderClientHistoryScreen extends StatelessWidget {
  const PlaceholderClientHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking History'), backgroundColor: const Color(0xFF6B3F69), foregroundColor: Colors.white),
      body: const Center(child: Text('Client History Screen Coming Soon!')),
    );
  }
}