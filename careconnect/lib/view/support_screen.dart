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

  // Helper method to build individual FAQ items
  Widget _buildFaqItem(String question, String answer) {
    return ListTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(answer, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }

  // Helper method to build FAQ categories
  Widget _buildFaqCategory(String title, List<Widget> items) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6B3F69))),
        children: items,
      ),
    );
  }

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
            // --- FAQ SECTION START ---
            const Text('Frequently Asked Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69))),
            const SizedBox(height: 15),
            _buildFaqCategory("1. General & Account", [
              _buildFaqItem("Can I book a service for family members?", "Yes! You can add family members as 'Recipients' in your profile. Select them during your booking."),
              _buildFaqItem("Are the caregivers verified?", "Absolutely. All workers undergo a strict verification process including ICs, driving licenses, and certifications."),
            ]),
            _buildFaqCategory("2. Services & Booking", [
              _buildFaqItem("What types of services do you offer?", "We offer Mobility Services, Physiotherapy & Rehabilitation, and Daily Assistance/Nursing Care."),
              _buildFaqItem("How do I know when my caregiver will arrive?", "You will receive real-time notifications for 'On The Way', 'Arrived', and 'Service Started'."),
            ]),
            _buildFaqCategory("3. Payments", [
              _buildFaqItem("When do I pay for the service?", "Payment is made after completion. Once the caregiver marks the job as 'Completed', you will be prompted to pay."),
              _buildFaqItem("How is the payment amount calculated?", "It is calculated based on the service type, duration, and travel distance."),
            ]),
            _buildFaqCategory("4. Account Status & Safety", [
              _buildFaqItem("How are ratings calculated?", "Your average rating is based on reviews from completed bookings by both clients and workers."),
              _buildFaqItem("Can I get warned or banned due to low ratings?", "Yes. Consistently low ratings may lead to a 'Warning' status or a ban to protect community quality."),
              _buildFaqItem("What happens if my account is banned?", "You can no longer log in. If you believe this was a mistake, use the contact form below to appeal."),
            ]),
            _buildFaqCategory("5. Registration & Security", [
              _buildFaqItem("Why do I need to provide my IC number?", "For security and identity verification to keep the community safe for everyone."),
              _buildFaqItem("I am having trouble signing up?", "Ensure your email and IC/Passport are not already registered. We do not allow duplicate accounts to prevent fraud."),
            ]),
            const SizedBox(height: 40),
            // --- FAQ SECTION END ---

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