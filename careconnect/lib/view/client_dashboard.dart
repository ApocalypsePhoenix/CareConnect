import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'recipient_screen.dart';
import 'settingclient_screen.dart'; 
import 'booking_screen.dart'; // Added import for the booking screen

class ClientDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const ClientDashboard({super.key, required this.user});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  List<dynamic> _recipients = [];
  bool _isLoading = true;
  late Map<String, dynamic> _currentUser; // Added to hold and update user state locally

  @override
  void initState() {
    super.initState();
    // Initialize the local user state with the data passed from the login screen
    _currentUser = Map<String, dynamic>.from(widget.user);
    _fetchRecipients();
  }

  Future<void> _fetchRecipients() async {
    final result = await MysqlApiService.getRecipients(int.parse(_currentUser['id'].toString()));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Header with Welcome Message
          SliverAppBar(
            expandedHeight: 120, // Reduced height for a sleeker look matching Worker Dashboard
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
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 20), // Adjusted top padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center, // Centered vertically
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                // Profile Picture Avatar - Uses _currentUser now
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: (_currentUser['profile_image'] != null && _currentUser['profile_image'].toString().isNotEmpty)
                                      ? NetworkImage('https://arcadiusengine.xyz/careconnect/${_currentUser['profile_image']}')
                                      : null,
                                  child: (_currentUser['profile_image'] == null || _currentUser['profile_image'].toString().isEmpty)
                                      ? const Icon(Icons.person, color: Colors.white, size: 30) // Fallback icon
                                      : null,
                                ),
                                const SizedBox(width: 15),
                                // Greeting Text - Uses _currentUser now
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Hello,', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                      Text(
                                        _currentUser['name'], 
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis, // Prevents overflow if name is long
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Notification Button
                          CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: IconButton(
                              icon: const Icon(Icons.notifications_none, color: Colors.white), // notification icon
                              onPressed: () {
                                // Add your notification navigation or popup logic here later
                              },
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
                  // Book Now CTA
                  _buildBookNowCard(),
                  const SizedBox(height: 30),

                  // Care Recipients Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Care Recipients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          // Navigate to the new Recipient Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipientScreen(user: _currentUser),
                            ),
                          ).then((_) {
                            // Refresh the dashboard list just in case a user was added
                            _fetchRecipients();
                          });
                        }, 
                        child: const Text('Add New')
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
                    : _recipients.isEmpty 
                      ? _buildEmptyRecipients()
                      : _buildRecipientsList(),

                  const SizedBox(height: 30),

                  // Recent Activity / Booking Status
                  const Text('Active Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                  const SizedBox(height: 15),
                  _buildBookingStatusCard(),
                  const SizedBox(height: 30), // Added spacing

                  // NEW: Booking History Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Booking History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          // Navigate to the placeholder history screen for now
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PlaceholderClientHistoryScreen(),
                            ),
                          );
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
        type: BottomNavigationBarType.fixed, // Recommended when having more than 3 items
        onTap: (int index) {
          // Index 1 corresponds to the 'Bookings' tab
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingScreen(user: _currentUser),
              ),
            );
          }
          // Index 2 corresponds to the 'Recipients' tab
          else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecipientScreen(user: _currentUser),
              ),
            ).then((_) {
              // Refresh the dashboard when coming back
              _fetchRecipients();
            });
          }
          // Index 3 corresponds to the 'Settings' tab
          else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingClientScreen(user: _currentUser),
              ),
            ).then((updatedUser) {
              // If the user updated their profile in Settings, update the dashboard immediately
              if (updatedUser != null) {
                setState(() {
                  _currentUser = Map<String, dynamic>.from(updatedUser);
                });
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
                    // Navigate to Booking Screen when the button is pressed
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingScreen(user: _currentUser),
                      ),
                    );
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

  Widget _buildBookingStatusCard() {
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

  // --- NEW: History Card Widget ---
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

// TEMPORARY PLACEHOLDER SCREENS 
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