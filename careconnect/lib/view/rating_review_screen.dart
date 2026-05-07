import 'package:flutter/material.dart';
import '../services/mysql_api_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ADDED OFFICIAL DICTIONARY

class RatingReviewScreen extends StatefulWidget {
  final String bookingId;
  final String reviewerId;
  final String revieweeId;
  final String revieweeName; // To say "Rate Amira" or "Rate John"
  final String reviewerRole; // 'Client' or 'Worker'

  const RatingReviewScreen({
    Key? key,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.revieweeName,
    required this.reviewerRole,
  }) : super(key: key);

  @override
  State<RatingReviewScreen> createState() => _RatingReviewScreenState();
}

class _RatingReviewScreenState extends State<RatingReviewScreen> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitReview() async {
    final l10n = AppLocalizations.of(context)!; // GRAB DICTIONARY BEFORE ASYNC GAP

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorNoRating), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await MysqlApiService.submitReview(
      bookingId: widget.bookingId,
      reviewerId: widget.reviewerId,
      revieweeId: widget.revieweeId,
      rating: _rating,
      comment: _commentController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context, true); // Return true to indicate success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.successFeedback), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? l10n.errorSubmitReview), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // CONNECTED TO THE DICTIONARY
    final titleText = widget.reviewerRole == 'Client' ? l10n.rateWorker : l10n.rateClient;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Icon(
              _rating >= 4 ? Icons.sentiment_very_satisfied : 
              _rating == 3 ? Icons.sentiment_satisfied : 
              _rating > 0 ? Icons.sentiment_dissatisfied : Icons.star_border,
              size: 60,
              color: const Color(0xFF6B3F69),
            ),
            const SizedBox(height: 15),
            
            // FITTED BOX: Protects the Title
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                titleText,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6B3F69)),
              ),
            ),
            const SizedBox(height: 8),
            
            // FITTED BOX: Protects the Experience Prompt
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l10n.experiencePrompt(widget.revieweeName), // Dynamically injects the name
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 25),

            // Interactive Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40,
                    color: index < _rating ? Colors.amber : Colors.grey.shade300,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 20),

            // Comment Box
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.commentHint,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFF8D5F8C)),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false), // User cancelled
                    child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B3F69),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      // FITTED BOX: Protects the Submit Button
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(l10n.submitBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}