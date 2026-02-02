import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/role_detection_service.dart';
import '../utils/app_colors.dart';
import '../../patient_dashboard_improved.dart' as patient_dash;
import '../../driver_dashboard_improved.dart' as driver_dash;
import 'role_selector_screen_new.dart';
import 'onboarding_screens.dart';
import 'first_time_role_selection_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🎨 Écran de chargement Yalla Tbib avec logo
class AppLoaderScreen extends StatefulWidget {
  const AppLoaderScreen({super.key});

  @override
  State<AppLoaderScreen> createState() => _AppLoaderScreenState();
}

class _AppLoaderScreenState extends State<AppLoaderScreen> {
  @override
  void initState() {
    super.initState();
    _detectAndNavigate();
  }

  Future<void> _detectAndNavigate() async {
    // Attendre un peu pour l'animation de chargement
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Vérifier si l'utilisateur est connecté
      final currentUser = DatabaseService.currentUser;
      
      if (currentUser == null) {
        // Pas connecté → Écran de connexion
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
        return;
      }

      print('✅ Utilisateur connecté: ${currentUser.id}');

      // Détecter le rôle de l'utilisateur
      final role = await RoleDetectionService.detectUserRole();

      print('🎭 Rôle détecté: $role');

      if (!mounted) return;

      // Rediriger selon le rôle
      switch (role) {
        case 'admin':
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
          break;

        case 'patient':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const patient_dash.PatientDashboard()),
          );
          break;

        case 'driver':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const driver_dash.DriverDashboard(),
            ),
          );
          break;

        case 'both':
          // Utilisateur avec les 2 rôles → Choix
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RoleSelectorScreenNew()),
          );
          break;

        default:
          // Aucun profil trouvé → Première connexion, laisser l'utilisateur choisir
          print('⚠️ Aucun profil trouvé, première inscription → Sélection de rôle');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FirstTimeRoleSelectionScreen()),
          );
      }
    } catch (e) {
      print('❌ Erreur détection: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Yalla Tbib
            Image.asset(
              'assets/images/logo_yalla_tbib.png',
              height: 320,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    size: 70,
                    color: AppColors.primary,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 48),
            
            // Indicateur de chargement
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          
            const SizedBox(height: 16),
            
            const Text(
              'Chargement...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
