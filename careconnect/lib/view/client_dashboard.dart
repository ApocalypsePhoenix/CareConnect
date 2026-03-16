import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'login_screen.dart'; // Added import for the login screen navigation

class ClientDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const ClientDashboard({super.key, required this.user});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  List<dynamic> _recipients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecipients();
  }

  Future<void> _fetchRecipients() async {
    final result = await MysqlApiService.getRecipients(int.parse(widget.user['id'].toString()));
    if (mounted) {
      setState(() {
        if (result['success']) {
          _recipients = result['recipients'];
        }
        _isLoading = false;
      });
    }
  }

  // Method to display the logout confirmation popup
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            // "No" Button - Closes the popup
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
              },
              child: const Text('No', style: TextStyle(color: Colors.grey)),
            ),
            // "Yes" Button - Logs out and navigates to Login Screen
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog first
                
                // Navigate to Login Screen and remove all previous routes 
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Header with Welcome Message
          SliverAppBar(
            expandedHeight: 200,
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
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hello,', style: TextStyle(color: Colors.white70, fontSize: 16)),
                              Text(widget.user['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white), // Changed to logout icon
                              onPressed: () => _showLogoutDialog(context), // Triggers the logout popup
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
                      TextButton(onPressed: () {}, child: const Text('Add New')),
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
                  onPressed: () {}, // Navigate to Booking Screen
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
          SizedBox(height: 10),
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
}