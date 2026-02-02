import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _supabase = SupabaseConfig.client;
  
  // Inscription avec OTP réel
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String phone,
    required String name,
    required String password,
    required String userType,
  }) async {
    try {
      print('🚀 Début inscription: $email');
      
      // 1. Créer utilisateur Supabase
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'phone': phone,
          'name': name,
          'user_type': userType,
        },
      );

      if (response.user == null) {
        throw 'Erreur création utilisateur';
      }

      // 2. Créer profil utilisateur dans la base
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'email': email,
        'phone_number': phone,
        'name': name,
        'user_type': userType,
      });

      // 3. Si c'est un chauffeur, créer profil chauffeur
      if (userType == 'driver') {
        await _supabase.from('drivers').insert({
          'user_id': response.user!.id,
          'first_name': name.split(' ').first,
          'last_name': name.split(' ').last,
          'status': 'pending',
        });
      }
      // 4. Si c'est un patient, créer profil patient
      else if (userType == 'patient') {
        await _supabase.from('patients').insert({
          'user_id': response.user!.id,
          'first_name': name.split(' ').first,
          'last_name': name.split(' ').last,
        });
      }

      print('✅ Utilisateur créé: ${response.user!.id}');
      
      return {
        'success': true,
        'message': 'Compte créé avec succès. Vérifiez votre email.',
        'user_id': response.user!.id,
      };
    } catch (e) {
      print('❌ Erreur inscription: $e');
      throw 'Erreur lors de l\'inscription: $e';
    }
  }

  // Connexion
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Tentative connexion: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw 'Email ou mot de passe incorrect';
      }

      // Récupérer le profil utilisateur
      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();

      print('✅ Connexion réussie');

      return {
        'success': true,
        'message': 'Connexion réussie',
        'user': userData,
      };
    } catch (e) {
      print('❌ Erreur connexion: $e');
      throw 'Erreur de connexion: $e';
    }
  }

  // Récupérer utilisateur actuel
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Récupérer profil utilisateur
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return data;
    } catch (e) {
      throw 'Erreur récupération profil: $e';
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    print('👋 Déconnexion');
  }

  // Stream de l'état d'authentification
  Stream<AuthState> authStateChanges() {
    return _supabase.auth.onAuthStateChange;
  }
}