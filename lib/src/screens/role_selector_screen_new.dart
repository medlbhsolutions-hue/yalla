import 'package:flutter/material.dart';
import '../../patient_dashboard_improved.dart' as patient_dash;
import 'driver_dashboard_real.dart';
import '../services/role_detection_service.dart';

/// Page professionnelle de sélection de rôle (Patient ou Chauffeur)
class RoleSelectorScreenNew extends StatelessWidget {
  const RoleSelectorScreenNew({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Logo et titre
              Center(
                child: Column(
                  children: [
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        size: 40,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Titre
                    const Text(
                      'Bienvenue sur YALLA L\'TBIB',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    Text(
                      'Choisissez votre profil pour continuer',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Carte Patient
              _buildRoleCard(
                context: context,
                title: 'Patient',
                subtitle: 'Je cherche un transport médical',
                icon: Icons.local_hospital_rounded,
                color: const Color(0xFF4CAF50),
                lightColor: const Color(0xFFE8F5E9),
                onTap: () async {
                  // Récupérer ou créer le patient profile
                  var patientProfile = await RoleDetectionService.getPatientProfile();
                  
                  // Si le profil n'existe pas, le créer
                  if (patientProfile == null) {
                    print('⚠️ Profil patient inexistant, création en cours...');
                    patientProfile = await RoleDetectionService.createPatientProfile();
                  }
                  
                  if (patientProfile != null && context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const patient_dash.PatientDashboard(),
                      ),
                    );
                  } else if (context.mounted) {
                    // Afficher une erreur si la création échoue
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Erreur lors de la création du profil patient'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 20),

              // Carte Chauffeur
              _buildRoleCard(
                context: context,
                title: 'Chauffeur',
                subtitle: 'Je transporte des patients',
                icon: Icons.local_taxi_rounded,
                color: const Color(0xFF2196F3),
                lightColor: const Color(0xFFE3F2FD),
                onTap: () async {
                  // Récupérer ou créer le driver profile
                  var driverProfile = await RoleDetectionService.getDriverProfile();
                  
                  // Si le profil n'existe pas, le créer
                  if (driverProfile == null) {
                    print('⚠️ Profil chauffeur inexistant, création en cours...');
                    driverProfile = await RoleDetectionService.createDriverProfile();
                  }
                  
                  if (driverProfile != null && context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverDashboardReal(
                          driverId: driverProfile!['id'] as String,
                        ),
                      ),
                    );
                  } else if (context.mounted) {
                    // Afficher une erreur si la création échoue
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Erreur lors de la création du profil chauffeur'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),

              const Spacer(),

              // Note en bas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Vous pourrez changer de profil à tout moment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color lightColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 36,
                color: color,
              ),
            ),

            const SizedBox(width: 20),

            // Textes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Flèche
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
