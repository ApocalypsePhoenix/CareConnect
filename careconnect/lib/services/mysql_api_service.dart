import 'dart:convert';
import 'package:http/http.dart' as http;

class MysqlApiService {
  static const String _baseUrl = 'https://arcadiusengine.xyz/careconnect/php';

  static Future<Map<String, dynamic>> registerClient(Map<String, dynamic> clientData) async {
    final url = Uri.parse('$_baseUrl/register_client.php');
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

  /// Fetches all care recipients for a specific client user
  static Future<Map<String, dynamic>> getRecipients(int userId) async {
    final url = Uri.parse('$_baseUrl/get_recipients.php?user_id=$userId');
    try {
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
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
          'Content-Type': 'application/json', // Changed to JSON to match your other API calls
        },
        body: jsonEncode({
          'id': int.tryParse(id) ?? 0, // Ensure id is passed securely as an int
          'name': name,
          'relationship': relationship,
          'age': int.tryParse(age.trim()) ?? 0, // Ensure age is parsed to int for the DB
          'medical_condition': medicalCondition,
          'special_needs': specialNeeds,
        }),
      );

      // Print the raw server response to the console to help debug PHP issues!
      print('PHP Response Code: ${response.statusCode}');
      print('PHP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // If the PHP script returns an error message, print it out
        if (data['success'] == false && data['message'] != null) {
          print('PHP Error Message: ${data['message']}');
        }
        
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error updating recipient: $e');
      return false;
    }
  }
}