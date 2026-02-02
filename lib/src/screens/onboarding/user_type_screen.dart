import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class UserTypeSelectionScreen extends StatelessWidget {
  final String email;
  final String password;
  final String name;
  final String phone;

  const UserTypeSelectionScreen({
    super.key,
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir votre profil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTypeCard(
              context,
              'Patient',
              Icons.person,
              Colors.blue,
              () => _handleSignUp(context, 'patient'),
            ),
            const SizedBox(height: 20),
            _buildTypeCard(
              context,
              'Chauffeur',
              Icons.drive_eta,
              Colors.green,
              () => _handleSignUp(context, 'driver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(icon, size: 50, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignUp(BuildContext context, String userType) async {
    try {
      // Inscription
      final response = await DatabaseService.signUpWithEmail(
        email: email,
        password: password,
        metadata: {'user_type': userType},
      );

      if (response.user != null) {
        // Créer le profil utilisateur
        await DatabaseService.createUserProfile(
          userId: response.user!.id,
          email: email,
          name: name,
          phone: phone,
          userType: userType,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte créé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );

          // Redirection selon le type
          if (userType == 'patient') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PatientDashboard()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverDashboard()),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}