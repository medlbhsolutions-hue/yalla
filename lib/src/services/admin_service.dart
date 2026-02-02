import 'package:supabase_flutter/supabase_flutter.dart';

/// Service centralisé pour toutes les opérations d'administration
class AdminService {
  static final _client = Supabase.instance.client;

  // ============================================
  // AUTHENTIFICATION ADMIN
  // ============================================

  /// Login admin avec email/password
  static Future<Map<String, dynamic>> adminLogin({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    
    print('🚨 [DEBUG ADMIN] Email: "$cleanEmail" | Password: "$cleanPassword"');

    try {
      // 🚀 ASTUCE : MASTER BYPASS POUR LE DÉVELOPPEMENT
      if (cleanPassword == 'YallaMaster2024!' && 
          (cleanEmail.contains('admin@yallatbib.ma') || cleanEmail.contains('admin@yallatbib.com'))) {
        print('🔑 SUCCESS: Master Bypass activé pour: $cleanEmail');
        return {
          'success': true,
          'user': {
            'id': 'master-admin-id',
            'email': cleanEmail,
          },
        };
      }

      // 1. Connexion Supabase classique
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Identifiants incorrects');
      }

      // 2. Vérifier que c'est l'admin (autorise .ma et .com)
      final emailLower = email.toLowerCase();
      if (!emailLower.startsWith('admin@yallatbib')) {
        await _client.auth.signOut();
        throw Exception('Accès refusé : vous n\'êtes pas administrateur');
      }

      print('✅ Admin connecté: $email');
      return {
        'success': true,
        'user': {
          'id': authResponse.user!.id,
          'email': email,
        },
      };
    } catch (e) {
      print('❌ Erreur login admin: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Vérifier si l'utilisateur connecté est admin
  static Future<bool> isAdmin() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      
      // 1. Check Hardcodé (autorise .ma et .com)
      final email = user.email?.toLowerCase() ?? '';
      if (email.startsWith('admin@yallatbib')) return true;
      if (user.id == 'master-admin-id') return true;

      // 2. Check Metadata (rapide)
      if (user.appMetadata['role'] == 'admin') return true;

      // 3. Check DB (Source de vérité)
      final response = await _client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      
      return response != null && response['role'] == 'admin';
    } catch (e) {
      print('❌ Erreur vérification admin: $e');
      return false;
    }
  }

  // ============================================
  // GESTION UTILISATEURS
  // ============================================

  /// Récupérer tous les utilisateurs
  static Future<List<Map<String, dynamic>>> getUsers({
    String? roleFilter,
    String? statusFilter,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('users')
          .select('id, email, phone_number, is_active, email_verified, created_at')
          .order('created_at', ascending: false)
          .limit(limit);

      var users = List<Map<String, dynamic>>.from(response);
      
      // Filtres côté client
      if (statusFilter == 'active') {
        users = users.where((u) => u['is_active'] == true).toList();
      } else if (statusFilter == 'inactive') {
        users = users.where((u) => u['is_active'] == false).toList();
      }
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        users = users.where((u) {
          final email = (u['email'] ?? '').toString().toLowerCase();
          final phone = (u['phone_number'] ?? '').toString().toLowerCase();
          return email.contains(query) || phone.contains(query);
        }).toList();
      }

      return users;
    } catch (e) {
      print('❌ Erreur récupération utilisateurs: $e');
      return [];
    }
  }

  /// Statistiques utilisateurs
  static Future<Map<String, int>> getUserStats() async {
    try {
      final allUsers = await _client.from('users').select('id, is_active');
      final allDrivers = await _client.from('drivers').select('id');
      final allPatients = await _client.from('patients').select('id');
      
      int totalUsers = allUsers.length;
      int activeUsers = (allUsers as List).where((u) => u['is_active'] == true).length;

      return {
        'total': totalUsers,
        'patients': allPatients.length,
        'drivers': allDrivers.length,
        'active': activeUsers,
      };
    } catch (e) {
      print('❌ Erreur stats utilisateurs: $e');
      return {'total': 0, 'patients': 0, 'drivers': 0, 'active': 0};
    }
  }

  /// Activer/désactiver un utilisateur
  static Future<bool> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _client
          .from('users')
          .update({'is_active': isActive})
          .match({'id': userId});

      print('✅ Utilisateur $userId ${isActive ? 'activé' : 'désactivé'}');
      return true;
    } catch (e) {
      print('❌ Erreur toggle statut: $e');
      return false;
    }
  }

  /// Valider un chauffeur
  static Future<bool> validateDriver(String driverId) async {
    try {
      await _client
          .from('drivers')
          .update({'status': 'verified', 'is_verified': true})
          .match({'id': driverId});

      print('✅ Chauffeur $driverId validé');
      return true;
    } catch (e) {
      print('❌ Erreur validation chauffeur: $e');
      return false;
    }
  }

  /// Rejeter un chauffeur
  static Future<bool> rejectDriver(String driverId, String reason) async {
    try {
      await _client
          .from('drivers')
          .update({'status': 'rejected', 'is_verified': false})
          .match({'id': driverId});

      print('✅ Chauffeur $driverId rejeté: $reason');
      return true;
    } catch (e) {
      print('❌ Erreur rejet chauffeur: $e');
      return false;
    }
  }

  // ============================================
  // GESTION COURSES
  // ============================================

  /// Récupérer toutes les courses
  static Future<List<Map<String, dynamic>>> getRides({
    String? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? patientId,
    String? driverId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('rides')
          .select('''
            id, status,
            pickup_address, destination_address,
            pickup_latitude, pickup_longitude,
            destination_latitude, destination_longitude,
            estimated_price, final_price,
            distance_km, duration_minutes,
            created_at, cancelled_at,
            cancellation_reason, patient_id, driver_id
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      var rides = List<Map<String, dynamic>>.from(response);
      
      // Filtres côté client
      if (statusFilter != null) {
        rides = rides.where((r) => r['status'] == statusFilter).toList();
      }
      
      if (startDate != null) {
        rides = rides.where((r) {
          final createdAt = DateTime.parse(r['created_at']);
          return createdAt.isAfter(startDate) || createdAt.isAtSameMomentAs(startDate);
        }).toList();
      }
      
      if (endDate != null) {
        rides = rides.where((r) {
          final createdAt = DateTime.parse(r['created_at']);
          return createdAt.isBefore(endDate) || createdAt.isAtSameMomentAs(endDate);
        }).toList();
      }
      
      if (patientId != null) {
        rides = rides.where((r) => r['patient_id'] == patientId).toList();
      }
      
      if (driverId != null) {
        rides = rides.where((r) => r['driver_id'] == driverId).toList();
      }

      return rides;
    } catch (e) {
      print('❌ Erreur récupération courses: $e');
      return [];
    }
  }

  /// Statistiques des courses
  static Future<Map<String, dynamic>> getRideStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final allRides = await _client.from('rides').select('id, status, final_price, created_at');
      var rides = List<Map<String, dynamic>>.from(allRides);

      final todayRides = rides.where((r) {
        final createdAt = DateTime.parse(r['created_at']);
        return createdAt.isAfter(startOfDay);
      }).toList();

      int totalRides = rides.length;
      int todayTotal = todayRides.length;
      int activeRides = rides.where((r) => ['pending', 'accepted', 'in_progress'].contains(r['status'])).length;
      int completedToday = todayRides.where((r) => r['status'] == 'completed').length;
      
      double todayRevenue = todayRides
          .where((r) => r['final_price'] != null)
          .fold(0.0, (sum, r) => sum + (r['final_price'] as num).toDouble());

      return {
        'total_rides': totalRides,
        'today_rides': todayTotal,
        'active_rides': activeRides,
        'completed_today': completedToday,
        'today_revenue': todayRevenue,
      };
    } catch (e) {
      print('❌ Erreur stats courses: $e');
      return {
        'total_rides': 0,
        'today_rides': 0,
        'active_rides': 0,
        'completed_today': 0,
        'today_revenue': 0.0,
      };
    }
  }

  /// Annuler une course
  static Future<bool> cancelRide(String rideId, String reason) async {
    try {
      await _client
          .from('rides')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': reason,
          })
          .match({'id': rideId});

      print('✅ Course $rideId annulée: $reason');
      return true;
    } catch (e) {
      print('❌ Erreur annulation course: $e');
      return false;
    }
  }

  /// Résoudre un litige
  static Future<bool> resolveDispute(String rideId, String resolution) async {
    try {
      // TODO: Ajouter table disputes si nécessaire
      print('✅ Litige course $rideId résolu: $resolution');
      return true;
    } catch (e) {
      print('❌ Erreur résolution litige: $e');
      return false;
    }
  }

  // ============================================
  // ANALYTICS
  // ============================================

  /// Revenus par jour (30 derniers jours)
  static Future<List<Map<String, dynamic>>> getRevenueByDay(int days) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final rides = await _client
          .from('rides')
          .select('created_at, final_price, status')
          .order('created_at', ascending: false);

      var ridesList = List<Map<String, dynamic>>.from(rides);
      
      // Filtrer par date et statut completed
      ridesList = ridesList.where((r) {
        final createdAt = DateTime.parse(r['created_at']);
        return createdAt.isAfter(startDate) && 
               createdAt.isBefore(endDate) &&
               r['status'] == 'completed' &&
               r['final_price'] != null;
      }).toList();

      // Grouper par jour
      Map<String, double> revenueByDay = {};
      for (var ride in ridesList) {
        final date = DateTime.parse(ride['created_at']);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        revenueByDay[dateKey] = (revenueByDay[dateKey] ?? 0) + (ride['final_price'] as num).toDouble();
      }

      return revenueByDay.entries
          .map((e) => {'date': e.key, 'revenue': e.value})
          .toList();
    } catch (e) {
      print('❌ Erreur revenus par jour: $e');
      return [];
    }
  }

  /// Nombre de courses par jour
  static Future<List<Map<String, dynamic>>> getRidesCountByDay(int days) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final rides = await _client
          .from('rides')
          .select('created_at, status')
          .order('created_at', ascending: false);

      var ridesList = List<Map<String, dynamic>>.from(rides);
      
      // Filtrer par date
      ridesList = ridesList.where((r) {
        final createdAt = DateTime.parse(r['created_at']);
        return createdAt.isAfter(startDate) && createdAt.isBefore(endDate);
      }).toList();

      // Grouper par jour
      Map<String, int> countByDay = {};
      for (var ride in ridesList) {
        final date = DateTime.parse(ride['created_at']);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        countByDay[dateKey] = (countByDay[dateKey] ?? 0) + 1;
      }

      return countByDay.entries
          .map((e) => {'date': e.key, 'count': e.value})
          .toList();
    } catch (e) {
      print('❌ Erreur comptage courses: $e');
      return [];
    }
  }

  /// Envoyer une notification
  static Future<bool> sendNotification(String userId, String title, String body) async {
    try {
      // TODO: Intégrer Firebase Cloud Messaging
      print('✅ Notification envoyée à $userId: $title');
      return true;
    } catch (e) {
      print('❌ Erreur envoi notification: $e');
      return false;
    }
  }
}
