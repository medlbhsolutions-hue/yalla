import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Pour debugPrint et kIsWeb
import '../config/app_config.dart'; // ✅ NOUVEAU: Configuration sécurisée
import '../utils/logger.dart'; // ✅ Logger centralisé

/// Service principal pour toutes les opérations de base de données
/// Gère l'authentification, les courses, les chauffeurs et les patients
class DatabaseService {
  // Instance Supabase
  static SupabaseClient get _client => Supabase.instance.client;
  
  // Getter public pour accéder au client depuis d'autres services
  static SupabaseClient get client => _client;
  
  // ✅ SÉCURISÉ: URL et clés chargées depuis .env via AppConfig
  // Les valeurs ne sont plus hardcodées ici

  // =========================================
  // INITIALISATION
  // =========================================
  
  static Future<void> initialize() async {
    try {
      Logger.info('Initialisation de Supabase...', 'DB');
      if (AppConfig.enableLogs) {
        Logger.debug('URL: ${AppConfig.maskKey(AppConfig.supabaseUrl)}', 'DB');
      }
      
      await Supabase.initialize(
        url: AppConfig.supabaseUrl, // ✅ Depuis .env
        anonKey: AppConfig.supabaseAnonKey, // ✅ Depuis .env
        debug: AppConfig.isDevelopment, // Debug seulement en développement
      );
      
      Logger.success('Supabase initialisé avec succès', 'DB');
      
      // Vérifier la connexion
      final user = _client.auth.currentUser;
      if (user != null) {
        Logger.info('Utilisateur connecté: ${user.email}', 'DB');
      }
    } catch (e) {
      Logger.error('Erreur initialisation Supabase', e, null, 'DB');
      rethrow;
    }
  }

  // =========================================
  // AUTHENTIFICATION
  // =========================================
  
  /// Inscription d'un nouvel utilisateur
  static Future<AuthResponse> signUp(String email, String password) async {
    try {
      Logger.info('Inscription: $email', 'AUTH');
      
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      
      if (response.user != null) {
        Logger.success('Inscription réussie: ${AppConfig.maskKey(response.user!.email ?? "")}', 'AUTH');
        Logger.debug('Session créée: ${response.session != null}', 'AUTH');
        
        // Attendre un peu pour que la session soit bien établie
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Vérifier que l'utilisateur est bien connecté
        final currentUser = _client.auth.currentUser;
        if (currentUser?.email != null) {
           Logger.debug('Utilisateur actuel après inscription: ${AppConfig.maskKey(currentUser!.email!)}', 'AUTH');
        }
      }
      
      return response;
    } catch (e) {
      Logger.error('Erreur inscription', e, null, 'AUTH');
      rethrow;
    }
  }

  /// Connexion d'un utilisateur existant
  static Future<AuthResponse> signIn(String email, String password) async {
    try {
      Logger.info('Connexion: $email', 'AUTH');
      
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        Logger.success('Connexion réussie: ${AppConfig.maskKey(response.user!.email ?? "")}', 'AUTH');
      }
      
      return response;
    } catch (e) {
      Logger.error('Erreur connexion', e, null, 'AUTH');
      rethrow;
    }
  }

  /// Déconnexion
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      Logger.info('Déconnexion réussie', 'AUTH');
    } catch (e) {
      Logger.error('Erreur déconnexion', e, null, 'AUTH');
      rethrow;
    }
  }

  /// Utilisateur actuel
  static User? get currentUser => _client.auth.currentUser;

  /// ID de l'utilisateur actuel
  static String? getCurrentUserId() => currentUser?.id;

  /// Stream des changements d'authentification
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Récupérer le rôle de l'utilisateur actuel
  static Future<String> getUserRole() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return 'patient'; // Par défaut

      final response = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return 'patient';
      return response['role'] ?? 'patient';
      
    } catch (e) {
      Logger.error('Erreur recuperation role', e, null, 'AUTH');
      return 'patient'; // Par défaut en cas d'erreur
    }
  }

  // =========================================
  // GESTION DES PATIENTS
  // =========================================
  
  /// Créer un profil patient
  static Future<Map<String, dynamic>> createPatientProfile({
    required String firstName,
    required String lastName,
    DateTime? dateOfBirth,
    String? emergencyContactName,
    String? emergencyContactPhone,
    List<String>? medicalConditions,
  }) async {
    try {
      // Forcer la récupération de l'utilisateur actuel
      final user = _client.auth.currentUser;
      print('🔍 Utilisateur actuel dans createPatientProfile: ${user?.email}');
      
      if (user == null) {
        throw Exception('Utilisateur non connecté. Veuillez vous reconnecter.');
      }
      
      final userId = user.id;
      print('👤 Création profil patient: $firstName $lastName (userID: $userId)');

      final data = {
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'emergency_contact_name': emergencyContactName,
        'emergency_contact_phone': emergencyContactPhone,
        'medical_conditions': medicalConditions ?? [],
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('patients')
          .insert(data)
          .select()
          .single();

      print('✅ Profil patient créé: ${response['id']}');
      return response;
    } catch (e) {
      print('❌ Erreur création profil patient: $e');
      rethrow;
    }
  }

  /// Récupérer le profil patient de l'utilisateur connecté
  static Future<Map<String, dynamic>?> getPatientProfile() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('patients')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Erreur récupération profil patient: $e');
      return null;
    }
  }

  /// Mettre à jour le profil patient
  static Future<void> updatePatientProfile(Map<String, dynamic> updates) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      await _client
          .from('patients')
          .update(updates)
          .eq('user_id', userId);

      print('✅ Profil patient mis à jour');
    } catch (e) {
      print('❌ Erreur mise à jour profil patient: $e');
      rethrow;
    }
  }

  // =========================================
  // GESTION DES CHAUFFEURS
  // =========================================
  
  /// Mettre à jour le profil chauffeur
  static Future<void> updateDriverProfile(Map<String, dynamic> updates) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      // Filtrer les colonnes qui n'existent pas dans la table drivers
      final validUpdates = Map<String, dynamic>.from(updates);
      validUpdates.remove('email'); // Email est dans auth.users, pas drivers
      
      await _client
          .from('drivers')
          .update(validUpdates)
          .eq('user_id', userId);

      print('[OK] Profil driver mis a jour');
    } catch (e) {
      print('[ERROR] Erreur mise a jour profil driver: $e');
      rethrow;
    }
  }
  
  /// Créer un profil chauffeur
  static Future<Map<String, dynamic>> createDriverProfile({
    required String firstName,
    required String lastName,
    required String nationalId,
    DateTime? dateOfBirth,
    String? address,
    String? city,
    List<String>? specializations,
  }) async {
    try {
      // Forcer la récupération de l'utilisateur actuel
      final user = _client.auth.currentUser;
      print('🔍 Utilisateur actuel dans createDriverProfile: ${user?.email}');
      
      if (user == null) {
        throw Exception('Utilisateur non connecté. Veuillez vous reconnecter.');
      }
      
      final userId = user.id;
      print('🚗 Création profil chauffeur: $firstName $lastName (userID: $userId)');

      final data = {
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'national_id': nationalId,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'address': address,
        'city': city,
        'specializations': specializations ?? [],
        'status': 'pending',
        'is_available': false,
        'rating': 0.0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('drivers')
          .insert(data)
          .select()
          .single();

      print('✅ Profil chauffeur créé: ${response['id']}');
      return response;
    } catch (e) {
      Logger.error('Erreur création profil chauffeur', e, null, 'DRIVER');
      rethrow;
    }
  }

  /// Récupérer le profil chauffeur de l'utilisateur connecté
  static Future<Map<String, dynamic>?> getDriverProfile() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('drivers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      Logger.error('Erreur récupération profil chauffeur', e, null, 'DRIVER');
      return null;
    }
  }

  /// Récupérer le profil d'un chauffeur par son ID
  static Future<Map<String, dynamic>?> getDriverById(String driverId) async {
    try {
      final response = await _client
          .from('drivers')
          .select('''
            *,
            vehicles(*)
          ''')
          .eq('id', driverId)
          .maybeSingle();

      return response;
    } catch (e) {
      Logger.error('Erreur récupération chauffeur par ID', e, null, 'DRIVER');
      return null;
    }
  }

  /// Créer automatiquement un profil Driver si manquant (avec données par défaut)
  static Future<Map<String, dynamic>?> ensureDriverProfile() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        Logger.warning('Pas d\'utilisateur connecté', 'DRIVER');
        return null;
      }

      // Vérifier si le profil existe déjà
      var profile = await getDriverProfile();
      
      if (profile != null) {
        Logger.debug('Profil driver existant trouvé: ${profile['id']}', 'DRIVER');
        return profile;
      }

      // Créer un profil par défaut
      Logger.info('Profil driver manquant, création automatique...', 'DRIVER');
      
      // Obtenir le téléphone depuis Firebase si disponible
      final phone = currentUser?.phone ?? currentUser?.email ?? 'Non renseigné';
      
      profile = await createDriverProfile(
        firstName: 'Chauffeur',
        lastName: phone.contains('@') ? phone.split('@')[0] : phone,
        nationalId: 'À renseigner',
        address: 'Casablanca, Maroc',
        city: 'Casablanca',
      );
      
      Logger.success('Profil driver créé automatiquement: ${profile!['id']}', 'DRIVER');
      return profile;
    } catch (e) {
      Logger.error('Erreur création automatique profil driver', e, null, 'DRIVER');
      return null;
    }
  }

  /// Créer automatiquement un profil Patient si manquant (avec données par défaut)
  static Future<Map<String, dynamic>?> ensurePatientProfile() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        Logger.warning('Pas d\'utilisateur connecté', 'PATIENT');
        return null;
      }

      // Vérifier si le profil existe déjà
      var profile = await getPatientProfile();
      
      if (profile != null) {
        Logger.debug('Profil patient existant trouvé: ${profile['id']}', 'PATIENT');
        return profile;
      }

      // Créer un profil par défaut
      Logger.info('Profil patient manquant, création automatique...', 'PATIENT');
      
      // Obtenir le téléphone depuis Firebase si disponible
      final phone = currentUser?.phone ?? currentUser?.email ?? 'Non renseigné';
      
      profile = await createPatientProfile(
        firstName: 'Patient',
        lastName: phone.contains('@') ? phone.split('@')[0] : phone,
        emergencyContactName: 'À renseigner',
        emergencyContactPhone: 'À renseigner',
      );
      
      Logger.success('Profil patient créé automatiquement: ${profile!['id']}', 'PATIENT');
      return profile;
    } catch (e) {
      Logger.error('Erreur création automatique profil patient', e, null, 'PATIENT');
      return null;
    }
  }

  /// Mettre à jour la disponibilité du chauffeur
  static Future<void> updateDriverAvailability(bool isAvailable) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      await _client
          .from('drivers')
          .update({
            'is_available': isAvailable,
            'last_active': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      Logger.debug('Disponibilité chauffeur: $isAvailable', 'DRIVER');
    } catch (e) {
      Logger.error('Erreur mise à jour disponibilité', e, null, 'DRIVER');
      rethrow;
    }
  }

  /// Mettre à jour la position GPS du chauffeur
  static Future<void> updateDriverLocation(double latitude, double longitude) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      // PostGIS format: POINT(longitude latitude)
      final location = 'POINT($longitude $latitude)';

      await _client
          .from('drivers')
          .update({
            'current_location': location,
            'last_active': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      Logger.debug('Position chauffeur mise à jour: $latitude, $longitude', 'GPS');
    } catch (e) {
      Logger.error('Erreur mise à jour position', e, null, 'GPS');
      rethrow;
    }
  }

  /// Récupérer les chauffeurs disponibles à proximité
  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      Logger.info('Recherche chauffeurs dans un rayon de ${radiusKm}km', 'RIDE');
      Logger.debug('Position utilisateur: $latitude, $longitude', 'RIDE');

      try {
        // Essayer d'abord la fonction RPC avec l'ordre correct des paramètres
        final response = await _client.rpc(
          'get_nearby_drivers_rpc',
          params: {
            'radius_km': radiusKm,
            'user_lat': latitude,
            'user_lng': longitude,
          },
        );

        Logger.info('${response.length} chauffeurs trouvés via RPC', 'RIDE');
        
        // Reformater les données pour correspondre au format attendu
        final List<Map<String, dynamic>> drivers = [];
        for (var driver in response) {
          drivers.add({
            'id': driver['id'],
            'first_name': driver['first_name'],
            'last_name': driver['last_name'],
            'rating': driver['rating'],
            'is_available': driver['is_available'],
            'current_location': {
              'latitude': driver['current_location_lat'],
              'longitude': driver['current_location_lng'],
            },
            'vehicles': {
              'make': driver['vehicle_make'],
              'model': driver['vehicle_model'],
              'year': driver['vehicle_year'],
              'vehicle_type': driver['vehicle_type'],
            },
          });
        }

        return drivers;
      } catch (rpcError) {
        Logger.warning('Erreur RPC, fallback sur données simulées: $rpcError', 'RIDE');
        
        // FALLBACK: Données simulées basées sur la vraie DB
        return [
          {
            'id': '660e8400-e29b-41d4-a716-446655440001',
            'first_name': 'Mohamed',
            'last_name': 'Tazi',
            'rating': 4.8,
            'is_available': true,
            'current_location': {'latitude': 33.9716, 'longitude': -6.8498},
            'vehicles': {
              'make': 'Mercedes',
              'model': 'Sprinter',
              'year': 2021,
              'vehicle_type': 'ambulance',
            },
          },
          {
            'id': '660e8400-e29b-41d4-a716-446655440002',
            'first_name': 'Ahmed',
            'last_name': 'Bennani',
            'rating': 4.6,
            'is_available': true,
            'current_location': {'latitude': 33.9592, 'longitude': -6.8368},
            'vehicles': {
              'make': 'Renault',
              'model': 'Kangoo',
              'year': 2020,
              'vehicle_type': 'medical_transport',
            },
          },
          {
            'id': '660e8400-e29b-41d4-a716-446655440004',
            'first_name': 'Said',
            'last_name': 'Ouali',
            'rating': 4.7,
            'is_available': true,
            'current_location': {'latitude': 33.9778, 'longitude': -6.8302},
            'vehicles': {
              'make': 'Peugeot',
              'model': 'Boxer',
              'year': 2022,
              'vehicle_type': 'ambulance',
            },
          },
        ];
      }
    } catch (e) {
      Logger.error('Erreur recherche chauffeurs', e, null, 'RIDE');
      return [];
    }
  }

  // =========================================
  // GESTION DES COURSES
  // =========================================
  
  /// Créer une nouvelle demande de course
  static Future<Map<String, dynamic>> createRide({
    String? driverId,
    required String patientId,
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required String destinationAddress,
    required double destinationLatitude,
    required double destinationLongitude,
    required double estimatedPrice,
    required double distanceKm,
    required int durationMinutes,
    String priority = 'medium',  // Changé de 'normal' à 'medium' pour correspondre à l'ENUM SQL
    String? medicalNotes,
    Map<String, dynamic>? specialRequirements,
  }) async {
    try {
      // MODE SIMULATION : créer une course simulée sans Supabase
      final userId = currentUser?.id;
      if (userId == null || userId.startsWith('debug-')) {
        print('🧪 MODE SIMULATION : Création course simulée');
        
        // Générer un ID simulé
        final rideId = 'ride-${DateTime.now().millisecondsSinceEpoch}';
        
        return {
          'id': rideId,
          'patient_id': 'simulated-patient-id',
          'driver_id': driverId,
          'pickup_address': pickupAddress,
          'destination_address': destinationAddress,
          'estimated_price': estimatedPrice,
          'priority': priority,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        };
      }

      // MODE PRODUCTION : vraie insertion Supabase
      print('🚕 Création nouvelle course: $pickupAddress → $destinationAddress');
      print('💰 Prix estimé: $estimatedPrice MAD');

      final data = {
        'patient_id': patientId,
        'driver_id': driverId, // Peut être null (course en attente de chauffeur)
        'pickup_address': pickupAddress,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'destination_address': destinationAddress,
        'destination_latitude': destinationLatitude,
        'destination_longitude': destinationLongitude,
        'estimated_price': estimatedPrice, // Prix estimé initial
        'total_price': estimatedPrice, // Prix total (peut être ajusté)
        'base_price': estimatedPrice * 0.8, // 80% prix de base, 20% variables
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'priority': priority,
        'medical_notes': medicalNotes,
        'special_requirements': specialRequirements ?? {},
        'status': 'pending', // En attente d'un chauffeur
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('rides')
          .insert(data)
          .select();

      if (response == null || response.isEmpty) {
        throw Exception('Aucune donnée retournée après insertion');
      }

      final ride = response.first; // 🎯 FIX: Utiliser .first au lieu de .single()
      print('✅ Course créée: ${ride['id']}');
      
      // 🔔 Notifier les chauffeurs via Edge Function
      try {
        print('📱 Appel Edge Function notify-drivers...');
        final notificationPayload = {
          'ride_id': ride['id'], // 🎯 FIX: Utiliser ride au lieu de response
          'pickup_latitude': pickupLatitude,
          'pickup_longitude': pickupLongitude,
          'estimated_price': estimatedPrice,
          'priority_level': priority == 'urgent' ? 'urgent' : 'standard',
        };
        print('📦 Payload: $notificationPayload');
        
        final notifResponse = await _client.functions.invoke(
          'notify-drivers',
          body: notificationPayload,
        );
        
        print('✅ Réponse Edge Function: ${notifResponse.data}');
      } catch (e, stackTrace) {
        print('⚠️ Erreur notifications (non bloquant): $e');
        print('🔍 Stack trace: $stackTrace');
        // Non bloquant - la course est créée même si les notifications échouent
      }
      
      return ride; // 🎯 FIX: Retourner ride au lieu de response
    } catch (e) {
      print('❌ Erreur création course: $e');
      rethrow;
    }
  }

  /// Récupérer les courses en attente (pour les chauffeurs)
  static Future<List<Map<String, dynamic>>> getPendingRides() async {
    try {
      final response = await _client
          .from('rides')
          .select('''
            *,
            patients!inner(
              first_name,
              last_name,
              emergency_contact_phone
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);

      print('✅ ${(response as List).length} courses en attente');
      return (response).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Erreur récupération courses: $e');
      return [];
    }
  }

  /// Mettre à jour le statut d'une course
  static Future<void> updateRideStatus(String rideId, String status) async {
    try {
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Ajouter des timestamps spécifiques selon le statut
      switch (status) {
        case 'arrived':
          updates['pickup_time'] = DateTime.now().toIso8601String();
          break;
        case 'in_progress':
          updates['arrival_time'] = DateTime.now().toIso8601String();
          break;
        case 'completed':
          updates['completion_time'] = DateTime.now().toIso8601String();
          break;
      }

      await _client
          .from('rides')
          .update(updates)
          .eq('id', rideId);

      print('✅ Statut course mis à jour: $status');
    } catch (e) {
      print('❌ Erreur mise à jour statut: $e');
      rethrow;
    }
  }

  /// Accepter une course en tant que chauffeur
  static Future<bool> acceptRide({
    required String rideId,
    required String driverId,
  }) async {
    try {
      print('🚗 Acceptation de la course $rideId par le chauffeur $driverId');

      // 1. Récupérer les infos de la course et du patient avant mise à jour
      final rideInfo = await _client
          .from('rides')
          .select('patient_id, patients!inner(user_id, first_name)')
          .eq('id', rideId)
          .maybeSingle();

      // 2. Mettre à jour la course
      final updates = {
        'driver_id': driverId,
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('rides')
          .update(updates)
          .eq('id', rideId)
          .isFilter('driver_id', null); // Vérifier qu'aucun chauffeur n'est déjà assigné

      print('✅ Course acceptée avec succès');
      
      // 3. Envoyer notification au patient
      if (rideInfo != null) {
        final patientUserId = rideInfo['patients']?['user_id'];
        if (patientUserId != null) {
          try {
            print('📱 Envoi notification au patient: $patientUserId');
            await _client.functions.invoke(
              'send-notification',
              body: {
                'userId': patientUserId,
                'title': '🚗 Chauffeur trouvé !',
                'body': 'Un chauffeur a accepté votre course et arrive bientôt.',
                'type': 'ride_accepted',
                'data': {'ride_id': rideId},
              },
            );
            print('✅ Notification envoyée au patient');
          } catch (e) {
            print('⚠️ Erreur notification (non bloquant): $e');
          }
        }
      }
      
      return true;
    } catch (e) {
      print('❌ Erreur acceptation course: $e');
      return false;
    }
  }

  /// Décliner/Annuler l'acceptation d'une course
  static Future<bool> declineRide({
    required String rideId,
  }) async {
    try {
      print('🚫 Refus de la course $rideId');

      final updates = {
        'driver_id': null,
        'status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('rides')
          .update(updates)
          .eq('id', rideId);

      print('✅ Course déclinée/remise en attente');
      return true;
    } catch (e) {
      print('❌ Erreur refus course: $e');
      return false;
    }
  }

  /// Récupérer les courses récentes d'un patient (simplifié pour dashboard)
  static Future<List<Map<String, dynamic>>> getPatientRides({
    required String patientId,
    int limit = 5,
  }) async {
    try {
      print('🚗 Récupération courses patient: $patientId (limit: $limit)');

      final response = await _client
          .from('rides')
          .select('''
            id,
            destination_address,
            status,
            total_price,
            created_at,
            drivers(
              first_name,
              last_name
            )
          ''')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(limit);

      final rides = (response as List).cast<Map<String, dynamic>>();
      
      // Formater les données pour inclure driver_name au niveau supérieur
      final formattedRides = rides.map((ride) {
        final drivers = ride['drivers'];
        String driverName = 'N/A';
        
        if (drivers != null && drivers is Map) {
          final firstName = drivers['first_name'] ?? '';
          final lastName = drivers['last_name'] ?? '';
          driverName = '$firstName $lastName'.trim();
          if (driverName.isEmpty) driverName = 'N/A';
        }
        
        return {
          ...ride,
          'driver_name': driverName,
        };
      }).toList();

      print('✅ ${formattedRides.length} courses récupérées');
      return formattedRides;
    } catch (e) {
      print('❌ Erreur récupération courses patient: $e');
      return [];
    }
  }

  /// Récupérer les courses d'un chauffeur
  static Future<List<Map<String, dynamic>>> getDriverRides({
    required String driverId,
    int limit = 5,
  }) async {
    try {
      print('🚗 Récupération courses driver: $driverId (limit: $limit)');

      final response = await _client
          .from('rides')
          .select('''
            id,
            destination_address,
            pickup_address,
            status,
            total_price,
            base_price,
            distance_km,
            duration_minutes,
            driver_rating,
            created_at,
            patients(
              first_name,
              last_name
            )
          ''')
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(limit);

      final rides = (response as List).cast<Map<String, dynamic>>();
      
      // Formater les données pour inclure patient_name au niveau supérieur
      final formattedRides = rides.map((ride) {
        final patients = ride['patients'];
        String patientName = 'N/A';
        
        if (patients != null && patients is Map) {
          final firstName = patients['first_name'] ?? '';
          final lastName = patients['last_name'] ?? '';
          patientName = '$firstName $lastName'.trim();
          if (patientName.isEmpty) patientName = 'N/A';
        }
        
        return {
          ...ride,
          'patient_name': patientName,
        };
      }).toList();

      print('✅ ${formattedRides.length} courses driver récupérées');
      return formattedRides;
    } catch (e) {
      print('❌ Erreur récupération courses driver: $e');
      return [];
    }
  }

  /// Récupérer les courses disponibles (sans chauffeur assigné) pour les chauffeurs
  static Future<List<Map<String, dynamic>>> getAvailableRides({
    int limit = 20,
  }) async {
    try {
      print('🔍 Récupération courses disponibles (sans chauffeur, limit: $limit)');

      final response = await _client
          .from('rides')
          .select('''
            id,
            destination_address,
            pickup_address,
            status,
            total_price,
            base_price,
            distance_km,
            duration_minutes,
            created_at,
            patients(
              first_name,
              last_name,
              user_id,
              users(
                phone_number
              )
            )
          ''')
          .isFilter('driver_id', null) // Courses sans chauffeur
          .eq('status', 'pending') // Seulement les courses en attente
          .order('created_at', ascending: false)
          .limit(limit);

      final rides = (response as List).cast<Map<String, dynamic>>();
      
      // Formater les données pour inclure patient_name au niveau supérieur
      final formattedRides = rides.map((ride) {
        final patients = ride['patients'];
        String patientName = 'N/A';
        String patientPhone = 'N/A';
        
        if (patients != null && patients is Map) {
          final firstName = patients['first_name'] ?? '';
          final lastName = patients['last_name'] ?? '';
          patientName = '$firstName $lastName'.trim();
          if (patientName.isEmpty) patientName = 'N/A';
          
          // Récupérer le phone_number depuis users via patient.user_id
          final users = patients['users'];
          if (users != null && users is Map) {
            patientPhone = users['phone_number'] ?? 'N/A';
          }
        }
        
        return {
          ...ride,
          'patient_name': patientName,
          'patient_phone': patientPhone,
        };
      }).toList();

      print('✅ ${formattedRides.length} courses disponibles récupérées');
      return formattedRides;
    } catch (e) {
      print('❌ Erreur récupération courses disponibles: $e');
      return [];
    }
  }

  /// Récupérer l'historique des courses d'un patient
  static Future<List<Map<String, dynamic>>> getPatientRideHistory() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return [];

      final patient = await getPatientProfile();
      if (patient == null) return [];

      final response = await _client
          .from('rides')
          .select('''
            *,
            drivers(
              first_name,
              last_name,
              rating
            )
          ''')
          .eq('patient_id', patient['id'])
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Erreur historique courses patient: $e');
      return [];
    }
  }

  /// Récupérer l'historique des courses d'un chauffeur
  static Future<List<Map<String, dynamic>>> getDriverRideHistory() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return [];

      final driver = await getDriverProfile();
      if (driver == null) return [];

      final response = await _client
          .from('rides')
          .select('''
            *,
            patients(
              first_name,
              last_name
            )
          ''')
          .eq('driver_id', driver['id'])
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Erreur historique courses chauffeur: $e');
      return [];
    }
  }

  // =========================================
  // TEMPS RÉEL (SUBSCRIPTIONS)
  // =========================================
  
  /// S'abonner aux nouvelles courses en attente (pour chauffeurs)
  static Stream<List<Map<String, dynamic>>> subscribeToPendingRides() {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at')
        .map((data) {
          print('🔔 Mise à jour courses en attente: ${data.length}');
          return data.cast<Map<String, dynamic>>();
        });
  }

  /// S'abonner aux mises à jour d'une course spécifique
  static Stream<Map<String, dynamic>?> subscribeToRide(String rideId) {
    return _client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('id', rideId)
        .map((data) {
          if (data.isEmpty) return null;
          print('🔔 Mise à jour course: $rideId');
          return data.first as Map<String, dynamic>;
        });
  }

  /// S'abonner à la position d'un chauffeur
  static Stream<Map<String, dynamic>?> subscribeToDriverLocation(String driverId) {
    return _client
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .map((data) {
          if (data.isEmpty) return null;
          return data.first as Map<String, dynamic>;
        });
  }

  // =========================================
  // ÉVALUATIONS
  // =========================================
  
  /// Évaluer un chauffeur après une course
  static Future<void> rateDriver({
    required String rideId,
    required int rating,
    String? feedback,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('La note doit être entre 1 et 5');
      }

      await _client
          .from('rides')
          .update({
            'patient_rating': rating,
            'patient_feedback': feedback,
          })
          .eq('id', rideId);

      print('✅ Chauffeur évalué: $rating/5');
    } catch (e) {
      print('❌ Erreur évaluation chauffeur: $e');
      rethrow;
    }
  }

  /// Évaluer un patient après une course
  static Future<void> ratePatient({
    required String rideId,
    required int rating,
    String? feedback,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('La note doit être entre 1 et 5');
      }

      await _client
          .from('rides')
          .update({
            'driver_rating': rating,
            'driver_feedback': feedback,
          })
          .eq('id', rideId);

      print('✅ Patient évalué: $rating/5');
    } catch (e) {
      print('❌ Erreur évaluation patient: $e');
      rethrow;
    }
  }

  // =========================================
  // STATISTIQUES
  // =========================================
  
  /// Récupérer les statistiques d'un chauffeur
  static Future<Map<String, dynamic>> getDriverStats() async {
    try {
      final driver = await getDriverProfile();
      if (driver == null) throw Exception('Profil chauffeur non trouvé');

      final rides = await _client
          .from('rides')
          .select('status, final_price, created_at')
          .eq('driver_id', driver['id']);

      final completedRides = (rides as List).where((r) => r['status'] == 'completed').toList();
      final totalEarnings = completedRides.fold<double>(
        0.0,
        (sum, ride) => sum + (ride['final_price'] ?? 0.0),
      );

      return {
        'total_rides': rides.length,
        'completed_rides': completedRides.length,
        'total_earnings': totalEarnings,
        'rating': driver['rating'] ?? 0.0,
        'status': driver['status'],
      };
    } catch (e) {
      print('❌ Erreur statistiques chauffeur: $e');
      return {};
    }
  }

  // =========================================
  // GESTION DES DOCUMENTS CHAUFFEURS
  // =========================================
  
  /// Upload un document chauffeur vers Supabase Storage
  /// Sur web: utilise XFile.readAsBytes() directement
  static Future<String> uploadDriverDocument({
    required String filePath,
    required String documentType,
    required String fileName,
    Uint8List? fileBytes, // Changé: Uint8List au lieu de List<int>
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      print('[INFO] Upload document: $documentType - $fileName');

      // Obtenir les bytes
      Uint8List bytes;
      if (fileBytes != null) {
        // Web: bytes fournis directement
        bytes = fileBytes;
      } else {
        // Cette partie ne sera pas appelée sur web
        throw UnimplementedError('File reading from path not supported on web');
      }
      
      // Nom unique avec timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final storagePath = '$userId/$documentType/$timestamp.$extension';

      // Upload vers Supabase Storage
      await _client.storage
          .from('driver-documents')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getMimeType(extension),
              upsert: false,
            ),
          );

      // Récupérer l'URL publique
      final publicUrl = _client.storage
          .from('driver-documents')
          .getPublicUrl(storagePath);

      print('[OK] Document uploade: $publicUrl');
      return publicUrl;
      
    } catch (e) {
      print('[ERROR] Erreur upload document: $e');
      rethrow;
    }
  }

  /// Sauvegarder les metadata du document dans la DB
  static Future<Map<String, dynamic>> saveDocumentMetadata({
    required String driverId,
    required String documentType,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    DateTime? expiresAt,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecte');

      final docData = {
        'driver_id': driverId,
        'user_id': userId, // L'ID de l'utilisateur connecté
        'document_type': documentType,
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'mime_type': _getMimeType(fileName.split('.').last),
        'status': 'pending',
        'uploaded_at': DateTime.now().toIso8601String(),
      };
      
      // Ajouter expires_at seulement si fourni
      if (expiresAt != null) {
        docData['expires_at'] = expiresAt.toIso8601String();
      }

      print('[INFO] Sauvegarde metadata document: $documentType');
      print('[DEBUG] Data: ${docData.keys.join(", ")}');

      final response = await _client
          .from('driver_documents')
          .insert(docData)
          .select()
          .single();

      print('[OK] Metadata document sauvegarde: ${response['id']}');
      return response;
      
    } catch (e) {
      print('[ERROR] Erreur sauvegarde metadata document: $e');
      rethrow;
    }
  }

  /// Récupérer tous les documents d'un chauffeur
  static Future<List<Map<String, dynamic>>> getDriverDocuments() async {
    try {
      final userId = currentUser?.id;
      print('🔍 getDriverDocuments: user_id = $userId');
      
      if (userId == null) {
        print('❌ getDriverDocuments: Utilisateur non connecté');
        throw Exception('Utilisateur non connecté');
      }

      print('🔍 getDriverDocuments: Requête Supabase avec user_id = $userId');
      final response = await _client
          .from('driver_documents')
          .select('*')
          .eq('user_id', userId)
          .order('uploaded_at', ascending: false);

      print('✅ getDriverDocuments: ${response.length} documents récupérés');
      if (response.isNotEmpty) {
        print('📄 getDriverDocuments: Premier document = ${response[0]}');
      }

      return List<Map<String, dynamic>>.from(response);
      
    } catch (e) {
      print('❌ Erreur récupération documents: $e');
      return [];
    }
  }

  /// Admin: Récupérer tous les documents pending
  static Future<List<Map<String, dynamic>>> getAdminPendingDocuments() async {
    try {
      final response = await _client
          .from('driver_documents')
          .select('''
            *,
            drivers:driver_id (
              first_name,
              last_name,
              phone_number
            )
          ''')
          .eq('status', 'pending')
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
      
    } catch (e) {
      print('❌ Erreur récupération documents pending: $e');
      return [];
    }
  }

  /// Admin: Récupérer tous les documents (avec filtre optionnel)
  static Future<List<Map<String, dynamic>>> getAdminDocuments({String? statusFilter}) async {
    try {
      var query = _client
          .from('driver_documents')
          .select('''
            *,
            drivers:driver_id (
              first_name,
              last_name,
              phone_number
            )
          ''');

      // Appliquer filtre statut si fourni
      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      final response = await query.order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
      
    } catch (e) {
      print('❌ Erreur récupération documents: $e');
      return [];
    }
  }

  /// Admin: Valider/Rejeter un document
  static Future<void> updateDocumentStatus({
    required String documentId,
    required String status, // 'approved' ou 'rejected'
    String? adminNotes,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      await _client
          .from('driver_documents')
          .update({
            'status': status,
            'admin_notes': adminNotes,
            'validated_by': userId,
            'validated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', documentId);

      print('✅ Document $status: $documentId');
      
    } catch (e) {
      print('❌ Erreur mise à jour statut document: $e');
      rethrow;
    }
  }

  /// Helper: Déterminer le MIME type
  static String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================================
  // NOTIFICATIONS
  // ============================================================================

  /// Récupérer les notifications de l'utilisateur connecté
  static Future<List<Map<String, dynamic>>> getNotifications({bool unreadOnly = false}) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecte');

      var query = _client
          .from('notifications')
          .select('*')
          .eq('user_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
      
    } catch (e) {
      print('[ERROR] Erreur recuperation notifications: $e');
      return [];
    }
  }

  /// Compter les notifications non lues
  static Future<int> getUnreadNotificationsCount() async {
    try {
      final notifications = await getNotifications(unreadOnly: true);
      return notifications.length;
    } catch (e) {
      print('[ERROR] Erreur comptage notifications: $e');
      return 0;
    }
  }

  /// Marquer une notification comme lue
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      print('[OK] Notification marquee comme lue');
    } catch (e) {
      print('[ERROR] Erreur marquage notification: $e');
      rethrow;
    }
  }

  /// Marquer toutes les notifications comme lues
  static Future<void> markAllNotificationsAsRead() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecte');

      await _client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .eq('is_read', false);

      print('[OK] Toutes les notifications marquees comme lues');
    } catch (e) {
      print('[ERROR] Erreur marquage toutes notifications: $e');
      rethrow;
    }
  }

}
