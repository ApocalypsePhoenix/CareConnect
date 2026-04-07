import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';

class BookingHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const BookingHistoryScreen({super.key, required this.user});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    // 1. Check the user's role dynamically
    final isClient = widget.user['role'] == 'Client';
    
    // 2. Fetch history using the correct ID based on their role
    final result = await MysqlApiService.getBookingHistory(
      clientId: isClient ? widget.user['id'].toString() : null,
      workerId: !isClient ? widget.user['id'].toString() : null,
    );
    
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _history = result['history'];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check role to adjust the UI text
    final isClient = widget.user['role'] == 'Client';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Booking History', style: TextStyle(color: Colors.white)), 
        backgroundColor: const Color(0xFF6B3F69), 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
        : _history.isEmpty
          ? const Center(child: Text('No past bookings found.', style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                bool isCompleted = item['status'] == 'Completed';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: isCompleted ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        isCompleted ? Icons.check_circle : Icons.cancel, 
                        color: isCompleted ? Colors.green : Colors.red
                      ),
                    ),
                    title: Text(item['service_needed'] ?? 'Service', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        
                        // 3. Display opposite party's name dynamically!
                        if (isClient)
                          Text('Worker: ${item['worker_name'] ?? 'None Assigned'}')
                        else
                          Text('Client: ${item['client_name'] ?? 'Unknown'}'),
                        
                        Text('Patient: ${item['patient_name']}'),
                        const SizedBox(height: 5),
                        Text(item['formatted_date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: Text(
                      item['status'], 
                      style: TextStyle(
                        color: isCompleted ? Colors.green : Colors.red, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ),
                );
              }
            ),
    );
  }
}