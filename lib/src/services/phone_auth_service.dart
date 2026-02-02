import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_phone_auth_service.dart';

/// Service d'authentification par téléphone avec SMS
/// 
/// ⚠️ MODE SIMULATION FORCÉ (même en production)
/// - Utilise toujours le code fixe 123456 (gratuit, pas de SMS réel)
/// - Pour activer les vrais SMS, changez FORCE_SIMULATION_MODE à false
class PhoneAuthService {
  static final _client = Supabase.instance.client;

  /// 🔧 MODE SIMULATION FORCÉ (même en release/production)
  /// Mettez à false pour activer les vrais SMS via Firebase
  static const bool FORCE_SIMULATION_MODE = false;

  /// CODE FIXE POUR LE MODE SIMULATION
  static const String DEBUG_OTP_CODE = '123456';
  
  /// Map pour stocker les numéros en attente de vérification (mode debug)
  static final Map<String, bool> _debugPhoneNumbers = {};

  /// Envoyer un code OTP par SMS
  /// Format du numéro: +212669337817 (avec indicatif pays)
  /// 
  /// MODE SIMULATION (kDebugMode = true):
  /// - N'envoie PAS de vrai SMS
  /// - Utilise le code fixe: 123456
  /// - Affiche le code dans la console
  /// 
  /// MODE PRODUCTION (kDebugMode = false):
  /// - Utilise Firebase Authentication
  /// - Envoie un VRAI SMS avec un code à 6 chiffres
  static Future<void> sendOTP(String phoneNumber) async {
    try {
      print('📱 Envoi du code SMS vers: $phoneNumber');
      
      // MODE SIMULATION (forcé ou debug)
      if (FORCE_SIMULATION_MODE) {
        print('');
        print('🧪 ═══════════════════════════════════════');
        print('🧪 MODE SIMULATION SMS ACTIVÉ');
        print('🧪 ═══════════════════════════════════════');
        print('🧪 Numéro: $phoneNumber');
        print('🧪 Code OTP: $DEBUG_OTP_CODE');
        print('🧪 ═══════════════════════════════════════');
        print('🧪 UTILISEZ LE CODE: $DEBUG_OTP_CODE');
        print('🧪 ═══════════════════════════════════════');
        print('');
        
        // Enregistrer le numéro comme "en attente de vérification"
        _debugPhoneNumbers[phoneNumber] = true;
        
        // Simuler un délai réseau
        await Future.delayed(const Duration(milliseconds: 500));
        
        print('✅ Code SMS simulé envoyé avec succès');
        return;
      }
      
      // MODE PRODUCTION (vrais SMS via Firebase)
      print('🔥 Mode production: envoi SMS réel via Firebase');
      await FirebasePhoneAuthService.sendOTP(phoneNumber: phoneNumber);
      
      print('✅ Code SMS réel envoyé avec succès via Firebase');
    } catch (e) {
      print('❌ Erreur envoi SMS: $e');
      rethrow;
    }
  }

  /// Vérifier le code OTP reçu par SMS
  /// 
  /// MODE SIMULATION (kDebugMode = true):
  /// - Accepte le code fixe: 123456
  /// - Crée un utilisateur simulé
  /// - Pas de vérification réelle
  /// 
  /// MODE PRODUCTION (kDebugMode = false):
  /// - Utilise Firebase Authentication
  /// - Vérifie le code reçu par SMS réel
  /// - Retourne l'utilisateur Firebase authentifié
  static Future<AuthResponse> verifyOTP({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      print('🔐 Vérification du code: $otpCode pour $phoneNumber');
      
      // MODE SIMULATION (forcé ou debug)
      if (FORCE_SIMULATION_MODE) {
        print('🧪 Mode simulation: vérification du code');
        
        // Vérifier que le numéro a bien reçu un "SMS simulé"
        if (!_debugPhoneNumbers.containsKey(phoneNumber)) {
          throw Exception('Aucun code envoyé à ce numéro. Envoyez d\'abord un SMS.');
        }
        
        // Vérifier le code
        if (otpCode != DEBUG_OTP_CODE) {
          print('❌ Code incorrect. Attendu: $DEBUG_OTP_CODE, Reçu: $otpCode');
          throw Exception('Code OTP incorrect. Utilisez: $DEBUG_OTP_CODE');
        }
        
        print('✅ Code correct ! Authentification en cours...');
        
        // MODE SIMULATION : Utiliser l'authentification anonyme Supabase
        // Plus simple et ne necessite pas d'email
        
        print('Connexion Supabase en mode anonyme...');
        
        try {
          // Se connecter de maniere anonyme avec metadata
          final authResponse = await _client.auth.signInAnonymously(
            data: {
              'phone': phoneNumber,
              'auth_mode': 'simulation_sms',
            },
          );
          
          print('✅ Session Supabase anonyme! User ID: ${authResponse.user?.id}');
          
          // Nettoyer
          _debugPhoneNumbers.remove(phoneNumber);
          return authResponse;
          
        } catch (anonError) {
          print('❌ Auth anonyme echouee: $anonError');
          
          // FALLBACK: Email ultra-simple
          final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
          final simpleDigits = digits.length > 10 ? digits.substring(digits.length - 9) : digits;
          final email = 'u$simpleDigits@t.co';
          final password = 'Pwd123!$simpleDigits';
          
          print('Fallback email: $email');
          
          try {
            final authResponse = await _client.auth.signInWithPassword(
              email: email,
              password: password,
            );
            print('✅ Connexion: $email');
            
            // ✅ ATTENDRE que la session soit bien établie
            await Future.delayed(const Duration(milliseconds: 800));
            
            // Vérifier que l'utilisateur est connecté
            final currentUser = _client.auth.currentUser;
            print('🔍 Utilisateur actuel: ${currentUser?.email} (ID: ${currentUser?.id})');
            
            _debugPhoneNumbers.remove(phoneNumber);
            return authResponse;
          } catch (_) {
            // Créer le compte avec signUp
            print('📝 Création du compte avec signUp...');
            
            try {
              await _client.auth.signUp(
                email: email,
                password: password,
                emailRedirectTo: null,
              );
              
              print('✅ Compte créé: $email');
              
              // IMPORTANT : Attendre que le compte soit vraiment créé dans la base
              await Future.delayed(const Duration(milliseconds: 2000));
              
            } catch (signUpError) {
              print('⚠️ Erreur signUp (compte existe peut-être déjà): $signUpError');
            }
            
            // TOUJOURS essayer de se connecter après (que signUp ait réussi ou échoué)
            print('🔐 Connexion avec le compte...');
            
            try {
              final authResponse = await _client.auth.signInWithPassword(
                email: email,
                password: password,
              );
              
              print('✅ Connexion réussie!');
              print('👤 User ID: ${authResponse.user?.id}');
              print('📧 Email: ${authResponse.user?.email}');
              
              // Attendre que la session soit bien établie
              await Future.delayed(const Duration(milliseconds: 1000));
              
              // Vérifier que l'utilisateur est connecté
              final currentUser = _client.auth.currentUser;
              print('🔍 Vérification session: ${currentUser?.email} (ID: ${currentUser?.id})');
              
              if (currentUser == null) {
                throw Exception('Session non établie après connexion');
              }
              
              _debugPhoneNumbers.remove(phoneNumber);
              return authResponse;
              
            } catch (signInError) {
              print('❌ Impossible de se connecter: $signInError');
              throw Exception('Erreur de connexion. Vérifiez que la confirmation d\'email est désactivée dans Supabase.');
            }
          }
        }
      }
      
      // MODE PRODUCTION (vrais SMS via Firebase)
      print('🔥 Mode production: vérification via Firebase');
      
      // Vérifier le code avec Firebase
      final firebaseUser = await FirebasePhoneAuthService.verifyOTP(otpCode);
      
      print('✅ Utilisateur Firebase authentifié: ${firebaseUser.uid}');
      
      // 🔗 SYNCHRONISATION SUPABASE (Pour avoir une session Supabase active)
      // On utilise un compte "fantôme" basé sur le numéro de téléphone vérifié
      final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final simpleDigits = digits.length > 10 ? digits.substring(digits.length - 9) : digits;
      final email = 'u$simpleDigits@t.co';
      final password = 'Pwd123!$simpleDigits';

      print('🔗 Synchronisation session Supabase ($email)...');
      
      try {
        // Tentative de connexion
        return await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        // Si échec, le compte n'existe peut-être pas encore -> Inscription
        print('📝 Création automatique du compte Supabase associé...');
        await _client.auth.signUp(
          email: email,
          password: password,
          data: {'phone': phoneNumber, 'firebase_uid': firebaseUser.uid},
        );
        
        // Connexion finale
        return await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
      
    } catch (e) {
      print('❌ Erreur vérification OTP: $e');
      rethrow;
    }
  }

  /// Obtenir l'utilisateur actuellement connecté
  static User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Vérifier si l'utilisateur est connecté
  static bool isLoggedIn() {
    return _client.auth.currentUser != null;
  }

  /// Déconnexion
  static Future<void> signOut() async {
    await _client.auth.signOut();
    print('👋 Déconnexion réussie');
  }

  /// Formater le numéro de téléphone au format international
  /// Exemples:
  /// - "+33669337817" → "+33669337817" (déjà formaté)
  /// - "+212669337817" → "+212669337817" (déjà formaté)
  /// - "0669337817" → "+212669337817" (Maroc par défaut)
  static String formatPhoneNumber(String phone) {
    // Enlever tous les espaces et caractères spéciaux (sauf +)
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Si déjà au format international (+33, +212, etc.)
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    
    // Si commence par 0, remplacer par +212 (Maroc par défaut)
    if (cleaned.startsWith('0')) {
      return '+212${cleaned.substring(1)}';
    }
    
    // Sinon ajouter +212
    return '+212$cleaned';
  }

  /// Valider un numéro de téléphone international
  /// Accepte: +33 (France), +212 (Maroc), et autres formats E.164
  static bool isValidInternationalPhone(String phone) {
    final formatted = formatPhoneNumber(phone);
    // Format E.164: + suivi de 1 à 15 chiffres
    return RegExp(r'^\+\d{7,15}$').hasMatch(formatted);
  }

  /// Valider un numéro de téléphone marocain (rétro-compatibilité)
  static bool isValidMoroccanPhone(String phone) {
    final formatted = formatPhoneNumber(phone);
    // Format attendu: +212 suivi de 9 chiffres
    return RegExp(r'^\+212\d{9}$').hasMatch(formatted);
  }
}
