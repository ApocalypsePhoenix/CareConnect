import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';

class SupportScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SupportScreen({super.key, required this.user});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedTopic;
  bool _isLoading = false;

  final List<String> _topics = [
    'General Inquiry',
    'Report a User',
    'Payment / Billing Issue',
    'Technical App Issue',
    'Other'
  ];

  Future<void> _submitForm() async {
    if (_selectedTopic == null) {
      _showError('Please select a topic.');
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _showError('Please write a message.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await MysqlApiService.submitSupportTicket(
      userId: widget.user['id'].toString(),
      role: widget.user['role'] ?? 'Unknown',
      topic: _selectedTopic!,
      message: _messageController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent! Admin will review it soon.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Close the screen on success
      }
    } else {
      _showError(result['message'] ?? 'Failed to send message.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Contact Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6B3F69),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.support_agent, size: 60, color: Color(0xFF8D5F8C)),
            const SizedBox(height: 15),
            const Text('How can we help you?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 5),
            const Text('Send us a message and our admin team will investigate.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 30),

            // Dropdown for Topic
            const Text('Select Topic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTopic,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              hint: const Text('Choose a category...'),
              items: _topics.map((String topic) {
                return DropdownMenuItem<String>(value: topic, child: Text(topic));
              }).toList(),
              onChanged: (newValue) => setState(() => _selectedTopic = newValue),
            ),
            const SizedBox(height: 20),

            // Text Area for Message
            const Text('Your Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Describe your issue or question in detail...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 40),

            // Cancel and Send Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                  )
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B3F69),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send Message', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  )
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}