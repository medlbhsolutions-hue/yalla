import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ NOUVEAU: Gestion sécurisée des variables d'environnement
import 'src/config/app_config.dart'; // ✅ NOUVEAU: Configuration centralisée
import 'src/services/database_service.dart';
import 'src/services/notification_service.dart';
import 'src/screens/app_loader_screen.dart';
import 'src/screens/waiting_driver_screen.dart';
import 'src/screens/ride_tracking_screen.dart';
import 'src/screens/ride_rating_screen.dart';
import 'src/screens/onboarding_screens.dart';
import 'src/screens/admin/admin_login_screen.dart';
import 'src/screens/admin/admin_dashboard_screen.dart';
import 'src/screens/test_autocomplete_screen.dart'; // 🧪 TEST
import 'src/utils/app_colors.dart'; // 🎨 Couleurs Yalla Tbib
import 'patient_dashboard_improved.dart' as patient_dash;
import 'driver_dashboard_improved.dart' as driver_dash_improved; 
import 'src/screens/auth/signin_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/screens/auth/role_selection_screen.dart';
import 'src/screens/transport_type_selection_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 0. Charger les variables d'environnement (.env) EN PREMIER
    // ⚠️ IMPORTANT: Doit être fait AVANT toute utilisation de AppConfig
    print('📁 Chargement des variables d\'environnement...');
    await dotenv.load(fileName: ".env");
    print('✅ Variables d\'environnement chargées');
    
    // Valider la configuration
    AppConfig.validate();
    AppConfig.printSummary();
    
    // 1. Initialiser les locales pour les dates en français
    if (AppConfig.enableLogs) print('🌍 Initialisation des locales...');
    await initializeDateFormatting('fr_FR', null);
    Intl.defaultLocale = 'fr_FR';
    if (AppConfig.enableLogs) print('✅ Locales initialisées');
    
    // 2. Initialiser Firebase EN PREMIER (obligatoire pour Firebase Auth)
    if (AppConfig.enableLogs) print('🔥 Initialisation de Firebase...');
    if (kIsWeb) {
      if (AppConfig.firebaseApiKey.isNotEmpty) {
        try {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: AppConfig.firebaseApiKey,
              authDomain: AppConfig.firebaseAuthDomain,
              projectId: AppConfig.firebaseProjectId,
              storageBucket: AppConfig.firebaseStorageBucket,
              messagingSenderId: AppConfig.firebaseMessagingSenderId,
              appId: AppConfig.firebaseAppId,
            ),
          );
           if (AppConfig.enableLogs) print('✅ Firebase initialisé avec succès');
        } catch (e) {
          print('⚠️ Erreur initialisation Firebase: $e');
        }
      } else {
        print('⚠️ Skipped Firebase initialization: API Key missing in .env');
      }
    } else {
      await Firebase.initializeApp();
    }
    if (AppConfig.enableLogs) print('✅ Firebase initialisé avec succès');
    
    // 3. Initialiser Supabase APRÈS
    if (AppConfig.enableLogs) print('🗄️  Initialisation de Supabase...');
    await DatabaseService.initialize();
    if (AppConfig.enableLogs) print('✅ Supabase initialisé avec succès');
    
    // 4. Initialiser les notifications (SEULEMENT SUR MOBILE)
    if (!kIsWeb) {
      if (AppConfig.enableLogs) print('🔔 Initialisation des notifications...');
      await NotificationService.initialize();
      if (AppConfig.enableLogs) print('✅ Notifications initialisées');
    } else {
      if (AppConfig.enableLogs) print('⚠️  Notifications désactivées sur Web');
    }
    
    runApp(const MyApp());
    
  } catch (e, stackTrace) {
    // Gestion d'erreur critique au démarrage
    debugPrint('❌ ERREUR CRITIQUE AU DÉMARRAGE');
    debugPrint('Erreur: $e');
    debugPrint('StackTrace: $stackTrace');
    
    // Afficher un écran d'erreur à l'utilisateur
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'Erreur de configuration',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Veuillez vérifier le fichier .env',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YALLA L\'TBIB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary, // Bleu #467db0
        primarySwatch: MaterialColor(
          0xFF467DB0,
          const <int, Color>{
            50: Color(0xFFE8F1F8),
            100: Color(0xFFC6DCEE),
            200: Color(0xFFA0C5E3),
            300: Color(0xFF7AAED8),
            400: Color(0xFF5D9DCF),
            500: Color(0xFF467DB0), // Couleur principale
            600: Color(0xFF3F75A7),
            700: Color(0xFF376A9C),
            800: Color(0xFF2F6092),
            900: Color(0xFF204D80),
          },
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.green,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
        ),
      ),
      // 🎨 Page d'accueil avec détection automatique
      home: const AppLoaderScreen(),
      // Routes nommées pour la navigation
      routes: {
        '/patient-dashboard': (context) => const patient_dash.PatientDashboard(),
        '/driver-dashboard': (context) => const driver_dash_improved.DriverDashboard(),
        '/admin': (context) => const AdminLoginScreen(), // 🛡️ ADMIN : Route login
        '/waiting-driver': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return WaitingDriverScreen(rideId: args['id'] as String);
        },
        '/ride-tracking': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return RideTrackingScreen(
            rideData: args,
            driver: args['driver'] ?? {},
          );
        },
        '/ride-rating': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return RideRatingScreen(
            rideId: args['rideId'] as String,
            raterRole: args['isPatient'] == true ? 'patient' : 'driver',
            rideData: args['rideData'] ?? {},
          );
        },
        '/test-autocomplete': (context) => const TestAutocompleteScreen(), // 🧪 TEST
        '/role-selection': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] as String? ?? DatabaseService.getCurrentUserId() ?? '';
          return RoleSelectionScreen(userId: userId);
        },
        '/transport-selection': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final role = args?['role'] as String? ?? 'patient';
          return TransportTypeSelectionScreen(userRole: role);
        },
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
      },
    );
  }
}

// ============================================
// ÉCRAN D'AUTHENTIFICATION SIMPLIFIÉ (TÉLÉPHONE UNIQUEMENT)
// ============================================
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  const Icon(
                    Icons.local_hospital,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'YALLA L\'TBIB',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Transport Médical Rapide',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '📱 Entrez votre numéro de téléphone\npour commencer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Champ Téléphone
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        hintText: 'Ex: 0612345678',
                        prefixIcon: Icon(Icons.phone, color: Color(0xFF4CAF50)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Boutons Patient / Chauffeur
                  const Text(
                    'Vous êtes :',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      // Bouton Patient
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _handlePhoneAuth(isDriver: false),
                          icon: const Icon(Icons.person),
                          label: const Text('PATIENT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Bouton Chauffeur
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _handlePhoneAuth(isDriver: true),
                          icon: const Icon(Icons.drive_eta),
                          label: const Text('CHAUFFEUR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // GESTION AUTHENTIFICATION PAR TÉLÉPHONE
  // ============================================
  void _handlePhoneAuth({required bool isDriver}) async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez entrer un numéro de téléphone valide (10 chiffres)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      print('📱 Création de compte pour: $phone');
      
      // Créer un email technique basé sur le téléphone avec domaine valide
      final technicalEmail = 'yalla_$phone@gmail.com';
      final password = 'YallaTbib_${phone}_2025!'; // Mot de passe généré automatiquement
      
      print('📧 Email technique: $technicalEmail');
      
      // 1. Créer le compte Supabase
      final response = await DatabaseService.signUp(technicalEmail, password);
      
      if (response.user == null) {
        throw Exception('Impossible de créer le compte');
      }
      
      print('✅ Compte créé - User ID: ${response.user!.id}');
      
      // 2. Se connecter immédiatement
      await DatabaseService.signIn(technicalEmail, password);
      print('✅ Connexion réussie');
      
      // 3. VÉRIFIER LE RÔLE D'ABORD (Avant de créer un profil inutile)
      await Future.delayed(const Duration(milliseconds: 500)); // Attente propagation
      final userRole = await DatabaseService.getUserRole();
      print('🎭 Rôle détecté après connexion: $userRole');

      if (userRole == 'admin') {
        print('👑 ADMIN IDENTIFIÉ - Redirection immédiate');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('👑 Bienvenue Admin !'),
              backgroundColor: Colors.blueAccent,
            ),
          );
          // Redirection DIRECTE vers le Dashboard (pas le login)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
            (route) => false,
          );
          return; // STOP ICI
        }
      }

      // Si pas admin, continuer la procédure normale
      
      // 4. IMPORTANT : Attendre que le trigger Supabase crée le profil patient automatiquement
      await Future.delayed(const Duration(seconds: 1));
      
      // 5. Si c'est un chauffeur, créer AUSSI le profil chauffeur
      if (isDriver) {
        print('🚗 Création du profil chauffeur...');
        await DatabaseService.createDriverProfile(
          firstName: 'Chauffeur',
          lastName: phone,
          nationalId: 'TEMP_$phone', // ID temporaire
        );
        print('✅ Profil chauffeur créé');
      }
      // Le profil patient est créé automatiquement par le trigger SQL
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bienvenue ! Profil ${isDriver ? "chauffeur" : "patient"} créé'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Naviguer vers la sélection du type de transport (Urgent / Non-Urgent)
        await Future.delayed(const Duration(milliseconds: 500));
        
        final role = isDriver ? 'driver' : 'patient';
        Navigator.pushReplacementNamed(
          context, 
          '/transport-selection',
          arguments: {'role': role},
        );
      }
      
    } catch (e) {
      print('❌ Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// ============================================
// DASHBOARD PATIENT (SIMPLIFIÉ)
// ============================================
class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Patient'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Color(0xFF4CAF50)),
            const SizedBox(height: 20),
            const Text(
              '✅ Profil Patient Créé !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Vous pouvez maintenant commander un transport'),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigation vers page de commande
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📍 Commande de transport - À implémenter')),
                );
              },
              icon: const Icon(Icons.local_hospital),
              label: const Text('Commander un Transport'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// DASHBOARD CHAUFFEUR (SIMPLIFIÉ)
// ============================================
class DriverDashboard extends StatelessWidget {
  final String phone;
  
  const DriverDashboard({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Chauffeur'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.drive_eta, size: 80, color: Color(0xFF2E7D32)),
            const SizedBox(height: 20),
            const Text(
              '✅ Profil Chauffeur Créé !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Vous pouvez maintenant accepter des courses'),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigation vers liste des courses
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🚗 Liste des courses - À implémenter')),
                );
              },
              icon: const Icon(Icons.list),
              label: const Text('Voir les Courses Disponibles'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
