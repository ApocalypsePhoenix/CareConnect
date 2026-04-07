import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'recipient_screen.dart';
import 'settingclient_screen.dart'; 
import 'booking_screen.dart';
import 'dart:async';
import 'booking_history_screen.dart';

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
  
  // Timer for auto-refreshing the live tracker
  Timer? _autoRefreshTimer; 
  bool _isCancelling = false;
  bool _hasPromptedApproval = false; // Prevents spamming the approval popup

  // NEW: State for the latest history item
  Map<String, dynamic>? _latestHistoryItem;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _fetchRecipients();
    _fetchActiveService();
    _fetchLatestHistory(); // Fetch history when dashboard opens
    
    // Start the background timer to fetch active services every 5 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchActiveService(isBackground: true);
    });
  }

  // Don't forget to stop the timer when the screen is closed!
  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Fetch only the latest history item for the dashboard card
  Future<void> _fetchLatestHistory() async {
    final result = await MysqlApiService.getBookingHistory(clientId: _currentUser['id'].toString());
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

  // Accepts an optional 'isBackground' parameter to hide the loading spinner
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
        String? oldBookingId = _activeService?['id']?.toString();

        if (result['success'] == true && result['has_service'] == true) {
          _activeService = result['service'];
          
          // Trigger approval popup if status is Pending_Approval
          if (_activeService!['status'] == 'Pending_Approval' && !_hasPromptedApproval) {
            _hasPromptedApproval = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showWorkerApprovalDialog();
            });
          } else if (_activeService!['status'] != 'Pending_Approval') {
            _hasPromptedApproval = false; // Reset if status moves forward
          }

        } else {
          // It disappeared! Let's find out why (only if we didn't cancel it ourselves)
          if (hadActiveService && oldBookingId != null && isBackground && !_isCancelling) {
             _checkWhyItDisappeared(oldBookingId);
          }
          _activeService = null;
          _hasPromptedApproval = false;
        }
      });
    }
  }

  // --- Ask the database what happened ---
  Future<void> _checkWhyItDisappeared(String bookingId) async {
    final statusResult = await MysqlApiService.checkBookingStatus(bookingId);
    if (mounted && statusResult['success'] == true) {
      if (statusResult['status'] == 'Completed') {
        _showStatusPopup('Service Completed!', 'The worker has successfully completed your care service.', Colors.green, Icons.check_circle);
      } else if (statusResult['status'] == 'Cancelled') {
        _showStatusPopup('Service Terminated', 'The assigned worker has cancelled the booking. The service is now terminated.', Colors.red, Icons.cancel);
      }
      _fetchLatestHistory(); // Refresh history card since a job just finished/cancelled!
    }
  }

  // --- Beautiful Custom Popup Dialog ---
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

  // --- Worker Approval Dialog ---
  void _showWorkerApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Forces client to make a choice
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Worker Found!', style: TextStyle(color: Color(0xFF6B3F69), fontWeight: FontWeight.bold)),
        content: Text('${_activeService!['worker_name']} has accepted your care request. Do you want to approve this worker?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _declineWorker();
            }, 
            child: const Text('Decline', style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approveWorker();
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          )
        ]
      )
    );
  }

  Future<void> _approveWorker() async {
    setState(() => _isLoadingService = true);
    final result = await MysqlApiService.updateServiceStatus(_activeService!['id'].toString(), 'Accepted');
    if (result['success'] == true) {
      _showStatusPopup('Worker Approved', 'The worker will now head to your location.', Colors.green, Icons.check_circle);
      _fetchActiveService(isBackground: false);
    }
  }

  Future<void> _declineWorker() async {
    setState(() => _isLoadingService = true);
    final result = await MysqlApiService.declineWorker(_activeService!['id'].toString(), _activeService!['worker_id'].toString());
    if (result['success'] == true) {
      _showStatusPopup('Worker Declined', 'The worker has been declined. Your request is back in the pool for others to accept.', Colors.orange, Icons.refresh);
      _fetchActiveService(isBackground: false);
    }
  }

  // --- Cancel Booking Logic ---
  Future<void> _cancelService() async {
    if (_activeService == null || _isCancelling) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to cancel this booking? The service will be permanently terminated.'),
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
          _showStatusPopup('Booking Cancelled', 'You have successfully cancelled the booking. The service is now terminated.', Colors.red, Icons.cancel);
          _fetchActiveService(isBackground: false); 
          _fetchLatestHistory(); // Refresh history card
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

  // --- PIZZA HUT STYLE TRACKER & APPROVAL BUTTONS ---
  Widget _buildActiveJobCard() {
    String currentStatus = _activeService!['status'] ?? 'Pending_Approval';
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
          
          // If pending approval, show Approve/Decline buttons instead of Tracker
          if (currentStatus == 'Pending_Approval')
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 10),
                  const Text('Please review the worker and confirm if you would like them to proceed with the service.', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _declineWorker,
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                          child: const Text('Decline', style: TextStyle(color: Colors.redAccent)),
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _approveWorker,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Approve', style: TextStyle(color: Colors.white)),
                        )
                      ),
                    ]
                  )
                ]
              )
            )
          else
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

  // UPDATED: Now dynamically shows the latest history item just like the Worker Dashboard
  Widget _buildBookingHistoryCard() {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => BookingHistoryScreen(user: _currentUser)))
                 .then((_) => _fetchLatestHistory());
      },
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
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
                        const Text('Tap "View All" above or this card to see your completed and cancelled bookings.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                        const Text('Latest Booking', style: TextStyle(color: Colors.grey, fontSize: 12)),
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