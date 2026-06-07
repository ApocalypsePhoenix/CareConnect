import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 
import '../services/mysql_api_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// IMPORTS FOR PDF GENERATION AND TIME FORMATTING
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

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
    final isClient = widget.user['role'] == 'Client';
    
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

  // --- LOGIC HELPER: Convert Global UTC DB Time to User's Local Time ---
  String _formatToLocalTime(String? dbUtcTime) {
    if (dbUtcTime == null || dbUtcTime.isEmpty) return 'N/A';
    try {
      // Step 1: Force the string into strict ISO 8601 format so Dart knows it is UTC
      String isoFormat = dbUtcTime.replaceFirst(' ', 'T') + 'Z';
      
      // Step 2: Parse it as a strict UTC DateTime object
      DateTime parsedUtc = DateTime.parse(isoFormat);
      
      // Step 3: Convert to Local Device Time (e.g., UTC+8 for Malaysia)
      DateTime localTime = parsedUtc.toLocal();
      
      // Step 4: Format it beautifully
      return DateFormat('dd MMM yyyy, hh:mm a').format(localTime);
    } catch (e) {
      return dbUtcTime; // Fallback to raw string if parsing fails
    }
  }

  // --- LOGIC HELPER: Recalculate Price exactly like Booking Screen ---
  double _calculateEstimatedPrice(Map<String, dynamic> item) {
    String service = item['service_needed'] ?? '';
    String durationStr = item['expected_duration'] ?? '1 hour';
    int hours = int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    
    if (service == 'Mobility Service') {
      double baseFee = 15.0;
      double hourlyRate = 10.0;
      double distanceFee = 0.0;
      
      var pLat = item['pickup_lat'];
      var pLng = item['pickup_lng'];
      var dLat = item['dropoff_lat'];
      var dLng = item['dropoff_lng'];

      if (pLat != null && pLng != null && dLat != null && dLng != null) {
        double distMeters = Geolocator.distanceBetween(
          double.parse(pLat.toString()), double.parse(pLng.toString()), 
          double.parse(dLat.toString()), double.parse(dLng.toString())
        );
        distanceFee = (distMeters / 1000) * 1.50; // RM 1.50 per KM
      }
      return baseFee + (hours * hourlyRate) + distanceFee;
    } else if (service == 'Physiotherapy/Rehabilitation') {
      return hours * 50.0;
    } else {
      return hours * 30.0;
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

  // --- PDF GENERATION (PRINT & SHARE) ---
// --- PDF GENERATION (PRINT & SHARE) ---
  Future<void> _generateReceipt(Map<String, dynamic> item, double price, AppLocalizations l10n, String action) async {
    final doc = pw.Document();
    final serviceName = _getServiceTranslation(item['service_needed'] ?? '', l10n);
    final bookingId = item['id']?.toString() ?? 'Unknown';
    
    // Use the new helper to get exact local time based on the DB created_at row
    final serviceDateLocal = _formatToLocalTime(item['created_at']?.toString());
    
    // Receipt generated timestamp (Current local time)
    final printDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // FIX: Dynamically detect the Client's name based on who is logged in!
    final isClient = widget.user['role'] == 'Client';
    final actualClientName = isClient ? widget.user['name'] : (item['client_name'] ?? 'N/A');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CareConnect', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                  pw.Text('RECEIPT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text('Generated on: $printDate', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
              pw.SizedBox(height: 15),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),
              
              // Booking Meta Data
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Receipt No: #CC-$bookingId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Service Date: $serviceDateLocal'), // Perfectly aligned local time
                      pw.Text('Status: PAID & COMPLETED', style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                ]
              ),
              pw.SizedBox(height: 30),

              // Parties Involved
              pw.Text('DETAILS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // FIX: Applied the actualClientName here
                    pw.Text('Client Name: $actualClientName'),
                    pw.Text('Patient Name: ${item['patient_name'] ?? 'N/A'}'),
                    pw.Text('Caregiver Assigned: ${item['worker_name'] ?? 'N/A'}'),
                  ]
                )
              ),
              pw.SizedBox(height: 30),

              // Service Data
              pw.Text('SERVICE DESCRIPTION', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Service Type: $serviceName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Duration: ${item['expected_duration'] ?? 'N/A'}'),
                    pw.Text('Location: ${item['pickup_location'] ?? 'N/A'}'),
                  ]
                )
              ),
              pw.SizedBox(height: 40),

              // Total Amount
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL AMOUNT PAID:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('RM ${price.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2),
              
              pw.Spacer(),
              pw.Center(
                child: pw.Text('Thank you for using CareConnect!', style: pw.TextStyle(color: PdfColors.grey600, fontStyle: pw.FontStyle.italic))
              )
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final filename = 'CareConnect_Receipt_$bookingId.pdf';

    if (action == 'share') {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else if (action == 'print') {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes, name: filename);
    }
  }

  // --- BOTTOM SHEET FOR DETAILS ---
  void _showBookingDetails(Map<String, dynamic> item, AppLocalizations l10n, bool isClient) {
    bool isCompleted = item['status'] == 'Completed';
    double estimatedPrice = _calculateEstimatedPrice(item);
    String serviceName = _getServiceTranslation(item['service_needed'] ?? '', l10n);
    String localTime = _formatToLocalTime(item['created_at']?.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(serviceName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: isCompleted ? Colors.green.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(20)),
                    child: Text(_getStatusTranslation(item['status'] ?? '', l10n), style: TextStyle(color: isCompleted ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const Divider(height: 30, thickness: 1),

              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display perfectly aligned local time
                      _buildDetailRow(Icons.calendar_today, 'Date & Time', localTime),
                      const SizedBox(height: 15),
                      
                      isClient 
                        ? _buildDetailRow(Icons.badge, 'Worker Name', item['worker_name'] ?? 'Not assigned yet')
                        : _buildDetailRow(Icons.person, 'Client Name', item['client_name'] ?? 'Unknown'),
                      
                      const SizedBox(height: 15),
                      _buildDetailRow(Icons.personal_injury, 'Patient', '${item['patient_name']} (Age: ${item['patient_age']})'),
                      const SizedBox(height: 15),
                      _buildDetailRow(Icons.medical_information, 'Medical Info', '${item['medical_condition']}\nSpecial Needs: ${item['special_needs'] ?? 'None'}'),
                      const SizedBox(height: 15),
                      
                      _buildDetailRow(Icons.location_on, 'Location', item['pickup_location'] ?? 'N/A'),
                      if (item['service_needed'] == 'Mobility Service' && item['dropoff_location'] != null && item['dropoff_location'].toString().isNotEmpty) ...[
                        const SizedBox(height: 15),
                        _buildDetailRow(Icons.local_hospital, 'Drop-off', item['dropoff_location']),
                      ],
                      
                      const SizedBox(height: 15),
                      _buildDetailRow(Icons.timer, 'Preferences', 'Duration: ${item['expected_duration']}\nLanguage: ${item['preferred_language']}\nGender: ${item['preferred_gender']}'),
                      
                      const SizedBox(height: 30),
                      // Price Container
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.green.shade200, width: 2)
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated Price', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                            Text('RM ${estimatedPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              // Split Receipt Buttons (Only shows if Completed)
              if (isCompleted) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _generateReceipt(item, estimatedPrice, l10n, 'print'),
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                        label: const Text('Save PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _generateReceipt(item, estimatedPrice, l10n, 'share'),
                        icon: const Icon(Icons.share, color: Colors.white, size: 20),
                        label: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B3F69), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Close Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF8D5F8C), size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                
                // Display Local Time instead of the PHP Formatted UTC time
                String localTime = _formatToLocalTime(item['created_at']?.toString());
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => _showBookingDetails(item, l10n, isClient), 
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
                          if (isClient)
                            Text(l10n.workerNameLabel(item['worker_name'] ?? l10n.noneAssigned))
                          else
                            Text(l10n.clientNameLabel(item['client_name'] ?? l10n.unknownName)),
                          
                          Text(l10n.patientNameOnlyLabel(item['patient_name'] ?? l10n.unknownName)),
                          const SizedBox(height: 5),
                          Text(localTime, style: const TextStyle(fontSize: 12, color: Colors.grey)), 
                        ],
                      ),
                      trailing: SizedBox(
                        width: 85,
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
                  ),
                );
              }
            ),
    );
  }
}