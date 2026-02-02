import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/role_detection_service.dart';
import '../utils/app_colors.dart';
import 'transport_type_selection_screen.dart'; // 🚑 Nouveau : Choix transport
import '../../patient_dashboard_improved.dart' as patient_dash;
import '../../driver_dashboard_improved.dart' as driver_dash;

/// 🎨 Écran Yalla Tbib de sélection de rôle
/// Patient ou Chauffeur avec fond bleu #467db0
class FirstTimeRoleSelectionScreen extends StatelessWidget {
  const FirstTimeRoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, String role) async {
    // Navigation vers la page de choix de transport
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransportTypeSelectionScreen(userRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 10),
              
              // Logo Yalla Tbib - Grand et centré
              Center(
                child: Image.asset(
                  'assets/images/logo_yalla_tbib.png',
                  height: 320,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 10),
              
              Text(
                'Choisissez votre profil pour continuer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
                
                // Carte Patient
                _buildRoleCard(
                  context: context,
                  icon: Icons.local_hospital,
                  title: 'Patient',
                  description: 'Je cherche un transport\nmédical',
                  backgroundColor: const Color(0xFFE8F5E9),
                  iconColor: const Color(0xFF4CAF50),
                  titleColor: const Color(0xFF2E7D32),
                  onTap: () => _selectRole(context, 'patient'),
                ),
                
                const SizedBox(height: 20),
                
                // Carte Chauffeur
                _buildRoleCard(
                context: context,
                icon: Icons.local_taxi,
                title: 'Chauffeur',
                description: 'Je transporte des patients',
                backgroundColor: const Color(0xFFE3F2FD),
                iconColor: const Color(0xFF2196F3),
                titleColor: const Color(0xFF1565C0),
                  onTap: () => _selectRole(context, 'driver'),
                ),
              
              const Spacer(),
              
              // Note
             /*  Text(
                'Vous pourrez changer de profil à tout moment',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ), */
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color backgroundColor,
    required Color iconColor,
    required Color titleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.black26,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
