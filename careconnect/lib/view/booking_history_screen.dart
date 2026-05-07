import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED LOCALIZATION

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

  // --- VISUAL TRANSLATION HELPERS ---
  String _getServiceTranslation(String key, AppLocalizations l10n) {
    if (key == 'Mobility Service') return l10n.mobilityService;
    if (key == 'Physiotherapy/Rehabilitation') return l10n.physiotherapy;
    if (key == 'Daily Assistance/Nursing Care') return l10n.nursingCare;
    return key.isNotEmpty ? key : 'Service';
  }

  String _getStatusTranslation(String status, AppLocalizations l10n) {
    switch (status) {
      case 'Pending_Approval': return l10n.statusPending;
      case 'Accepted': return l10n.statusAccepted;
      case 'On_The_Way': return l10n.statusOnTheWay;
      case 'Arrived': return l10n.statusArrived;
      case 'In_Progress': return l10n.statusInProgress;
      case 'Pending_Payment': return l10n.statusPendingPayment;
      case 'Completed': return l10n.statusCompleted;
      case 'Cancelled': return l10n.statusCancelled;
      default: return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check role to adjust the UI text
    final isClient = widget.user['role'] == 'Client';
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.bookingHistory, style: const TextStyle(color: Colors.white)), 
        backgroundColor: const Color(0xFF6B3F69), 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
        : _history.isEmpty
          ? Center(child: Text(l10n.noPastBookingsFound, style: const TextStyle(color: Colors.grey, fontSize: 16)))
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
                    title: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _getServiceTranslation(item['service_needed'] ?? '', l10n), 
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        
                        // 3. Display opposite party's name dynamically!
                        if (isClient)
                          Text(l10n.workerNameLabel(item['worker_name'] ?? l10n.noneAssigned))
                        else
                          Text(l10n.clientNameLabel(item['client_name'] ?? l10n.unknownName)),
                        
                        Text(l10n.patientNameOnlyLabel(item['patient_name'] ?? l10n.unknownName)),
                        const SizedBox(height: 5),
                        Text(item['formatted_date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: SizedBox(
                      width: 85, // Constrains width so FittedBox can do its text-shrinking magic!
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _getStatusTranslation(item['status'] ?? '', l10n), 
                          style: TextStyle(
                            color: isCompleted ? Colors.green : Colors.red, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
    );
  }
}