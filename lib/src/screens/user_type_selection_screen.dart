import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Écran de sélection du type d'utilisateur après authentification
class UserTypeSelectionScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isSimulationMode;
  final String? firebaseUid; // ID Firebase pour le mode production
  
  const UserTypeSelectionScreen({
    super.key,
    required this.phoneNumber,
    this.isSimulationMode = false,
    this.firebaseUid, // Optionnel, utilisé uniquement en mode production
  });

  @override
  State<UserTypeSelectionScreen> createState() => _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> {
  bool _isLoading = false;

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
                  
                  const SizedBox(height: 60),
                  
                  // Message de bienvenue
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Téléphone Vérifié !',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.phoneNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Question
                  const Text(
                    'Vous êtes :',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Bouton Patient
                  _buildUserTypeButton(
                    icon: Icons.person,
                    title: 'PATIENT',
                    subtitle: 'Je cherche un transport médical',
                    color: Colors.white,
                    textColor: const Color(0xFF4CAF50),
                    onTap: () => _selectUserType(isDriver: false),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bouton Chauffeur
                  _buildUserTypeButton(
                    icon: Icons.local_taxi,
                    title: 'CHAUFFEUR',
                    subtitle: 'Je fournis des transports médicaux',
                    color: const Color(0xFF2E7D32),
                    textColor: Colors.white,
                    onTap: () => _selectUserType(isDriver: true),
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

  Widget _buildUserTypeButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 48, color: textColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: textColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _selectUserType({required bool isDriver}) async {
    setState(() => _isLoading = true);
    
    try {
      // MODE SIMULATION : Skip la création du profil Supabase
      if (widget.isSimulationMode) {
        print('');
        print('🧪 ═══════════════════════════════════════');
        print('🧪 MODE SIMULATION - PROFIL NON CRÉÉ');
        print('🧪 ═══════════════════════════════════════');
        print('🧪 Type: ${isDriver ? "CHAUFFEUR" : "PATIENT"}');
        print('🧪 Navigation vers dashboard simulé...');
        print('🧪 ═══════════════════════════════════════');
        print('');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🧪 Mode Simulation - ${isDriver ? "Chauffeur" : "Patient"} sélectionné'),
              backgroundColor: Colors.orange,
            ),
          );
          
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            if (isDriver) {
              Navigator.pushReplacementNamed(context, '/driver-dashboard');
            } else {
              Navigator.pushReplacementNamed(context, '/patient-dashboard');
            }
          }
        }
        return;
      }
      
      // MODE PRODUCTION : Créer le profil dans Supabase
      // Extraire les chiffres du numéro (sans +212)
      final phoneDigits = widget.phoneNumber.replaceAll('+212', '0');
      
      if (isDriver) {
        print('🚗 Création du profil chauffeur...');
        await DatabaseService.createDriverProfile(
          firstName: 'Chauffeur',
          lastName: phoneDigits,
          nationalId: 'TEMP_$phoneDigits',
        );
        print('✅ Profil chauffeur créé');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profil chauffeur créé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          
          // TODO: Navigation vers DriverDashboard
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/driver-dashboard');
          }
        }
      } else {
        print('🏥 Création du profil patient...');
        await DatabaseService.createPatientProfile(
          firstName: 'Patient',
          lastName: phoneDigits,
        );
        print('✅ Profil patient créé');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profil patient créé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          
          // TODO: Navigation vers PatientDashboard
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/patient-dashboard');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur création profil: $e');
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
