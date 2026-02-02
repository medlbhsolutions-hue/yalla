import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../services/rating_service.dart';

/// Écran pour noter une course terminée
class RideRatingScreen extends StatefulWidget {
  final String rideId;
  final String raterRole; // 'patient' ou 'driver'
  final Map<String, dynamic> rideData;

  const RideRatingScreen({
    Key? key,
    required this.rideId,
    required this.raterRole,
    required this.rideData,
  }) : super(key: key);

  @override
  State<RideRatingScreen> createState() => _RideRatingScreenState();
}

class _RideRatingScreenState extends State<RideRatingScreen> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final success = await RatingService.submitRating(
      rideId: widget.rideId,
      rating: _rating,
      raterRole: widget.raterRole,
      comment: _commentController.text.trim().isEmpty 
          ? null 
          : _commentController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Merci pour votre avis !'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur lors de l\'envoi de l\'avis'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherPerson = widget.raterRole == 'patient' 
        ? widget.rideData['driver']
        : widget.rideData['patient'];
    
    final otherName = '${otherPerson?['first_name'] ?? ''} ${otherPerson?['last_name'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Évaluer la course',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.raterRole == 'patient' 
                    ? Icons.local_shipping
                    : Icons.person,
                size: 50,
                color: const Color(0xFF4CAF50),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Nom de la personne à noter
            Text(
              widget.raterRole == 'patient'
                  ? 'Comment s\'est passée votre course avec'
                  : 'Comment était ce patient ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              otherName.isNotEmpty ? otherName : 'Utilisateur',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Stars de notation
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemSize: 50,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Color(0xFFFFB300),
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
            
            const SizedBox(height: 12),
            
            // Texte de la note
            Text(
              _getRatingText(_rating),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _getRatingColor(_rating),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Champ de commentaire
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _commentController,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Partagez votre expérience (optionnel)',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Bouton de soumission
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Envoyer l\'avis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bouton passer
            TextButton(
              onPressed: _isSubmitting 
                  ? null 
                  : () => Navigator.of(context).pop(),
              child: Text(
                'Passer',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent ! 🌟';
    if (rating >= 4) return 'Très bien 👍';
    if (rating >= 3) return 'Bien';
    if (rating >= 2) return 'Moyen';
    return 'À améliorer';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return const Color(0xFF4CAF50);
    if (rating >= 3) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}
