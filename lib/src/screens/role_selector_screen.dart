import 'package:flutter/material.dart';
import '../../patient_dashboard_improved.dart' as patient_dash;
import 'driver_dashboard_real.dart';
import '../services/role_detection_service.dart';

/// Écran de sélection de rôle (si l'utilisateur a les 2 profils)
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Choisir votre rôle'),
        backgroundColor: const Color(0xFF00B894),
        elevation: 0,
        automaticallyImplyLeading: false, // Pas de bouton retour
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_pin,
                size: 100,
                color: Color(0xFF00B894),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Vous avez 2 profils',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Choisissez comment vous voulez continuer',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Bouton Patient
              SizedBox(
                width: double.infinity,
                height: 120,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const patient_dash.PatientDashboard(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B894),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_hospital, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Je suis Patient',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Demander une course',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Bouton Chauffeur
              SizedBox(
                width: double.infinity,
                height: 120,
                child: ElevatedButton(
                  onPressed: () async {
                    // Récupérer le driver profile
                    final driverProfile = await RoleDetectionService.getDriverProfile();
                    if (driverProfile != null && context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DriverDashboardReal(
                            driverId: driverProfile['id'] as String,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0984E3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_taxi, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Je suis Chauffeur',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Accepter des courses',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
