import 'database_service.dart';
import 'notification_service.dart';

/// Service de gestion des avis et notations
class RatingService {
  /// Soumet un avis pour une course
  static Future<bool> submitRating({
    required String rideId,
    required double rating,
    required String raterRole, // 'patient' ou 'driver'
    String? comment,
  }) async {
    try {
      print('⭐ Soumission d\'un avis: $rating étoiles');

      // 1. Récupérer les informations de la course
      final ride = await DatabaseService.client
          .from('rides')
          .select('*, patient:patients(*), driver:drivers(*)')
          .eq('id', rideId)
          .single();

      // 2. Mettre à jour la course avec le rating
      Map<String, dynamic> updateData = {};
      String? recipientId;
      String notificationTitle = '';
      String notificationBody = '';

      if (raterRole == 'patient') {
        // Le patient note le chauffeur
        updateData = {
          'driver_rating': rating.round(), // Convertir en INTEGER
          'driver_comment': comment,
          'rated_at': DateTime.now().toIso8601String(),
        };
        recipientId = ride['driver']['user_id'];
        notificationTitle = '⭐ Nouvel avis reçu !';
        notificationBody = 'Vous avez reçu une note de ${rating.round()} étoiles';
      } else {
        // Le chauffeur note le patient
        updateData = {
          'patient_rating': rating.round(), // Convertir en INTEGER
          'patient_comment': comment,
          'rated_at': DateTime.now().toIso8601String(),
        };
        recipientId = ride['patient']['user_id'];
        notificationTitle = '⭐ Nouvel avis reçu !';
        notificationBody = 'Vous avez reçu une note de ${rating.round()} étoiles';
      }

      await DatabaseService.client
          .from('rides')
          .update(updateData)
          .eq('id', rideId);

      // 3. Mettre à jour la moyenne du profil
      await _updateAverageRating(
        raterRole == 'patient' ? ride['driver_id'] : ride['patient_id'],
        raterRole == 'patient' ? 'driver' : 'patient',
      );

      // 4. Envoyer une notification
      if (recipientId != null) {
        await NotificationService.sendNotification(
          userId: recipientId,
          title: notificationTitle,
          body: notificationBody,
          type: 'rating_received',
          data: {
            'ride_id': rideId,
            'rating': rating,
          },
        );
      }

      print('✅ Avis soumis avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur soumission avis: $e');
      return false;
    }
  }

  /// Met à jour la moyenne des ratings d'un utilisateur
  static Future<void> _updateAverageRating(String profileId, String role) async {
    try {
      final table = role == 'driver' ? 'drivers' : 'patients';
      final ratingField = role == 'driver' ? 'driver_rating' : 'patient_rating';

      // Récupérer toutes les courses notées
      final rides = await DatabaseService.client
          .from('rides')
          .select(ratingField)
          .eq(role == 'driver' ? 'driver_id' : 'patient_id', profileId)
          .not(ratingField, 'is', null);

      if (rides.isEmpty) return;

      // Calculer la moyenne
      double sum = 0;
      int count = 0;
      for (var ride in rides) {
        final rating = ride[ratingField];
        if (rating != null) {
          sum += (rating as num).toDouble();
          count++;
        }
      }

      final average = count > 0 ? sum / count : 0.0;

      // Mettre à jour le profil
      await DatabaseService.client
          .from(table)
          .update({
            'rating': average,
            'total_ratings': count,
          })
          .eq('id', profileId);

      print('✅ Moyenne rating mise à jour: $average ($count avis)');
    } catch (e) {
      print('❌ Erreur mise à jour moyenne: $e');
    }
  }

  /// Récupère les avis pour un utilisateur
  static Future<List<Map<String, dynamic>>> getRatings({
    required String profileId,
    required String role, // 'driver' ou 'patient'
    int limit = 20,
  }) async {
    try {
      final ratingField = role == 'driver' ? 'driver_rating' : 'patient_rating';
      final commentField = role == 'driver' ? 'driver_comment' : 'patient_comment';

      final rides = await DatabaseService.client
          .from('rides')
          .select('*, patient:patients(first_name, last_name), driver:drivers(first_name, last_name)')
          .eq(role == 'driver' ? 'driver_id' : 'patient_id', profileId)
          .not(ratingField, 'is', null)
          .order('rated_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(rides).map((ride) {
        return {
          'id': ride['id'],
          'rating': ride[ratingField],
          'comment': ride[commentField],
          'rated_at': ride['rated_at'],
          'rater_name': role == 'driver' 
              ? '${ride['patient']['first_name']} ${ride['patient']['last_name']}'
              : '${ride['driver']['first_name']} ${ride['driver']['last_name']}',
          'pickup_address': ride['pickup_address'],
          'dropoff_address': ride['dropoff_address'],
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération avis: $e');
      return [];
    }
  }

  /// Vérifie si une course peut être notée
  static Future<bool> canRateRide(String rideId, String role) async {
    try {
      final ratingField = role == 'patient' ? 'driver_rating' : 'patient_rating';
      
      final ride = await DatabaseService.client
          .from('rides')
          .select('status, $ratingField')
          .eq('id', rideId)
          .single();

      // La course doit être terminée et pas encore notée
      return ride['status'] == 'completed' && ride[ratingField] == null;
    } catch (e) {
      print('❌ Erreur vérification rating: $e');
      return false;
    }
  }

  /// Récupère les statistiques de rating d'un profil
  static Future<Map<String, dynamic>> getRatingStats({
    required String profileId,
    required String role,
  }) async {
    try {
      final table = role == 'driver' ? 'drivers' : 'patients';
      
      final profile = await DatabaseService.client
          .from(table)
          .select('rating, total_ratings')
          .eq('id', profileId)
          .single();

      // Récupérer la distribution des notes
      final ratingField = role == 'driver' ? 'driver_rating' : 'patient_rating';
      final rides = await DatabaseService.client
          .from('rides')
          .select(ratingField)
          .eq(role == 'driver' ? 'driver_id' : 'patient_id', profileId)
          .not(ratingField, 'is', null);

      // Compter par étoile
      Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var ride in rides) {
        final rating = (ride[ratingField] as num).round();
        distribution[rating] = (distribution[rating] ?? 0) + 1;
      }

      return {
        'average': profile['rating'] ?? 0.0,
        'total': profile['total_ratings'] ?? 0,
        'distribution': distribution,
      };
    } catch (e) {
      print('❌ Erreur statistiques rating: $e');
      return {
        'average': 0.0,
        'total': 0,
        'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }
  }
}
