import 'package:flutter/material.dart';
import 'find_client_screen.dart'; 

class WorkerDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const WorkerDashboard({super.key, required this.user});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  late Map<String, dynamic> _currentUser;

  @override
  void initState() {
    super.initState();
    // Initialize the local user state with the data passed from the login screen
    _currentUser = Map<String, dynamic>.from(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Header with Welcome Message
          SliverAppBar(
            expandedHeight: 10, // Reduced height for a sleeker look
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
                    mainAxisAlignment: MainAxisAlignment.center, // Added to center vertically
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                // Profile Picture Avatar
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
                                // Greeting Text
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
                          // Notification Button
                          CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: IconButton(
                              icon: const Icon(Icons.notifications_none, color: Colors.white), 
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
                  // 1. Find Client / Worker CTA
                  _buildFindClientCard(),
                  const SizedBox(height: 30),

                  // 2. Active Services (Moved up)
                  const Text('Active Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                  const SizedBox(height: 15),
                  _buildActiveServiceCard(),
                  const SizedBox(height: 30),

                  // 3. Booking History (Moved down, replacing Recipients)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Booking History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          // View all history
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
            // Navigate to Client Requests Screen
            Navigator.push(context, MaterialPageRoute(builder: (context) => FindClientScreen(user: _currentUser)));
          } else if (index == 2) {
            // Navigate to Booking History
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PlaceholderHistoryScreen()));
          } else if (index == 3) {
            // Navigate to Worker Settings
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

  // --- UI Components Tailored for Workers ---

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
                    // Navigate to Find Clients Screen
                    Navigator.push(context, MaterialPageRoute(builder: (context) => FindClientScreen(user: _currentUser)));
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

  Widget _buildActiveServiceCard() {
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

// =========================================================================
// TEMPORARY PLACEHOLDER SCREENS 
// (These prevent your app from crashing when you tap the Bottom NavBar)
// =========================================================================

class PlaceholderClientScreen extends StatelessWidget {
  const PlaceholderClientScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Clients'), backgroundColor: const Color(0xFF6B3F69), foregroundColor: Colors.white),
      body: const Center(child: Text('Client Requests Screen Coming Soon!')),
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