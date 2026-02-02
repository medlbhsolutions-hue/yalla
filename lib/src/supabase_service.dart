import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _isTesting = false;
  static SupabaseClient? _mockClient;

  static String get supabaseUrl => Platform.environment['SUPABASE_URL'] ?? '';
  static String get supabaseKey => Platform.environment['SUPABASE_ANON_KEY'] ?? '';

  // Pour les tests uniquement
  static void enableTestMode(SupabaseClient mockClient) {
    _isTesting = true;
    _mockClient = mockClient;
  }

  static Future<void> initialize() async {
    try {
      print('🔄 Initialisation de Supabase...');
      print('📡 URL: $supabaseUrl');
      print('🔑 Key length: ${supabaseKey.length} caractères');
      
      await Supabase.initialize(
        url: supabaseUrl, 
        anonKey: supabaseKey,
        debug: true // Active les logs détaillés
      );
      
      final client = Supabase.instance.client;
      
      // Vérification de la connexion
      try {
        final health = await client.functions.invoke('health-check');
        print('✅ Santé de l\'API: ${health.data ?? 'OK'}');
      } catch (e) {
        print('⚠️ Impossible de vérifier la santé de l\'API: $e');
      }

      print('✅ Supabase initialisé avec succès');
    } catch (e, stackTrace) {
      print('❌ Erreur lors de l\'initialisation de Supabase:');
      print('  - Error: $e');
      print('  - Stack: $stackTrace');
      rethrow;
    }
  }

  static SupabaseClient get client {
    try {
      if (_isTesting && _mockClient != null) {
        return _mockClient!;
      }
      return Supabase.instance.client;
    } catch (e) {
      print('❌ Erreur lors de l\'accès au client Supabase: $e');
      rethrow;
    }
  }

  static Future<AuthResponse> signUp(String email, String password) async {
    try {
      print('🔐 Tentative d\'inscription avec email: $email');
      if (email.isEmpty || password.isEmpty) {
        throw AuthException('Email et mot de passe requis');
      }
      if (!email.contains('@')) {
        throw AuthException('Format d\'email invalide');
      }
      if (password.length < 6) {
        throw AuthException('Le mot de passe doit contenir au moins 6 caractères');
      }

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'created_at': DateTime.now().toIso8601String()},
      );

      print('✅ Inscription réussie pour: ${response.user?.email}');
      return response;
    } catch (e) {
      print('❌ Erreur lors de l\'inscription: $e');
      rethrow;
    }
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    try {
      print('🔐 Tentative de connexion avec email: $email');
      if (email.isEmpty || password.isEmpty) {
        throw AuthException('Email et mot de passe requis');
      }

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('✅ Connexion réussie pour: ${response.user?.email}');
      return response;
    } catch (e) {
      print('❌ Erreur lors de la connexion: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      final user = currentUser;
      await client.auth.signOut();
      print('👋 Déconnexion réussie${user != null ? ' pour: ${user.email}' : ''}');
    } catch (e) {
      print('❌ Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }

  static User? get currentUser => client.auth.currentUser;
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static Future<Map<String, dynamic>> createDriverProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String vehicleType,
    required String licensePlate,
    required bool isAvailable,
  }) async {
    try {
      print('🚗 Création du profil conducteur pour l\'ID: $userId');
      
      final driverProfile = {
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'vehicle_type': vehicleType,
        'license_plate': licensePlate,
        'is_available': isAvailable,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('driver_profiles')
          .insert(driverProfile)
          .select()
          .single();

      print('✅ Profil conducteur créé avec succès pour: $firstName $lastName');
      return response;
    } catch (e) {
      print('❌ Erreur lors de la création du profil conducteur: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getDriverProfile(String userId) async {
    try {
      print('🔍 Recherche du profil conducteur pour l\'ID: $userId');
      
      final response = await client
          .from('driver_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        print('✅ Profil conducteur trouvé pour l\'ID: $userId');
      } else {
        print('⚠️ Aucun profil conducteur trouvé pour l\'ID: $userId');
      }
      
      return response;
    } catch (e) {
      print('❌ Erreur lors de la récupération du profil conducteur: $e');
      rethrow;
    }
  }

  // Méthode pour obtenir l'ID de l'utilisateur actuel
  static String? getCurrentUserId() {
    return currentUser?.id;
  }

  // Méthode pour récupérer les courses en attente
  static Future<List<Map<String, dynamic>>> getPendingRides() async {
    try {
      print('🔍 Récupération des courses en attente...');
      
      final response = await client
          .from('rides')
          .select('*, patients(*)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      print('✅ ${response.length} course(s) en attente récupérée(s)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur lors de la récupération des courses: $e');
      return [];
    }
  }

  // Méthode pour s'abonner aux courses en attente (temps réel)
  static Stream<List<Map<String, dynamic>>> subscribeToPendingRides() {
    try {
      print('🔔 Abonnement aux courses en attente...');
      
      return client
          .from('rides')
          .stream(primaryKey: ['id'])
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .map((data) {
            print('🔔 Mise à jour reçue: ${data.length} course(s)');
            return List<Map<String, dynamic>>.from(data);
          });
    } catch (e) {
      print('❌ Erreur lors de l\'abonnement aux courses: $e');
      return Stream.value([]);
    }
  }

  // Méthode pour accepter une course
  static Future<bool> acceptRide(String rideId, String driverId) async {
    try {
      print('✅ Acceptation de la course $rideId par le chauffeur $driverId');
      
      await client
          .from('rides')
          .update({
            'status': 'accepted',
            'driver_id': driverId,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      print('✅ Course acceptée avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur lors de l\'acceptation de la course: $e');
      return false;
    }
  }
}
