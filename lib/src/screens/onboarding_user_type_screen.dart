import 'package:flutter/material.dart';
import 'user_type_selection_screen.dart';

/// Troisième écran d'onboarding - Choix du type d'utilisateur
class OnboardingUserTypeScreen extends StatelessWidget {
  const OnboardingUserTypeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Bouton retour
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Titre
              const Text(
                'Vous êtes ?',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              const Text(
                'Choisissez votre profil pour continuer',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
              
              // Carte Patient
              _buildUserTypeCard(
                context: context,
                icon: Icons.person,
                title: 'Patient',
                description: 'J\'ai besoin d\'un transport médical',
                color: const Color(0xFF4CAF50),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                userType: 'patient',
              ),
              
              const SizedBox(height: 24),
              
              // Carte Chauffeur
              _buildUserTypeCard(
                context: context,
                icon: Icons.local_taxi,
                title: 'Chauffeur',
                description: 'Je veux devenir chauffeur médical',
                color: const Color(0xFF2196F3),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                userType: 'driver',
              ),
              
              const Spacer(),
              
              // Indicateurs de pagination
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(false),
                  const SizedBox(width: 8),
                  _buildDot(false),
                  const SizedBox(width: 8),
                  _buildDot(true),
                ],
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Gradient gradient,
    required String userType,
  }) {
    return GestureDetector(
      onTap: () {
        // Navigation vers UserTypeSelectionScreen
        // Note: Pour l'instant on utilise un numéro simulé
        // Dans une vraie appli, il faudrait passer le vrai numéro depuis l'authentification
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => UserTypeSelectionScreen(
              phoneNumber: '+212 6XX XXX XXX', // Placeholder
              isSimulationMode: true,
            ),
          ),
          (route) => false,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 60,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continuer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4CAF50) : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
