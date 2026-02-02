import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/database_service.dart'; // ✅ Pour obtenir le driver ID

/// 🚑 Écran de sélection du type de transport
/// Patient et Chauffeur choisissent: Transport Urgent ou Non-Urgent
class TransportTypeSelectionScreen extends StatelessWidget {
  final String userRole; // 'patient' ou 'driver'
  
  const TransportTypeSelectionScreen({
    Key? key,
    required this.userRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isPatient = userRole == 'patient';
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                
                // Titre
                Text(
                  isPatient 
                    ? 'De quel type de transport avez-vous besoin ?' 
                    : 'Quel type de transport proposez-vous ?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                
                Text(
                  'Sélectionnez les services que vous offrez',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Carte Transport Urgent
                _buildTransportCard(
                  context: context,
                  title: 'Transport Urgent',
                  description: isPatient
                    ? 'Ambulance équipée\nIntervention d\'urgence\nPriorité maximale'
                    : 'Ambulance équipée\nIntervention d\'urgence\nPriorité maximale',
                  color: AppColors.urgentColor,
                  isUrgent: true,
                  icon: Icons.emergency,
                ),
                
                const SizedBox(height: 20),
                
                // Carte Transport Non-Urgent
                _buildTransportCard(
                  context: context,
                  title: 'Transport médical standard',
                  description: isPatient
                    ? 'Rendez-vous médical\nConsultation\nExamens de routine'
                    : 'Transport médical standard\nRendez-vous planifiés\nConfort assuré',
                  color: AppColors.primary,
                  isUrgent: false,
                  icon: Icons.local_hospital,
                ),
                
                const SizedBox(height: 40),
                
                // Bouton Retour
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  label: const Text(
                    'Retour',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                  
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportCard({
    required BuildContext context,
    required String title,
    required String description,
    required Color color,
    required bool isUrgent,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () async {
        // Navigation selon le rôle et le type choisi
        if (userRole == 'patient') {
          // ✅ Pour le patient, obtenir ou créer son profil
          var patientProfile = await DatabaseService.getPatientProfile();
          
          // Si pas de profil, le créer automatiquement
          if (patientProfile == null) {
            try {
              print('📝 Création automatique du profil patient...');
              patientProfile = await DatabaseService.createPatientProfile(
                firstName: 'Patient',
                lastName: 'Nouveau',
                dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 30)),
                emergencyContactName: 'Contact',
                emergencyContactPhone: '+212600000000',
                medicalConditions: [],
              );
              print('✅ Profil patient créé automatiquement: ${patientProfile['id']}');
            } catch (e) {
              print('❌ Erreur création profil patient: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ Erreur création profil: ${e.toString()}')),
              );
              return;
            }
          }
          
          Navigator.pushReplacementNamed(
            context,
            '/patient-dashboard',
            arguments: {'transportType': isUrgent ? 'urgent' : 'non-urgent'},
          );
        } else {
          // ✅ Pour le chauffeur, obtenir ou créer son profil driver
          var driverProfile = await DatabaseService.getDriverProfile();
          
          // Si pas de profil, le créer automatiquement
          if (driverProfile == null) {
            try {
              print('📝 Création automatique du profil chauffeur...');
              driverProfile = await DatabaseService.createDriverProfile(
                firstName: 'Chauffeur',
                lastName: 'Nouveau',
                nationalId: 'AUTO-${DateTime.now().millisecondsSinceEpoch}',
                dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 30)),
                address: 'Casablanca',
                city: 'Casablanca',
                specializations: ['medical'], // ✅ Valeur correcte de l'enum
              );
              print('✅ Profil chauffeur créé automatiquement: ${driverProfile['id']}');
            } catch (e) {
              print('❌ Erreur création profil chauffeur: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ Erreur création profil: ${e.toString()}')),
              );
              return;
            }
          }
          
          if (driverProfile != null && driverProfile['id'] != null) {
            Navigator.pushReplacementNamed(
              context,
              '/driver-dashboard',
              arguments: {
                'driverId': driverProfile['id'],
                'transportType': isUrgent ? 'urgent' : 'non-urgent'
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ Erreur : Profil chauffeur introuvable')),
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icône
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            
            // Titre
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            
            // Badge si urgent
            if (isUrgent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.urgentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PRIORITÉ MAXIMALE',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'CONFORT ET SÉCURITÉ',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
