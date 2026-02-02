import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Service pour gérer les propositions de courses (ride_proposals)
/// Utilisé par les chauffeurs pour accepter/refuser les courses proposées
class RideProposalService {
  
  /// Récupère les propositions en attente pour un chauffeur
  /// Filtre uniquement status='pending' et non expirées
  static Future<List<Map<String, dynamic>>> getPendingProposals({
    required String driverId,
  }) async {
    try {
      debugPrint('📋 Récupération propositions pending pour driver: $driverId');
      
      final response = await DatabaseService.client
          .from('ride_proposals')
          .select('''
            *,
            rides:ride_id (
              id,
              pickup_location,
              pickup_address,
              dropoff_location,
              dropoff_address,
              ride_type,
              estimated_price,
              status,
              created_at,
              patients:patient_id (
                full_name,
                phone
              )
            )
          ''')
          .eq('driver_id', driverId)
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      debugPrint('✅ ${response.length} propositions pending récupérées');
      return List<Map<String, dynamic>>.from(response);
      
    } catch (e) {
      debugPrint('❌ Erreur récupération propositions: $e');
      return [];
    }
  }

  /// Stream en temps réel des propositions pour un chauffeur
  /// Met à jour automatiquement quand une nouvelle proposition arrive
  static Stream<List<Map<String, dynamic>>> watchProposals({
    required String driverId,
  }) {
    debugPrint('👀 Watching proposals pour driver: $driverId');
    
    return DatabaseService.client
        .from('ride_proposals')
        .stream(primaryKey: ['id'])
        .map((data) {
          // Filtrer côté client
          final filtered = data.where((proposal) => 
            proposal['driver_id'] == driverId && 
            proposal['status'] == 'pending'
          ).toList();
          
          debugPrint('🔄 Stream update: ${filtered.length} propositions pending');
          return filtered;
        });
  }

  /// Accepter une proposition de course
  /// Appelle la fonction PostgreSQL accept_ride_proposal
  static Future<Map<String, dynamic>> acceptProposal({
    required String proposalId,
  }) async {
    try {
      debugPrint('✅ Acceptation proposition: $proposalId');
      
      final response = await DatabaseService.client
          .rpc('accept_ride_proposal', params: {
        'proposal_id': proposalId,
      });

      if (response['success'] == true) {
        debugPrint('🎉 Proposition acceptée avec succès');
        debugPrint('   Ride ID: ${response['rideId']}');
        debugPrint('   Driver ID: ${response['driverId']}');
        
        return {
          'success': true,
          'rideId': response['rideId'],
          'driverId': response['driverId'],
        };
      } else {
        debugPrint('❌ Échec acceptation: ${response['error']}');
        return {
          'success': false,
          'error': response['error'] ?? 'Unknown error',
        };
      }
      
    } catch (e) {
      debugPrint('❌ Erreur acceptation proposition: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Refuser une proposition de course
  /// Appelle la fonction PostgreSQL reject_ride_proposal
  static Future<Map<String, dynamic>> rejectProposal({
    required String proposalId,
  }) async {
    try {
      debugPrint('❌ Refus proposition: $proposalId');
      
      final response = await DatabaseService.client
          .rpc('reject_ride_proposal', params: {
        'proposal_id': proposalId,
      });

      if (response['success'] == true) {
        debugPrint('✅ Proposition refusée avec succès');
        return {'success': true};
      } else {
        debugPrint('❌ Échec refus: ${response['error']}');
        return {
          'success': false,
          'error': response['error'] ?? 'Unknown error',
        };
      }
      
    } catch (e) {
      debugPrint('❌ Erreur refus proposition: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Calculer le temps restant avant expiration (en secondes)
  static int getTimeRemaining(String expiresAt) {
    try {
      final expiry = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final diff = expiry.difference(now);
      return diff.inSeconds > 0 ? diff.inSeconds : 0;
    } catch (e) {
      debugPrint('❌ Erreur calcul temps restant: $e');
      return 0;
    }
  }

  /// Formater le temps restant en format MM:SS
  static String formatTimeRemaining(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Vérifier si une proposition est expirée
  static bool isExpired(String expiresAt) {
    try {
      final expiry = DateTime.parse(expiresAt);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      return true;
    }
  }
}
