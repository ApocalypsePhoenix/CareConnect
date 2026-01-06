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
}