import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; 
import '../services/mysql_api_service.dart';
import 'recipient_screen.dart';
import 'settingclient_screen.dart'; 
import 'booking_screen.dart';
import 'dart:async';
import 'booking_history_screen.dart';
import 'rating_review_screen.dart'; 
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 

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
  
  Timer? _autoRefreshTimer; 
  bool _isCancelling = false;
  bool _hasPromptedApproval = false; 

  Map<String, dynamic>? _latestHistoryItem;
  bool _isLoadingHistory = true;

  // --- NEW: DATABASE NOTIFICATIONS STATE ---
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _fetchRecipients();
    _fetchActiveService();
    _fetchLatestHistory(); 
    _fetchNotifications(); // FETCH ALERTS ON BOOT
    
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchActiveService(isBackground: true);
      _fetchNotifications(); // FETCH ALERTS IN BACKGROUND
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLatestHistory() async {
    final result = await MysqlApiService.getBookingHistory(clientId: _currentUser['id'].toString());
    if (mounted) {
      setState(() {
        if (result['success'] == true && (result['history'] as List).isNotEmpty) {
          _latestHistoryItem = result['history'][0]; 
        } else {
          _latestHistoryItem = null;
        }
        _isLoadingHistory = false;
      });
    }
  }

  // --- NEW: FETCH NOTIFICATIONS FROM MYSQL ---
  Future<void> _fetchNotifications() async {
    final result = await MysqlApiService.getNotifications(_currentUser['id'].toString());
    if (mounted && result['success'] == true) {
      final notifs = result['notifications'] as List;
      
      // Calculate how many unread rows exist
      int unread = notifs.where((n) => n['is_read'] == 0 || n['is_read'] == '0').length;
      
      setState(() {
        _notifications = notifs;
        _unreadCount = unread;
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
          
          if (_activeService!['status'] == 'Pending_Approval' && !_hasPromptedApproval) {
            _hasPromptedApproval = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showWorkerApprovalDialog();
            });
          } else if (_activeService!['status'] != 'Pending_Approval') {
            _hasPromptedApproval = false; 
          }

        } else {
          if (hadActiveService && oldBookingId != null && isBackground && !_isCancelling) {
             _checkWhyItDisappeared(oldBookingId);
          }
          _activeService = null;
          _hasPromptedApproval = false;
        }
      });
    }
  }

  Future<void> _checkWhyItDisappeared(String bookingId) async {
    final statusResult = await MysqlApiService.checkBookingStatus(bookingId);
    if (mounted && statusResult['success'] == true) {
      final l10n = AppLocalizations.of(context)!;
      if (statusResult['status'] == 'Cancelled') {
        _showStatusPopup(l10n.serviceTerminated, l10n.workerCancelledBooking, Colors.red, Icons.cancel);
        _fetchLatestHistory(); 
      }
    }
  }

  void _showDummyPaymentDialog() {
    final l10n = AppLocalizations.of(context)!;
    bool isProcessing = false;
    bool isSuccess = false;
    
    final String savedBookingId = _activeService?['id']?.toString() ?? '';
    final String savedWorkerId = _activeService?['worker_id']?.toString() ?? '';
    final String savedWorkerName = _activeService?['worker_name']?.toString() ?? 'your Caregiver';
    
    double serviceAmount = 0.0;
    String serviceType = _activeService?['service_needed'] ?? '';
    String durationStr = _activeService?['expected_duration'] ?? '1 hour';
    
    int hours = int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    if (serviceType == 'Mobility Service') {
      double baseFee = 15.0; 
      double hourlyRate = 10.0; 
      double distanceFee = 0.0;
      
      if (_activeService?['pickup_lat'] != null && _activeService?['dropoff_lat'] != null) {
        double pLat = double.parse(_activeService!['pickup_lat'].toString());
        double pLng = double.parse(_activeService!['pickup_lng'].toString());
        double dLat = double.parse(_activeService!['dropoff_lat'].toString());
        double dLng = double.parse(_activeService!['dropoff_lng'].toString());
        
        double distanceInMeters = Geolocator.distanceBetween(pLat, pLng, dLat, dLng);
        double distanceInKm = distanceInMeters / 1000;
        distanceFee = distanceInKm * 1.50; 
      }
      serviceAmount = baseFee + (hours * hourlyRate) + distanceFee;
      
    } else if (serviceType == 'Physiotherapy/Rehabilitation') {
      serviceAmount = hours * 50.0;
    } else {
      serviceAmount = hours * 30.0;
    }

    double adminFee = serviceAmount * 0.03; 
    double workerEarns = serviceAmount - adminFee;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: isSuccess
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 80),
                          const SizedBox(height: 20),
                          Text(l10n.paymentSuccessful, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 10),
                          Text(l10n.paymentReleased, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context); 

                                await showDialog(
                                  context: context,
                                  barrierDismissible: false, 
                                  builder: (context) => RatingReviewScreen(
                                    bookingId: savedBookingId, 
                                    reviewerId: widget.user['id'].toString(),   
                                    revieweeId: savedWorkerId, 
                                    revieweeName: savedWorkerName, 
                                    reviewerRole: widget.user['role'],          
                                  ),
                                );

                                _fetchActiveService(isBackground: false); 
                                _fetchLatestHistory(); 
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              child: Text(l10n.done, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long, size: 60, color: Color(0xFF6B3F69)),
                          const SizedBox(height: 15),
                          Text(l10n.serviceCompleted, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                          const SizedBox(height: 10),
                          Text(
                            l10n.paymentPromptDesc, 
                            textAlign: TextAlign.center, 
                            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)
                          ),
                          const SizedBox(height: 20),
                          
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50, 
                              borderRadius: BorderRadius.circular(15), 
                              border: Border.all(color: Colors.grey.shade200)
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(l10n.totalServiceFee, style: const TextStyle(color: Colors.black87)))), 
                                    const SizedBox(width: 10),
                                    Text('RM ${serviceAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))
                                  ]
                                ),
                                const Divider(height: 25),
                                Row(
                                  children: [
                                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(l10n.platformFee, style: const TextStyle(color: Colors.redAccent, fontSize: 12)))), 
                                    const SizedBox(width: 10),
                                    Text('- RM ${adminFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 12))
                                  ]
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(l10n.workerReceives, style: const TextStyle(color: Colors.green, fontSize: 12)))), 
                                    const SizedBox(width: 10),
                                    Text('RM ${workerEarns.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))
                                  ]
                                ),
                                const Divider(height: 25),
                                Row(
                                  children: [
                                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(l10n.totalToPay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))), 
                                    const SizedBox(width: 10),
                                    Text('RM ${serviceAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF6B3F69)))
                                  ]
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: isProcessing ? null : () async {
                                setDialogState(() => isProcessing = true);
                                
                                await Future.delayed(const Duration(seconds: 2));

                                final result = await MysqlApiService.updateServiceStatus(savedBookingId, 'Completed');

                                if (result['success'] == true) {
                                  setDialogState(() {
                                    isProcessing = false;
                                    isSuccess = true;
                                  });
                                } else {
                                  setDialogState(() => isProcessing = false);
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paymentFailedDatabase)));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6B3F69), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                              ),
                              child: isProcessing
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(l10n.payNowBtn(serviceAmount.toStringAsFixed(2)), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                            ),
                          )
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStatusPopup(String title, String message, Color color, IconData icon) {
    final l10n = AppLocalizations.of(context)!;
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
                child: Text(l10n.ok, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      )
    );
  }

  void _showWorkerApprovalDialog() {
    final l10n = AppLocalizations.of(context)!;
    final workerName = _activeService!['worker_name'] ?? 'Worker';
    final workerPhone = _activeService!['worker_phone'] ?? l10n.noPhoneProvided;
    
    final workerGender = _getGenericTranslation(_activeService!['worker_gender']?.toString().trim() ?? 'Not specified', l10n);
    final workerRace = _getGenericTranslation(_activeService!['worker_race']?.toString().trim() ?? 'Not specified', l10n);
    final workerLanguage = _getGenericTranslation(_activeService!['worker_language']?.toString().trim() ?? 'Not specified', l10n);
    
    final rawAge = _activeService!['worker_age']?.toString() ?? 'N/A';
    final isMs = Localizations.localeOf(context).languageCode == 'ms';
    final workerAgeText = rawAge != 'N/A' ? '$rawAge ${isMs ? 'thn' : 'yrs'}' : 'N/A';

    final passportImg = _activeService!['worker_passport'];

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView( 
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.workerFound, style: const TextStyle(color: Color(0xFF6B3F69), fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(l10n.reviewWorkerDesc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: passportImg != null && passportImg.toString().isNotEmpty
                      ? Image.network(
                          'https://arcadiusengine.xyz/careconnect/$passportImg',
                          width: 130,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                        )
                      : _buildPlaceholderImage(),
                ),
                
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200)
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person, l10n.fullName, workerName),
                      const Divider(height: 20, color: Colors.black12),
                      Row(
                        children: [
                          Expanded(child: _buildInfoRow(Icons.cake, l10n.age, workerAgeText)),
                          Expanded(child: _buildInfoRow(Icons.wc, l10n.gender, workerGender)),
                        ],
                      ),
                      const Divider(height: 20, color: Colors.black12),
                      Row(
                        children: [
                          Expanded(child: _buildInfoRow(Icons.groups, l10n.race, workerRace)),
                          Expanded(child: _buildInfoRow(Icons.language, l10n.language, workerLanguage)),
                        ],
                      ),
                      const Divider(height: 20, color: Colors.black12),
                      _buildInfoRow(Icons.phone, l10n.phoneNumber, workerPhone),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),
               
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _declineWorker();
                        }, 
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        child: Text(l10n.decline, style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))
                      )
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveWorker();
                        }, 
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        child: Text(l10n.approve, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      )
                    ),
                  ]
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 130,
      height: 160,
      color: Colors.grey.shade200,
      child: const Icon(Icons.portrait, size: 60, color: Colors.grey),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B3F69)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        )
      ],
    );
  }

  Future<void> _approveWorker() async {
    if (_activeService == null) return; 
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoadingService = true);
    final result = await MysqlApiService.updateServiceStatus(_activeService!['id'].toString(), 'Accepted');
    if (result['success'] == true) {
      _showStatusPopup(l10n.workerApproved, l10n.workerHeadingToLocation, Colors.green, Icons.check_circle);
      _fetchActiveService(isBackground: false);
    }
  }

  Future<void> _declineWorker() async {
    if (_activeService == null) return; 
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoadingService = true);
    final result = await MysqlApiService.declineWorker(_activeService!['id'].toString(), _activeService!['worker_id'].toString());
    if (result['success'] == true) {
      _showStatusPopup(l10n.workerDeclined, l10n.workerDeclinedDesc, Colors.orange, Icons.refresh);
      _fetchActiveService(isBackground: false);
    }
  }

  Future<void> _cancelService() async {
    if (_activeService == null || _isCancelling) return;
    final l10n = AppLocalizations.of(context)!;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelBooking, style: const TextStyle(color: Colors.red)),
        content: Text(l10n.cancelBookingConfirmDesc),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.noKeepIt, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.yesCancel, style: const TextStyle(color: Colors.white)),
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
          _showStatusPopup(l10n.bookingCancelled, l10n.bookingCancelledSuccess, Colors.red, Icons.cancel);
          _fetchActiveService(isBackground: false); 
          _fetchLatestHistory(); 
        }
      }
    }
  }

  // =========================================================================
  // --- NEW: SMART NOTIFICATION PANEL ---
  // =========================================================================
  void _showNotificationPanel(BuildContext context, AppLocalizations l10n) {
    // We now map completely from the MySQL Database!
    List<Widget> notificationWidgets = _notifications.map((notif) {
      bool isUnread = notif['is_read'] == 0 || notif['is_read'] == '0';
      
      // --- NEW: GLOBAL TIMEZONE CONVERTER ---
      String displayTime = 'Recently';
      if (notif['created_at'] != null) {
        try {
          // Add 'Z' to tell Dart this time is UTC, then convert to phone's Local Time
          DateTime utcTime = DateTime.parse(notif['created_at'].toString() + "Z");
          DateTime localTime = utcTime.toLocal();
          
          // Format it back nicely (YYYY-MM-DD HH:mm)
          displayTime = "${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}";
        } catch (e) {
          displayTime = notif['created_at'].toString().substring(0, 16); // Fallback
        }
      }

      return _buildNotificationItem(
        icon: isUnread ? Icons.notifications_active : Icons.notifications_none,
        color: isUnread ? Colors.blueAccent : Colors.grey.shade600,
        title: notif['title'] ?? 'Notification',
        desc: notif['message'] ?? '',
        time: displayTime, // Now uses the automatically converted local time!
      );
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Notifications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: notificationWidgets.isEmpty 
                ? const Center(child: Text("No new notifications", style: TextStyle(color: Colors.grey)))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    children: notificationWidgets,
                  ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({required IconData icon, required Color color, required String title, required String desc, required String time}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2))
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3)),
                const SizedBox(height: 8),
                Text(time, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
  // =========================================================================

  // --- VISUAL TRANSLATION HELPERS ---
  String _getServiceTranslation(String key, AppLocalizations l10n) {
    if (key == 'Mobility Service') return l10n.mobilityService;
    if (key == 'Physiotherapy/Rehabilitation') return l10n.physiotherapy;
    if (key == 'Daily Assistance/Nursing Care') return l10n.nursingCare;
    return key;
  }
  
  String _getGenericTranslation(String key, AppLocalizations l10n) {
    final k = key.trim(); 
    if (k == 'Male') return l10n.male;
    if (k == 'Female') return l10n.female;
    if (k == 'Malay') return l10n.malay;
    if (k == 'Chinese') return l10n.chinese;
    if (k == 'Indian') return l10n.indian;
    if (k == 'English') return l10n.english;
    if (k == 'Mandarin') return l10n.mandarin;
    if (k == 'Tamil') return l10n.tamil;
    if (k == 'Any') return l10n.anyOption;
    return k;
  }

  String _getTranslatedRelation(String val, AppLocalizations l10n) {
    final trimmed = val.trim();
    if (trimmed == 'Parent') return l10n.parent;
    if (trimmed == 'Grandparent') return l10n.grandparent;
    if (trimmed == 'Spouse') return l10n.spouse;
    if (trimmed == 'Other' || trimmed == 'Others') return l10n.othersOption;
    return val;
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
    final l10n = AppLocalizations.of(context)!; 

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
                                      Text(l10n.hello, style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
                          
                          // ==========================================
                          // BELL ICON WITH REAL-TIME RED BADGE
                          // ==========================================
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.white24,
                                child: IconButton(
                                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                                  onPressed: () {
                                    _showNotificationPanel(context, l10n);
                                    
                                    // If they had unread messages, mark them as read in DB!
                                    if (_unreadCount > 0) {
                                      MysqlApiService.markNotificationsRead(_currentUser['id'].toString());
                                      setState(() {
                                        _unreadCount = 0;
                                        // Update local list visually immediately
                                        for (var n in _notifications) {
                                          n['is_read'] = 1;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              if (_unreadCount > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF6B3F69), width: 1.5),
                                    ),
                                    child: Text(
                                      '$_unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
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
                  _buildBookNowCard(l10n),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.careRecipients, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => RecipientScreen(user: _currentUser)))
                                     .then((_) => _fetchRecipients());
                        }, 
                        child: Text(l10n.addNew)
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _isLoadingRecipients 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
                    : _recipients.isEmpty 
                      ? _buildEmptyRecipients(l10n)
                      : _buildRecipientsList(l10n),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.activeServices, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF6B3F69)),
                        onPressed: () => _fetchActiveService(isBackground: false), 
                      )
                    ],
                  ),
                  const SizedBox(height: 5),
                  
                  if (_isLoadingService)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)))
                  else if (_activeService != null)
                    _buildActiveJobCard(l10n)
                  else
                    _buildEmptyBookingStatusCard(l10n),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.bookingHistory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingHistoryScreen(user: _currentUser)))
                                     .then((_) => _fetchLatestHistory()); 
                        }, 
                        child: Text(l10n.viewAll)
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBookingHistoryCard(l10n),
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
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), label: l10n.home),
          BottomNavigationBarItem(icon: const Icon(Icons.calendar_today_outlined), label: l10n.bookings),
          BottomNavigationBarItem(icon: const Icon(Icons.people_outline), label: l10n.recipientsNav),
          BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), label: l10n.settings),
        ],
      ),
    );
  }

  Widget _buildBookNowCard(AppLocalizations l10n) {
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
                Text(l10n.needProfessionalCare, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
                const SizedBox(height: 5),
                Text(l10n.bookWorkerDesc, style: const TextStyle(fontSize: 13, color: Colors.black54)),
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
                  child: Text(l10n.bookWorkerBtn, style: const TextStyle(color: Colors.white)),
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

  Widget _buildEmptyRecipients(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 40, color: Colors.grey),
          const SizedBox(height: 10),
          Text(l10n.noRecipientsAdded, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecipientsList(AppLocalizations l10n) {
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
                      Text(
                        _getTranslatedRelation(recipient['relationship']?.toString() ?? '', l10n), 
                        style: const TextStyle(color: Colors.grey, fontSize: 11)
                      ),
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

  Widget _buildActiveJobCard(AppLocalizations l10n) {
    String currentStatus = _activeService!['status'] ?? 'Pending_Approval';
    String serviceType = _activeService!['service_needed'] ?? '';
    
    int statusIndex = 0;
    if (currentStatus == 'On_The_Way') statusIndex = 1;
    if (currentStatus == 'Arrived') statusIndex = 2;
    if (currentStatus == 'In_Progress' || currentStatus == 'Pending_Payment') statusIndex = 3;

    List<String> stepTitles = [];
    if (serviceType == 'Mobility Service') {
      stepTitles = [l10n.trackAssigned, l10n.trackHeadingPickup, l10n.trackArrivedPickup, l10n.trackHeadingDropoff];
    } else {
      stepTitles = [l10n.trackAssigned, l10n.trackOnTheWay, l10n.trackArrivedClient, l10n.trackServiceOngoing];
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
              Flexible(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(l10n.workerAssigned, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _getStatusTranslation(currentStatus, l10n), 
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (_activeService!['worker_passport'] != null && _activeService!['worker_passport'].toString().isNotEmpty)
                    ? NetworkImage('https://arcadiusengine.xyz/careconnect/${_activeService!['worker_passport']}')
                    : null,
                child: (_activeService!['worker_passport'] == null || _activeService!['worker_passport'].toString().isEmpty)
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
                    Text(
                      l10n.servicePrefix(_getServiceTranslation(_activeService!['service_needed'], l10n)), 
                      style: const TextStyle(fontSize: 13, color: Colors.black87)
                    ),
                  ],
                ),
              )
            ],
          ),
          
          const Divider(height: 20),
          
          Row(children: [
            const Icon(Icons.phone, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(_activeService!['worker_phone'] ?? l10n.noPhoneProvided, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ]),

          const SizedBox(height: 20),
          
          if (currentStatus == 'Pending_Payment')
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.paymentRequired, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 10),
                  Text(l10n.paymentRequiredDesc, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showDummyPaymentDialog(),
                      icon: const Icon(Icons.payment, color: Colors.white),
                      label: Text(l10n.makePayment, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                    ),
                  )
                ]
              )
            )
          else if (currentStatus == 'Pending_Approval')
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.actionRequired, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 10),
                  Text(l10n.actionRequiredDesc, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _declineWorker,
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                          child: Text(l10n.decline, style: const TextStyle(color: Colors.redAccent)),
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _approveWorker,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: Text(l10n.approve, style: const TextStyle(color: Colors.white)),
                        )
                      ),
                    ]
                  )
                ]
              )
            )
          else
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(15)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.liveDeliveryTracker, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
          
          if (currentStatus != 'Pending_Payment')
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isCancelling ? null : _cancelService,
                icon: _isCancelling 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                  : const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_isCancelling ? l10n.cancelling : l10n.cancelBooking, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            )
        ],
      ),
    );
  }

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

  Widget _buildEmptyBookingStatusCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          const Icon(Icons.history_outlined, size: 30, color: Color(0xFF8D5F8C)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.noActiveBookings, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(l10n.ongoingServicesDesc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingHistoryCard(AppLocalizations l10n) {
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
                        Text(l10n.noPastHistory, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(l10n.historyDesc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                        Text(l10n.latestBooking, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _getServiceTranslation(_latestHistoryItem!['service_needed'] ?? 'Service', l10n), 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                          ),
                        ),
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