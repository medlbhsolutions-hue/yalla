import 'database_service.dart';

/// Service pour détecter automatiquement le rôle d'un utilisateur
/// (Patient, Chauffeur, ou les deux)
class RoleDetectionService {
  
  /// Détecte le rôle de l'utilisateur connecté
  /// Retourne 'admin', 'patient', 'driver', 'both', ou null si aucun profil
  static Future<String?> detectUserRole() async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      
      if (userId == null) {
        print('❌ Aucun utilisateur connecté');
        return null;
      }
      
      print('🔍 Détection du rôle pour user: $userId');
      
      // 1. Vérifier si SUPER ADMIN (Hardcodé - Secours)
      final email = DatabaseService.currentUser?.email;
      if (email == 'admin@yallatbib.com') {
        print('👑 Super Administrateur détecté (Email)');
        return 'admin';
      }

      // 2. Vérifier le rôle dans la base de données (Table 'users')
      try {
        final userDoc = await DatabaseService.client
            .from('users')
            .select('role')
            .eq('id', userId)
            .maybeSingle();
        
        if (userDoc != null && userDoc['role'] == 'admin') {
          print('👑 Administrateur détecté (DB)');
          return 'admin';
        }
      } catch (e) {
        print('⚠️ Erreur lecture role DB: $e');
      }

      // 3. Vérifier les metadata Auth (Fallback)
      final metadata = DatabaseService.currentUser?.appMetadata;
      if (metadata != null && (metadata['role'] == 'admin' || metadata['authorization_tier'] == 'admin')) {
         print('👑 Administrateur détecté (Metadata)');
         return 'admin';
      }
      
      // Vérifier si l'utilisateur est un patient
      final isPatient = await _checkIfPatient(userId);
      
      // Vérifier si l'utilisateur est un chauffeur
      final isDriver = await _checkIfDriver(userId);
      
      print('📊 Résultat: Patient=$isPatient, Driver=$isDriver');
      
      if (isPatient && isDriver) {
        return 'both'; // Rare : utilisateur avec les 2 rôles
      } else if (isDriver) {
        return 'driver';
      } else if (isPatient) {
        return 'patient';
      } else {
        print('⚠️ Aucun profil trouvé pour cet utilisateur');
        return null;
      }
      
    } catch (e) {
      print('❌ Erreur détection rôle: $e');
      return null;
    }
  }
  
  /// Vérifie si l'utilisateur a un profil patient
  static Future<bool> _checkIfPatient(String userId) async {
    try {
      final response = await DatabaseService.client
          .from('patients')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('❌ Erreur vérification patient: $e');
      return false;
    }
  }
  
  /// Vérifie si l'utilisateur a un profil chauffeur
  static Future<bool> _checkIfDriver(String userId) async {
    try {
      final response = await DatabaseService.client
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('❌ Erreur vérification driver: $e');
      return false;
    }
  }
  
  /// Récupère les informations du profil patient
  static Future<Map<String, dynamic>?> getPatientProfile() async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) return null;
      
      final response = await DatabaseService.client
          .from('patients')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('❌ Erreur récupération profil patient: $e');
      return null;
    }
  }
  
  /// Crée automatiquement un profil patient pour l'utilisateur connecté
  static Future<Map<String, dynamic>?> createPatientProfile() async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) {
        print('❌ Impossible de créer profil patient: pas d\'utilisateur connecté');
        return null;
      }
      
      print('🏥 Création du profil patient pour user: $userId');
      
      // Créer un profil patient de base
      final patientData = {
        'user_id': userId,
        'first_name': 'Nouveau',
        'last_name': 'Patient',
        'date_of_birth': null,
        'emergency_contact_name': null,
        'emergency_contact_phone': null,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final response = await DatabaseService.client
          .from('patients')
          .insert(patientData)
          .select()
          .single();
      
      print('✅ Profil patient créé avec ID: ${response['id']}');
      return response;
    } catch (e) {
      print('❌ Erreur création profil patient: $e');
      return null;
    }
  }
  
  /// Récupère les informations du profil chauffeur
  static Future<Map<String, dynamic>?> getDriverProfile() async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) return null;
      
      final response = await DatabaseService.client
          .from('drivers')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('❌ Erreur récupération profil driver: $e');
      return null;
    }
  }
  
  /// Crée automatiquement un profil chauffeur pour l'utilisateur connecté
  static Future<Map<String, dynamic>?> createDriverProfile() async {
    try {
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) {
        print('❌ Impossible de créer profil driver: pas d\'utilisateur connecté');
        return null;
      }
      
      print('🚗 Création du profil chauffeur pour user: $userId');
      
      // Créer un profil chauffeur de base
      final driverData = {
        'user_id': userId,
        'first_name': 'Nouveau',
        'last_name': 'Chauffeur',
        'is_available': true,
        'current_location': null,
        'rating': 5.0,
        'total_rides': 0,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final response = await DatabaseService.client
          .from('drivers')
          .insert(driverData)
          .select()
          .single();
      
      print('✅ Profil chauffeur créé avec ID: ${response['id']}');
      
      // Créer aussi un véhicule par défaut
      try {
        await DatabaseService.client
            .from('vehicles')
            .insert({
              'driver_id': response['id'],
              'make': 'À définir',
              'model': 'À définir',
              'year': DateTime.now().year,
              'license_plate': 'TEMP-000',
              'color': 'Blanc',
              'vehicle_type': 'ambulance',
              'capacity': 4,
              'is_active': true,
            });
        print('✅ Véhicule par défaut créé');
      } catch (e) {
        print('⚠️ Erreur création véhicule: $e');
      }
      
      return response;
    } catch (e) {
      print('❌ Erreur création profil driver: $e');
      return null;
    }
  }
}
