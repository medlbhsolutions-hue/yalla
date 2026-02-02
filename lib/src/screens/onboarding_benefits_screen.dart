import 'package:flutter/material.dart';
import 'onboarding_user_type_screen.dart';

/// Deuxième écran d'onboarding - Avantages du service
class OnboardingBenefitsScreen extends StatelessWidget {
  const OnboardingBenefitsScreen({Key? key}) : super(key: key);

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
                'Pourquoi YALLA L\'TBIB ?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Liste des avantages
              Expanded(
                child: ListView(
                  children: [
                    _buildBenefitCard(
                      icon: Icons.speed,
                      color: Colors.red,
                      title: 'Rapide et Efficace',
                      description: 'Trouvez un chauffeur médical en quelques secondes, disponible 24h/24',
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildBenefitCard(
                      icon: Icons.verified_user,
                      color: const Color(0xFF4CAF50),
                      title: 'Sécurisé et Professionnel',
                      description: 'Chauffeurs qualifiés et véhicules équipés pour le transport médical',
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildBenefitCard(
                      icon: Icons.location_on,
                      color: Colors.blue,
                      title: 'Suivi en Temps Réel',
                      description: 'Suivez votre trajet en direct sur la carte GPS',
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildBenefitCard(
                      icon: Icons.payment,
                      color: Colors.orange,
                      title: 'Tarifs Transparents',
                      description: 'Prix fixés à l\'avance, sans surprise',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Indicateurs de pagination
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(false),
                  const SizedBox(width: 8),
                  _buildDot(true),
                  const SizedBox(width: 8),
                  _buildDot(false),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Bouton Suivant
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnboardingUserTypeScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Suivant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
