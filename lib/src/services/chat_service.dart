import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de gestion du chat en temps réel
class ChatService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final Map<String, StreamSubscription> _subscriptions = {};

  /// Envoie un message dans une conversation de course
  static Future<Map<String, dynamic>?> sendMessage({
    required String rideId,
    required String senderId,
    required String message,
  }) async {
    try {
      debugPrint('💬 Envoi message - Course: $rideId');
      
      final response = await _client.from('chat_messages').insert({
        'ride_id': rideId,
        'sender_id': senderId,
        'message': message,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      debugPrint('✅ Message envoyé');
      return response;
    } catch (e) {
      debugPrint('❌ Erreur envoi message: $e');
      return null;
    }
  }

  /// Récupère l'historique des messages d'une course
  static Future<List<Map<String, dynamic>>> getMessages(String rideId) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('ride_id', rideId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Erreur récupération messages: $e');
      return [];
    }
  }

  /// S'abonne aux nouveaux messages d'une course (temps réel)
  static Stream<List<Map<String, dynamic>>> subscribeToMessages(String rideId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('ride_id', rideId)
        .order('created_at', ascending: true);
  }

  /// Marque tous les messages comme lus
  static Future<void> markMessagesAsRead({
    required String rideId,
    required String currentUserId,
  }) async {
    try {
      await _client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('ride_id', rideId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);

      debugPrint('✅ Messages marqués comme lus');
    } catch (e) {
      debugPrint('⚠️ Erreur marquage messages: $e');
    }
  }

  /// Compte les messages non lus pour une course
  static Future<int> getUnreadCount({
    required String rideId,
    required String currentUserId,
  }) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select('id')
          .eq('ride_id', rideId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Erreur comptage non lus: $e');
      return 0;
    }
  }

  /// Récupère le dernier message d'une course
  static Future<Map<String, dynamic>?> getLastMessage(String rideId) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('ride_id', rideId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Erreur récupération dernier message: $e');
      return null;
    }
  }

  /// Supprime tous les messages d'une course (utilisé à la fin)
  static Future<void> deleteMessages(String rideId) async {
    try {
      await _client
          .from('chat_messages')
          .delete()
          .eq('ride_id', rideId);

      debugPrint('✅ Messages supprimés pour course: $rideId');
    } catch (e) {
      debugPrint('❌ Erreur suppression messages: $e');
    }
  }

  /// Annule toutes les souscriptions actives
  static void cancelAllSubscriptions() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    debugPrint('✅ Toutes les souscriptions chat annulées');
  }

  /// Récupère les informations de l'autre utilisateur dans la conversation
  static Future<Map<String, dynamic>?> getChatPartnerInfo({
    required String rideId,
    required String currentUserId,
  }) async {
    try {
      // Récupérer la course avec les infos patient et chauffeur
      final ride = await _client
          .from('rides')
          .select('''
            patient_id,
            driver_id,
            patients!inner(id, user_id, full_name, phone),
            drivers!inner(id, user_id, full_name, phone, vehicle_model, license_plate)
          ''')
          .eq('id', rideId)
          .maybeSingle();

      if (ride == null) return null;

      // Déterminer si l'utilisateur actuel est le patient ou le chauffeur
      final patientUserId = ride['patients']?['user_id'];
      final driverUserId = ride['drivers']?['user_id'];

      if (currentUserId == patientUserId) {
        // L'utilisateur est le patient, retourner les infos du chauffeur
        return {
          'name': ride['drivers']?['full_name'] ?? 'Chauffeur',
          'phone': ride['drivers']?['phone'],
          'vehicle': ride['drivers']?['vehicle_model'],
          'plate': ride['drivers']?['license_plate'],
          'isDriver': false,
        };
      } else if (currentUserId == driverUserId) {
        // L'utilisateur est le chauffeur, retourner les infos du patient
        return {
          'name': ride['patients']?['full_name'] ?? 'Patient',
          'phone': ride['patients']?['phone'],
          'isDriver': true,
        };
      }

      return null;
    } catch (e) {
      debugPrint('❌ Erreur récupération partenaire: $e');
      return null;
    }
  }

  /// Vérifie si le chat est disponible pour une course
  /// (seulement si la course est en cours)
  static Future<bool> isChatAvailable(String rideId) async {
    try {
      final ride = await _client
          .from('rides')
          .select('status, driver_id')
          .eq('id', rideId)
          .maybeSingle();

      if (ride == null) return false;

      // Chat disponible seulement si un chauffeur est assigné 
      // et la course n'est pas terminée/annulée
      final status = ride['status'] as String?;
      final hasDriver = ride['driver_id'] != null;

      final activeStatuses = ['accepted', 'en_route', 'arrived', 'in_progress'];
      return hasDriver && activeStatuses.contains(status);
    } catch (e) {
      debugPrint('❌ Erreur vérification chat: $e');
      return false;
    }
  }
}

/// Classe pour représenter un message
class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      rideId: json['ride_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_id': rideId,
      'sender_id': senderId,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
