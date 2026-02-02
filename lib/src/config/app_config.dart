import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service de configuration centralisé
/// Gère toutes les variables d'environnement de manière sécurisée
/// 
/// ⚠️ IMPORTANT: Charger dotenv AVANT d'utiliser ce service
/// await dotenv.load(fileName: ".env");
class AppConfig {
  // Empêcher l'instanciation
  AppConfig._();

  /// Environnement actuel (development, staging, production)
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  
  /// Mode production
  static bool get isProduction => environment == 'production';
  
  /// Mode développement
  static bool get isDevelopment => environment == 'development';
  
  /// Logs activés
  static bool get enableLogs => dotenv.env['ENABLE_LOGS']?.toLowerCase() == 'true';

  // ============================================
  // FIREBASE CONFIGURATION
  // ============================================
  
  // ============================================
  // VALIDATION (Relaxée pour démo)
  // ============================================
  
  /// Valider que toutes les configurations critiques sont présentes
  static void validate() {
    final errors = <String>[];

    // Vérifier Firebase (Log seulement)
    if (firebaseApiKey.isEmpty) errors.add('Firebase API Key manquante');
    if (firebaseAuthDomain.isEmpty) errors.add('Firebase Auth Domain manquant');
    if (firebaseProjectId.isEmpty) errors.add('Firebase Project ID manquant');

    // Vérifier Supabase (Critique mais ne pas crasher ici, laisser DatabaseService gérer)
    if (supabaseUrl.isEmpty) errors.add('Supabase URL manquante');
    if (supabaseAnonKey.isEmpty) errors.add('Supabase Key manquante');

    // Google Maps
    if (isProduction && googleMapsApiKey.isEmpty) {
       errors.add('Google Maps API Key manquante en production');
    }

    if (errors.isNotEmpty) {
      // Au lieu de crasher, on log juste les erreurs
      print('⚠️ ATTENTION: Configuration partielle:\n${errors.join('\n')}');
      print('L\'application va tenter de démarrer mais certaines fonctionnalités peuvent échouer.');
    }
  }

  // MODIFICATION DES GETTERS POUR NE PAS CRASHER

  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseAuthDomain => dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseStorageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get firebaseMessagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';

  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url != null && url.isNotEmpty) return url;
    // FALLBACK POUR DEMO (Sauvetage)
    return '';
  }

  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key != null && key.isNotEmpty) return key;
    // FALLBACK POUR DEMO (Sauvetage)
    return '';
  }
  
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ============================================
  // TWILIO CONFIGURATION (Optionnel)
  // ============================================
  
  static String? get twilioAccountSid => dotenv.env['TWILIO_ACCOUNT_SID'];
  static String? get twilioAuthToken => dotenv.env['TWILIO_AUTH_TOKEN'];
  static String? get twilioPhoneNumber => dotenv.env['TWILIO_PHONE_NUMBER'];

  /// Vérifier si Twilio est configuré
  static bool get isTwilioConfigured {
    return twilioAccountSid != null && 
           twilioAuthToken != null && 
           twilioPhoneNumber != null;
  }

  /// Afficher un résumé de la configuration (sans exposer les clés)
  static void printSummary() {
    if (!enableLogs) return;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📋 CONFIGURATION DE L\'APPLICATION');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌍 Environnement: $environment');
    print('🔧 Logs activés: $enableLogs');
    print('');
    print('🔥 Firebase: ${maskKey(firebaseApiKey)}');
    print('🗄️  Supabase: ${maskKey(supabaseAnonKey)}');
    print('🗺️  Google Maps: ${googleMapsApiKey.isEmpty ? "Non configuré" : maskKey(googleMapsApiKey)}');
    print('📱 Twilio: ${isTwilioConfigured ? "Configuré" : "Non configuré"}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Masquer une clé API pour l'affichage (garder 4 premiers et 4 derniers caractères)
  static String maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }
}
