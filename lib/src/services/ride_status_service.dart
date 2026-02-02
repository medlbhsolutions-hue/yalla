import 'database_service.dart';
import 'notification_service.dart';

/// Service de gestion des statuts de course et transitions
/// Workflow: pending → accepted → driver_en_route → arrived → in_progress → completed
class RideStatusService {
  /// Statuts possibles d'une course
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusDriverEnRoute = 'driver_en_route';
  static const String statusArrived = 'arrived';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  
  /// Libellés des statuts pour l'affichage
  static String getStatusLabel(String status) {
    switch (status) {
      case statusPending:
        return 'En attente';
      case statusAccepted:
        return 'Acceptée';
      case statusDriverEnRoute:
        return 'Chauffeur en route';
      case statusArrived:
        return 'Chauffeur arrivé';
      case statusInProgress:
        return 'En cours';
      case statusCompleted:
        return 'Terminée';
      case statusCancelled:
        return 'Annulée';
      default:
        return 'Inconnu';
    }
  }
  
  /// Couleurs associées aux statuts
  static Map<String, dynamic> getStatusStyle(String status) {
    switch (status) {
      case statusPending:
        return {'color': 0xFFFFA726, 'icon': 0xe8b5}; // Orange, hourglass
      case statusAccepted:
        return {'color': 0xFF42A5F5, 'icon': 0xe5ca}; // Blue, check
      case statusDriverEnRoute:
        return {'color': 0xFF4CAF50, 'icon': 0xe531}; // Green, directions_car
      case statusArrived:
        return {'color': 0xFF66BB6A, 'icon': 0xe0c8}; // Light green, location_on
      case statusInProgress:
        return {'color': 0xFF29B6F6, 'icon': 0xe531}; // Cyan, directions_car
      case statusCompleted:
        return {'color': 0xFF66BB6A, 'icon': 0xe86c}; // Green, done_all
      case statusCancelled:
        return {'color': 0xFFEF5350, 'icon': 0xe5c9}; // Red, close
      default:
        return {'color': 0xFF9E9E9E, 'icon': 0xe88f}; // Grey, help
    }
  }
  
  /// Vérifie si la transition est valide
  static bool isValidTransition(String currentStatus, String newStatus) {
    // Map des transitions autorisées (assoupli pour UX simplifiée)
    final Map<String, List<String>> validTransitions = {
      statusPending: [statusAccepted, statusCancelled],
      statusAccepted: [statusDriverEnRoute, statusArrived, statusCancelled], // Permet d'aller directement à arrived
      statusDriverEnRoute: [statusArrived, statusCancelled],
      statusArrived: [statusInProgress, statusCancelled],
      statusInProgress: [statusCompleted, statusCancelled],
      statusCompleted: [], // État final
      statusCancelled: [], // État final
    };
    
    return validTransitions[currentStatus]?.contains(newStatus) ?? false;
  }
  
  /// Met à jour le statut d'une course
  static Future<bool> updateRideStatus({
    required String rideId,
    required String newStatus,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Récupérer la course actuelle
      final currentRide = await DatabaseService.client
          .from('rides')
          .select()
          .eq('id', rideId)
          .single();
      
      final currentStatus = currentRide['status'] as String;
      
      // Vérifier si la transition est valide
      if (!isValidTransition(currentStatus, newStatus)) {
        print('❌ Transition invalide: $currentStatus → $newStatus');
        return false;
      }
      
      // Préparer les données de mise à jour
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Ajouter des timestamps selon le statut
      switch (newStatus) {
        case statusAccepted:
          updateData['accepted_at'] = DateTime.now().toIso8601String();
          break;
        case statusArrived:
          updateData['arrived_at'] = DateTime.now().toIso8601String();
          break;
        case statusInProgress:
          updateData['started_at'] = DateTime.now().toIso8601String();
          updateData['pickup_time'] = DateTime.now().toIso8601String();
          break;
        case statusCompleted:
          updateData['completion_time'] = DateTime.now().toIso8601String();
          break;
        case statusCancelled:
          updateData['cancelled_at'] = DateTime.now().toIso8601String();
          break;
      }
      
      // Ajouter les données additionnelles (seulement les colonnes qui existent)
      // Ne pas ajouter additionalData car peut contenir des colonnes inexistantes
      
      // Mettre à jour dans la base de données
      await DatabaseService.client
          .from('rides')
          .update(updateData)
          .eq('id', rideId);
      
      print('✅ Statut mis à jour: $currentStatus → $newStatus');
      
      // Envoyer une notification au patient (optionnel)
      if (newStatus != statusCancelled) {
        await _notifyPatient(rideId, currentRide['patient_id'], newStatus);
      }
      
      return true;
      
    } catch (e) {
      print('❌ Erreur mise à jour statut: $e');
      return false;
    }
  }
  
  /// Notifie le patient d'un changement de statut
  static Future<void> _notifyPatient(String rideId, String patientId, String newStatus) async {
    try {
      // Récupérer le user_id du patient pour la notification push
      final patientData = await DatabaseService.client
          .from('patients')
          .select('user_id')
          .eq('id', patientId)
          .maybeSingle();
      
      final userId = patientData?['user_id'];
      if (userId == null) {
        print('⚠️ user_id non trouvé pour patient $patientId');
        return;
      }
      
      final title = _getStatusNotificationTitle(newStatus);
      final body = _getStatusNotificationMessage(newStatus);
      
      // Envoyer notification push via Edge Function
      await NotificationService.sendNotification(
        userId: userId,
        title: title,
        body: body,
        type: 'ride_status_update',
        data: {'ride_id': rideId, 'new_status': newStatus},
      );
      
      print('✅ Notification push envoyée au patient: $newStatus');
      
    } catch (e) {
      print('⚠️ Erreur envoi notification (non bloquant): $e');
    }
  }
  
  static String _getStatusNotificationTitle(String status) {
    switch (status) {
      case statusAccepted:
        return '🚗 Chauffeur trouvé !';
      case statusDriverEnRoute:
        return '🚗 En route vers vous';
      case statusArrived:
        return '📍 Chauffeur arrivé';
      case statusInProgress:
        return '🏥 Course en cours';
      case statusCompleted:
        return '✅ Course terminée';
      default:
        return '🔔 Mise à jour course';
    }
  }
  
  static String _getStatusNotificationMessage(String status) {
    switch (status) {
      case statusAccepted:
        return 'Un chauffeur a accepté votre course !';
      case statusDriverEnRoute:
        return 'Le chauffeur est en route vers vous';
      case statusArrived:
        return 'Le chauffeur est arrivé !';
      case statusInProgress:
        return 'Votre course a commencé';
      case statusCompleted:
        return 'Votre course est terminée';
      default:
        return 'Statut de votre course mis à jour';
    }
  }
  
  /// Obtient les actions possibles pour un chauffeur selon le statut
  static List<Map<String, dynamic>> getDriverActions(String currentStatus) {
    switch (currentStatus) {
      case statusAccepted:
        return [
          {
            'label': 'Je pars maintenant',
            'nextStatus': statusDriverEnRoute,
            'icon': 0xe531, // directions_car
            'color': 0xFF4CAF50,
          }
        ];
      case statusDriverEnRoute:
        return [
          {
            'label': 'Je suis arrivé',
            'nextStatus': statusArrived,
            'icon': 0xe0c8, // location_on
            'color': 0xFF4CAF50,
          }
        ];
      case statusArrived:
        return [
          {
            'label': 'Démarrer la course',
            'nextStatus': statusInProgress,
            'icon': 0xe037, // play_arrow
            'color': 0xFF4CAF50,
          }
        ];
      case statusInProgress:
        return [
          {
            'label': 'Terminer la course',
            'nextStatus': statusCompleted,
            'icon': 0xe5ca, // check_circle
            'color': 0xFF66BB6A,
          }
        ];
      default:
        return [];
    }
  }
  
  /// Annule une course
  static Future<bool> cancelRide({
    required String rideId,
    required String userId,
    required String reason,
  }) async {
    try {
      final success = await updateRideStatus(
        rideId: rideId,
        newStatus: statusCancelled,
        additionalData: {
          'cancelled_by': userId,
          'cancellation_reason': reason,
        },
      );
      
      if (success) {
        print('✅ Course annulée: $rideId');
      }
      
      return success;
      
    } catch (e) {
      print('❌ Erreur annulation course: $e');
      return false;
    }
  }
  
  /// Récupère l'historique des statuts d'une course
  static Future<List<Map<String, dynamic>>> getRideStatusHistory(String rideId) async {
    try {
      final ride = await DatabaseService.client
          .from('rides')
          .select()
          .eq('id', rideId)
          .single();
      
      final history = <Map<String, dynamic>>[];
      
      // Créé
      if (ride['created_at'] != null) {
        history.add({
          'status': statusPending,
          'timestamp': ride['created_at'],
          'label': 'Course créée',
        });
      }
      
      // Acceptée
      if (ride['accepted_at'] != null) {
        history.add({
          'status': statusAccepted,
          'timestamp': ride['accepted_at'],
          'label': 'Acceptée par le chauffeur',
        });
      }
      
      // En route
      if (ride['driver_en_route_at'] != null) {
        history.add({
          'status': statusDriverEnRoute,
          'timestamp': ride['driver_en_route_at'],
          'label': 'Chauffeur en route',
        });
      }
      
      // Arrivé
      if (ride['arrived_at'] != null) {
        history.add({
          'status': statusArrived,
          'timestamp': ride['arrived_at'],
          'label': 'Chauffeur arrivé',
        });
      }
      
      // Démarrée
      if (ride['started_at'] != null) {
        history.add({
          'status': statusInProgress,
          'timestamp': ride['started_at'],
          'label': 'Course démarrée',
        });
      }
      
      // Terminée
      if (ride['completed_at'] != null) {
        history.add({
          'status': statusCompleted,
          'timestamp': ride['completed_at'],
          'label': 'Course terminée',
        });
      }
      
      // Annulée
      if (ride['cancelled_at'] != null) {
        history.add({
          'status': statusCancelled,
          'timestamp': ride['cancelled_at'],
          'label': 'Course annulée',
        });
      }
      
      return history;
      
    } catch (e) {
      print('❌ Erreur récupération historique: $e');
      return [];
    }
  }
}
