import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_service.dart';

/// Service de gestion des notifications push et locales
class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;

  /// Initialise le service de notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    print('🔔 Initialisation du service de notifications...');

    try {
      // 1. Demander les permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Permissions notifications accordées');
      } else {
        print('⚠️ Permissions notifications refusées');
        return;
      }

      // 2. Configuration des notifications locales
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // 3. Obtenir le token FCM
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 FCM Token: $token');
        await _saveFCMToken(token);
      }

      // 4. Gérer le rafraîchissement du token
      _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

      // 5. Écouter les messages en foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 6. Gérer les notifications en background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // 7. Vérifier si l'app a été ouverte depuis une notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

      _initialized = true;
      print('✅ Service de notifications initialisé');
    } catch (e) {
      print('❌ Erreur initialisation notifications: $e');
    }
  }

  /// Sauvegarde le token FCM dans Supabase
  static Future<void> _saveFCMToken(String token) async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) return;

      // Utiliser upsert pour insérer ou mettre à jour
      await DatabaseService.client
          .from('user_fcm_tokens')
          .upsert({
            'user_id': userId,
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      print('✅ FCM Token sauvegardé');
    } catch (e) {
      print('❌ Erreur sauvegarde FCM token: $e');
    }
  }

  /// Gère les messages reçus en foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 Notification reçue en foreground: ${message.messageId}');
    
    // Afficher une notification locale
    await _showLocalNotification(
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );

    // Sauvegarder dans la base de données
    await _saveNotificationToDatabase(message);
  }

  /// Gère les messages en background (quand app ouverte depuis notif)
  static void _handleBackgroundMessage(RemoteMessage message) {
    print('🔔 App ouverte depuis notification: ${message.messageId}');
    // TODO: Navigation vers l'écran approprié selon le type
  }

  /// Appelé quand l'utilisateur tape sur une notification locale
  static void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notification tappée: ${response.payload}');
    // TODO: Navigation
  }

  /// Affiche une notification locale
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'yalla_ltbib_channel',
      'YALLA L\'TBIB Notifications',
      channelDescription: 'Notifications pour les courses médicales',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Sauvegarde la notification dans Supabase
  static Future<void> _saveNotificationToDatabase(RemoteMessage message) async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) return;

      await DatabaseService.client.from('notifications').insert({
        'user_id': userId,
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
        'type': message.data['type'] ?? 'general',
        'data': message.data,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Notification sauvegardée en base');
    } catch (e) {
      print('❌ Erreur sauvegarde notification: $e');
    }
  }

  /// Envoie une notification push (via Supabase Edge Function)
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Appeler l'Edge Function pour envoyer le push FCM
      final response = await DatabaseService.client.functions.invoke(
        'send-notification',
        body: {
          'userId': userId,
          'title': title,
          'body': body,
          'type': type,
          'data': data ?? {},
        },
      );

      if (response.status == 200) {
        print('✅ Notification push envoyée avec succès à $userId');
      } else {
        print('⚠️ Erreur Edge Function: ${response.data}');
      }

      print('✅ Notification traitée pour utilisateur $userId');
    } catch (e) {
      print('❌ Erreur envoi notification: $e');
    }
  }

  /// Marque une notification comme lue
  static Future<void> markAsRead(String notificationId) async {
    try {
      await DatabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('❌ Erreur marquage notification lue: $e');
    }
  }

  /// Marque toutes les notifications comme lues
  static Future<void> markAllAsRead() async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) return;

      await DatabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('❌ Erreur marquage toutes notifications: $e');
    }
  }

  /// Récupère le nombre de notifications non lues
  static Future<int> getUnreadCount() async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) return 0;

      final response = await DatabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      print('❌ Erreur comptage notifications: $e');
      return 0;
    }
  }

  /// Récupère toutes les notifications de l'utilisateur
  static Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) return [];

      final response = await DatabaseService.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur récupération notifications: $e');
      return [];
    }
  }
}

/// Types de notifications
enum NotificationType {
  newRideRequest,    // Nouvelle demande de course
  rideAccepted,      // Course acceptée
  driverArrived,     // Chauffeur arrivé
  rideStarted,       // Course démarrée
  rideCompleted,     // Course terminée
  rideCancelled,     // Course annulée
  paymentReceived,   // Paiement reçu
  ratingReceived,    // Avis reçu
  system,            // Message système
}
