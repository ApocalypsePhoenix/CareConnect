import 'dart:convert';
import 'package:http/http.dart' as http;

class MysqlApiService {
  static const String _baseUrl = 'https://arcadiusengine.xyz/careconnect/php';

  static Future<Map<String, dynamic>> registerClient(Map<String, dynamic> clientData) async {
    final url = Uri.parse('$_baseUrl/register.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(clientData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Secure Google Sign-In API Call
  static Future<Map<String, dynamic>> loginWithGoogle(String email, String idToken) async {
    final url = Uri.parse('$_baseUrl/login.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'id_token': idToken,
          'login_type': 'google',
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Updates the user's profile information
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updateData) async {
    final url = Uri.parse('$_baseUrl/update_profile.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Changes the user's password securely
  static Future<Map<String, dynamic>> changePassword(String userId, String currentPassword, String newPassword) async {
    final url = Uri.parse('$_baseUrl/change_password.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Fetches all care recipients for a specific client user (CACHE BUSTER ADDED)
  static Future<Map<String, dynamic>> getRecipients(int userId) async {
    final url = Uri.parse('$_baseUrl/get_recipients.php?user_id=$userId&t=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Adds a new care recipient
  static Future<bool> addRecipient({
    required int userId,
    required String name,
    required String relationship,
    required String age,
    required String medicalCondition,
    required String specialNeeds,
  }) async {
    final url = Uri.parse('$_baseUrl/add_recipient.php');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'relationship': relationship,
          'age': int.tryParse(age.trim()) ?? 0,
          'medical_condition': medicalCondition,
          'special_needs': specialNeeds,
        }),
      );

      print('PHP Add Response Code: ${response.statusCode}');
      print('PHP Add Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == false && data['message'] != null) {
          print('PHP Error Message: ${data['message']}');
        }
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error adding recipient: $e');
      return false;
    }
  }

  /// Updates an existing care recipient
  static Future<bool> updateRecipient({
    required String id,
    required String name,
    required String relationship,
    required String age,
    required String medicalCondition,
    required String specialNeeds,
  }) async {
    final url = Uri.parse('$_baseUrl/update_recipient.php');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': int.tryParse(id) ?? 0,
          'name': name,
          'relationship': relationship,
          'age': int.tryParse(age.trim()) ?? 0,
          'medical_condition': medicalCondition,
          'special_needs': specialNeeds,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error updating recipient: $e');
      return false;
    }
  }

  /// Deletes an existing care recipient
  static Future<bool> deleteRecipient(String id) async {
    final url = Uri.parse('$_baseUrl/delete_recipient.php');
    try {
      final response = await http.post(
        url,
        body: {'id': id},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print("Error deleting recipient: $e");
      return false;
    }
  }

  // LIVE BOOKING & WORKER REQUEST LOGIC
  static Future<Map<String, dynamic>> submitBooking(Map<String, dynamic> bookingData) async {
    final url = Uri.parse('$_baseUrl/submit_booking.php');
    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'}, 
        body: jsonEncode(bookingData)
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateWorkerVisibility(String workerId, bool isOnline) async {
    final url = Uri.parse('$_baseUrl/update_visibility.php');
    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'}, 
        body: jsonEncode({'worker_id': workerId, 'is_online': isOnline ? 1 : 0})
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // CACHE BUSTER ADDED
  static Future<Map<String, dynamic>> getAvailableRequests(String workerId, double lat, double lng) async {
    final url = Uri.parse('$_baseUrl/get_requests.php?worker_id=$workerId&lat=$lat&lng=$lng&t=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> respondToRequest(String requestId, String workerId, String action) async {
    final url = Uri.parse('$_baseUrl/respond_request.php');
    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'}, 
        body: jsonEncode({'request_id': requestId, 'worker_id': workerId, 'action': action})
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ACTIVE SERVICES & LIVE TRACKING LOGIC (CACHE BUSTER ADDED)
  static Future<Map<String, dynamic>> getActiveService({String? clientId, String? workerId}) async {
    String query = '';
    if (clientId != null) query = '?client_id=$clientId';
    if (workerId != null) query = '?worker_id=$workerId';
    
    // Add cache buster depending on if a query string already exists
    String cacheBuster = (query.isEmpty ? '?' : '&') + 't=${DateTime.now().millisecondsSinceEpoch}';
    
    final url = Uri.parse('$_baseUrl/get_active_service.php$query$cacheBuster');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateServiceStatus(String bookingId, String newStatus) async {
    final url = Uri.parse('$_baseUrl/update_service_status.php');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'booking_id': bookingId, 'status': newStatus}));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> cancelService(String bookingId, String role) async {
    final url = Uri.parse('$_baseUrl/cancel_service.php');
    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'}, 
        body: jsonEncode({'booking_id': bookingId, 'role': role})
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NEW: Decline Worker API
  static Future<Map<String, dynamic>> declineWorker(String bookingId, String workerId) async {
    final url = Uri.parse('$_baseUrl/decline_worker.php');
    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'}, 
        body: jsonEncode({'booking_id': bookingId, 'worker_id': workerId})
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Function to find out why a job disappeared (CACHE BUSTER ADDED)
  static Future<Map<String, dynamic>> checkBookingStatus(String bookingId) async {
    final url = Uri.parse('$_baseUrl/check_booking_status.php?booking_id=$bookingId&t=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  //Fetch Booking History (Completed or Cancelled)
  static Future<Map<String, dynamic>> getBookingHistory({String? clientId, String? workerId}) async {
    String query = '';
    if (clientId != null) query = '?client_id=$clientId';
    if (workerId != null) query = '?worker_id=$workerId';
    
    final url = Uri.parse('$_baseUrl/get_history.php$query&t=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  // NEW: TWO-WAY REVIEW & RATING API
  static Future<Map<String, dynamic>> submitReview({
    required String bookingId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    required String comment,
  }) async {
    final url = Uri.parse('$_baseUrl/submit_review.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'booking_id': bookingId,
          'reviewer_id': reviewerId,
          'reviewee_id': revieweeId,
          'rating': rating,
          'comment': comment,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getNotifications(String userId) async {
    final url = Uri.parse('$_baseUrl/get_notifications.php?user_id=$userId&t=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationsRead(String userId) async {
    final url = Uri.parse('$_baseUrl/mark_notification_read.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}