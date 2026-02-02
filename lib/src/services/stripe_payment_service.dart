import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service pour les paiements Stripe
/// Gère les sessions de paiement via Edge Functions Supabase
class StripePaymentService {
  final SupabaseClient _client;

  StripePaymentService(this._client);

  /// Crée une session Stripe Checkout et retourne l'URL de paiement
  /// [amount] - Montant en centimes (ex: 2500 = 25.00 MAD)
  /// [successUrl] - URL de redirection après paiement réussi
  /// [cancelUrl] - URL de redirection si annulation
  Future<String> createCheckoutSession({
    required int amount,
    required String successUrl,
    required String cancelUrl,
    String? rideId,
    String? patientId,
    String? driverId,
  }) async {
    try {
      debugPrint('💳 Création session Stripe - Montant: $amount centimes');
      
      final response = await _client.functions.invoke(
        'create-checkout',
        body: {
          'amount': amount,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
          if (rideId != null) 'ride_id': rideId,
          if (patientId != null) 'patient_id': patientId,
          if (driverId != null) 'driver_id': driverId,
        },
      );

      if (response.data == null) {
        throw Exception('Réponse vide de l\'Edge Function');
      }

      final data = response.data as Map<String, dynamic>;
      
      if (data.containsKey('error')) {
        throw Exception(data['error']);
      }

      final checkoutUrl = data['url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('URL de checkout non reçue');
      }

      debugPrint('✅ Session Stripe créée: ${checkoutUrl.substring(0, 50)}...');
      return checkoutUrl;
      
    } catch (e) {
      debugPrint('❌ Erreur création session Stripe: $e');
      rethrow;
    }
  }

  /// Enregistre le paiement en base de données
  Future<void> recordPayment({
    required String rideId,
    required int amountCents,
    required String paymentMethod, // 'card', 'cash'
    required String status, // 'pending', 'completed', 'failed'
    String? stripeSessionId,
  }) async {
    try {
      debugPrint('💾 Enregistrement paiement - Course: $rideId');
      
      await _client.from('payments').insert({
        'ride_id': rideId,
        'amount': amountCents / 100, // Montant en MAD
        'amount_cents': amountCents,
        'amount_mad': amountCents / 100,
        'payment_method': paymentMethod,
        'status': status,
        'stripe_session_id': stripeSessionId,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Paiement enregistré');
    } catch (e) {
      debugPrint('❌ Erreur enregistrement paiement: $e');
      rethrow;
    }
  }

  /// Met à jour le statut du paiement
  Future<void> updatePaymentStatus({
    required String paymentId,
    required String status,
    String? stripePaymentIntentId,
  }) async {
    try {
      await _client.from('payments').update({
        'status': status,
        if (stripePaymentIntentId != null) 'stripe_payment_intent_id': stripePaymentIntentId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);

      debugPrint('✅ Statut paiement mis à jour: $status');
    } catch (e) {
      debugPrint('❌ Erreur mise à jour paiement: $e');
      rethrow;
    }
  }

  /// Récupère l'historique des paiements d'un utilisateur
  Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      final response = await _client
          .from('payments')
          .select('''
            *,
            rides(
              pickup_address,
              destination_address,
              created_at
            )
          ''')
          .or('patient_id.eq.$userId,driver_id.eq.$userId')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur récupération historique: $e');
      return [];
    }
  }

  /// Calcule le montant à payer (prix course + frais)
  static int calculateTotalAmount({
    required double ridePriceMad,
    double serviceFeePercent = 10.0, // 10% de frais de service
  }) {
    final serviceFee = ridePriceMad * (serviceFeePercent / 100);
    final total = ridePriceMad + serviceFee;
    // Convertir en centimes
    return (total * 100).round();
  }

  /// Vérifie si le paiement d'une course est complété
  Future<bool> isRidePaymentCompleted(String rideId) async {
    try {
      final response = await _client
          .from('payments')
          .select('status')
          .eq('ride_id', rideId)
          .eq('status', 'completed')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Erreur vérification paiement: $e');
      return false;
    }
  }
}

/// Types de méthodes de paiement
enum PaymentMethod {
  card('card', 'Carte bancaire', '💳'),
  cash('cash', 'Espèces', '💵');

  final String value;
  final String label;
  final String icon;

  const PaymentMethod(this.value, this.label, this.icon);
}

/// Statuts de paiement
enum PaymentStatus {
  pending('pending', 'En attente'),
  completed('completed', 'Complété'),
  failed('failed', 'Échoué'),
  refunded('refunded', 'Remboursé');

  final String value;
  final String label;

  const PaymentStatus(this.value, this.label);
}
