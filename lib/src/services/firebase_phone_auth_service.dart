import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service d'authentification Firebase pour SMS réels
/// 
/// Utilise Firebase Authentication pour envoyer des OTP par SMS
/// et vérifier les codes reçus.
class FirebasePhoneAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// ID de vérification stocké après l'envoi du SMS
  static String? _verificationId;
  
  /// Token de renvoi pour les SMS multiples
  static int? _forceResendingToken;

  /// Envoie un code OTP par SMS au numéro spécifié
  /// 
  /// [phoneNumber] doit être au format international avec +
  /// Exemple: +212669337817
  /// 
  /// Retourne un Future qui se complète quand le SMS est envoyé.
  /// Lance une exception en cas d'erreur.
  static Future<void> sendOTP({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      if (kDebugMode) {
        print('📱 Firebase: Envoi SMS vers $phoneNumber');
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        
        // Appelé quand la vérification automatique réussit (Android uniquement)
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (kDebugMode) {
            print('✅ Vérification automatique réussie (Android)');
          }
          // Connexion automatique
          await _auth.signInWithCredential(credential);
        },
        
        // Appelé en cas d'échec de la vérification
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) {
            print('❌ Échec vérification Firebase: ${e.code} - ${e.message}');
          }
          
          // Traduction des erreurs Firebase en français
          String errorMessage;
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = 'Numéro de téléphone invalide';
              break;
            case 'too-many-requests':
              errorMessage = 'Trop de tentatives. Réessayez plus tard';
              break;
            case 'quota-exceeded':
              errorMessage = 'Quota SMS dépassé. Contactez le support';
              break;
            case 'network-request-failed':
              errorMessage = 'Erreur réseau. Vérifiez votre connexion';
              break;
            default:
              errorMessage = 'Erreur d\'authentification: ${e.message}';
          }
          
          throw Exception(errorMessage);
        },
        
        // Appelé quand le code est envoyé avec succès
        codeSent: (String verificationId, int? resendToken) {
          if (kDebugMode) {
            print('📨 Code SMS envoyé avec succès');
            print('   Verification ID: $verificationId');
          }
          
          _verificationId = verificationId;
          _forceResendingToken = resendToken;
        },
        
        // Appelé quand le timeout est atteint
        codeAutoRetrievalTimeout: (String verificationId) {
          if (kDebugMode) {
            print('⏱️ Timeout de récupération automatique du code');
          }
          _verificationId = verificationId;
        },
        
        // Token pour forcer le renvoi du SMS
        forceResendingToken: _forceResendingToken,
      );
      
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur Firebase Auth: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur inattendue: $e');
      }
      rethrow;
    }
  }

  /// Vérifie le code OTP saisi par l'utilisateur
  /// 
  /// [otp] est le code à 6 chiffres reçu par SMS
  /// 
  /// Retourne l'utilisateur Firebase connecté.
  /// Lance une exception si le code est invalide.
  static Future<User> verifyOTP(String otp) async {
    try {
      if (_verificationId == null) {
        throw Exception('Aucun code SMS envoyé. Veuillez d\'abord envoyer un SMS.');
      }

      if (kDebugMode) {
        print('🔐 Vérification du code OTP: $otp');
        print('   Verification ID: $_verificationId');
      }

      // Création des credentials avec le code de vérification
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Connexion à Firebase avec les credentials
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Échec de la connexion');
      }

      if (kDebugMode) {
        print('✅ Connexion Firebase réussie');
        print('   UID: ${userCredential.user!.uid}');
        print('   Téléphone: ${userCredential.user!.phoneNumber}');
      }

      return userCredential.user!;
      
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Erreur vérification OTP: ${e.code} - ${e.message}');
      }
      
      // Traduction des erreurs
      String errorMessage;
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Code de vérification invalide';
          break;
        case 'session-expired':
          errorMessage = 'Session expirée. Demandez un nouveau code';
          break;
        case 'invalid-verification-id':
          errorMessage = 'Identifiant de vérification invalide';
          break;
        default:
          errorMessage = 'Erreur de vérification: ${e.message}';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Renvoie un nouveau code OTP
  /// 
  /// Utilise le même numéro de téléphone que la dernière demande.
  /// Le token de renvoi force Firebase à renvoyer un SMS même si
  /// le délai minimal n'est pas écoulé.
  static Future<void> resendOTP(String phoneNumber) async {
    if (kDebugMode) {
      print('🔁 Renvoi du code SMS vers $phoneNumber');
    }
    
    // Le token de renvoi sera utilisé automatiquement
    await sendOTP(phoneNumber: phoneNumber);
  }

  /// Déconnecte l'utilisateur Firebase actuel
  static Future<void> signOut() async {
    if (kDebugMode) {
      print('👋 Déconnexion Firebase');
    }
    
    await _auth.signOut();
    _verificationId = null;
    _forceResendingToken = null;
  }

  /// Retourne l'utilisateur Firebase actuellement connecté
  static User? get currentUser => _auth.currentUser;

  /// Retourne true si un utilisateur est connecté
  static bool get isSignedIn => _auth.currentUser != null;

  /// Stream des changements d'état d'authentification
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
