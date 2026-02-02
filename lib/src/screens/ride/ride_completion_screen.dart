import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import '../../services/stripe_payment_service.dart';
import '../../services/rating_service.dart';

/// Écran de fin de course avec paiement et évaluation
class RideCompletionScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideDetails;
  final bool isDriver;

  const RideCompletionScreen({
    required this.rideId,
    required this.rideDetails,
    this.isDriver = false,
    super.key,
  });

  @override
  State<RideCompletionScreen> createState() => _RideCompletionScreenState();
}

class _RideCompletionScreenState extends State<RideCompletionScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  
  bool _isProcessingPayment = false;
  bool _isSubmittingRating = false;
  bool _paymentCompleted = false;
  bool _ratingSubmitted = false;

  double get _ridePrice => (widget.rideDetails['estimated_price'] ?? 0).toDouble();
  double get _distance => (widget.rideDetails['distance_km'] ?? 0).toDouble();
  int get _duration => (widget.rideDetails['duration_minutes'] ?? 0) as int;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Traite le paiement
  Future<void> _processPayment() async {
    if (_isProcessingPayment) return;
    
    setState(() => _isProcessingPayment = true);

    try {
      final paymentService = StripePaymentService(_supabase);

      if (_selectedMethod == PaymentMethod.card) {
        // Paiement par carte via Stripe
        final amountCents = StripePaymentService.calculateTotalAmount(
          ridePriceMad: _ridePrice,
        );

        final currentUri = Uri.base;
        final baseUrl = '${currentUri.scheme}://${currentUri.host}:${currentUri.port}';

        final checkoutUrl = await paymentService.createCheckoutSession(
          amount: amountCents,
          successUrl: '$baseUrl/#/payment-success?ride_id=${widget.rideId}',
          cancelUrl: '$baseUrl/#/payment-cancel?ride_id=${widget.rideId}',
          rideId: widget.rideId,
        );

        // Ouvrir Stripe Checkout dans le navigateur
        debugPrint('🔗 Checkout URL: $checkoutUrl');
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Impossible d\'ouvrir le lien de paiement');
        }
        
        // Enregistrer le paiement comme pending
        await paymentService.recordPayment(
          rideId: widget.rideId,
          amountCents: amountCents,
          paymentMethod: 'card',
          status: 'pending',
        );

      } else {
        // Paiement en espèces
        final amountCents = (_ridePrice * 100).round();
        
        await paymentService.recordPayment(
          rideId: widget.rideId,
          amountCents: amountCents,
          paymentMethod: 'cash',
          status: 'completed', // Cash = complété immédiatement
        );
      }

      setState(() => _paymentCompleted = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedMethod == PaymentMethod.cash 
                ? '✅ Paiement en espèces confirmé'
                : '✅ Redirection vers le paiement...'
            ),
            backgroundColor: AppColors.green,
          ),
        );
      }

    } catch (e) {
      debugPrint('❌ Erreur paiement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  /// Soumet l'évaluation
  Future<void> _submitRating() async {
    if (_rating == 0 || _isSubmittingRating) return;

    setState(() => _isSubmittingRating = true);

    try {
      await RatingService.submitRating(
        rideId: widget.rideId,
        rating: _rating.toDouble(),
        comment: _commentController.text.trim(),
        raterRole: widget.isDriver ? 'driver' : 'patient',
      );

      setState(() => _ratingSubmitted = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Merci pour votre évaluation !'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      debugPrint('❌ Erreur évaluation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
      }
    }
  }

  /// Termine et retourne au dashboard
  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Course terminée'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header de succès
            _buildSuccessHeader(),
            const SizedBox(height: 24),

            // Récapitulatif de la course
            _buildRideSummary(),
            const SizedBox(height: 24),

            // Section paiement (pour Patient uniquement)
            if (!widget.isDriver) ...[
              _buildPaymentSection(),
              const SizedBox(height: 24),
            ],

            // Section évaluation
            _buildRatingSection(),
            const SizedBox(height: 32),

            // Bouton terminer - Actif après paiement (évaluation optionnelle)
            ElevatedButton(
              onPressed: (_paymentCompleted || widget.isDriver)
                  ? _finish
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                _paymentCompleted || widget.isDriver 
                    ? 'Terminer' 
                    : 'Veuillez d\'abord confirmer le paiement',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 50,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Course terminée !',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isDriver 
              ? 'Merci d\'avoir conduit ce patient'
              : 'Merci d\'avoir utilisé YALLA L\'TBIB',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Récapitulatif',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            icon: Icons.route,
            label: 'Distance',
            value: '${_distance.toStringAsFixed(1)} km',
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            icon: Icons.timer,
            label: 'Durée',
            value: '$_duration min',
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            icon: Icons.payments,
            label: 'Prix',
            value: '${_ridePrice.toStringAsFixed(2)} MAD',
            valueColor: AppColors.primary,
            valueBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: valueBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    if (_paymentCompleted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.green),
            const SizedBox(width: 12),
            const Text(
              'Paiement confirmé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mode de paiement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Options de paiement
          ...PaymentMethod.values.map((method) => _buildPaymentOption(method)),
          
          const SizedBox(height: 20),
          
          // Bouton payer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _selectedMethod == PaymentMethod.cash
                          ? 'Confirmer paiement espèces'
                          : 'Payer ${_ridePrice.toStringAsFixed(2)} MAD',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(PaymentMethod method) {
    final isSelected = _selectedMethod == method;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(method.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Text(
              method.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    if (_ratingSubmitted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green),
        ),
        child: Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 12),
            Text(
              'Évaluation soumise ($_rating/5)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isDriver ? 'Évaluez le patient' : 'Évaluez votre chauffeur',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Étoiles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => _rating = index + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _getRatingLabel(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Commentaire
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ajouter un commentaire (optionnel)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          
          // Bouton soumettre
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating > 0 && !_isSubmittingRating
                  ? _submitRating
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSubmittingRating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Soumettre l\'évaluation',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingLabel() {
    switch (_rating) {
      case 1: return 'Très mauvais 😠';
      case 2: return 'Mauvais 😕';
      case 3: return 'Correct 😐';
      case 4: return 'Bien 😊';
      case 5: return 'Excellent ! 🤩';
      default: return 'Appuyez sur les étoiles';
    }
  }
}
