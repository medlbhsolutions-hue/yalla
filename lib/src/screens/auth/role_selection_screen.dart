import 'package:flutter/material.dart';
import '../../services/auth_service_complete.dart';

/// Écran de sélection du rôle (Patient, Chauffeur, Admin)
class RoleSelectionScreen extends StatefulWidget {
  final String userId;

  const RoleSelectionScreen({
    super.key,
    required this.userId,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() {
      _selectedRole = role;
      _isLoading = true;
    });

    try {
      final result = await AuthServiceComplete.setUserRole(
        userId: widget.userId,
        role: role,
      );

      if (!mounted) return;

      if (result['success']) {
        _showSuccess('Rôle sélectionné avec succès !');
        
        // Attendre un peu
        await Future.delayed(const Duration(seconds: 1));
        
        if (!mounted) return;
        
        final profileId = result['id'];

        // Naviguer vers la sélection du type de transport (Urgent / Non-Urgent)
        Navigator.pushReplacementNamed(
          context, 
          '/transport-selection',
          arguments: {'role': role},
        );
      } else {
        _showError('Erreur lors de la sélection du rôle');
        setState(() {
          _selectedRole = null;
        });
      }
    } catch (e) {
      _showError('Erreur: $e');
      setState(() {
        _selectedRole = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Titre
              const Text(
                'Qui êtes-vous ?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Sélectionnez votre type de compte pour continuer',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Card Patient
              _buildRoleCard(
                role: 'patient',
                title: 'JE SUIS PATIENT',
                description: 'J\'ai besoin d\'un transport médical',
                icon: Icons.person,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Card Chauffeur
              _buildRoleCard(
                role: 'driver',
                title: 'JE SUIS CHAUFFEUR',
                description: 'Je propose des services de transport médical',
                icon: Icons.local_taxi,
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[700]!],
                ),
              ),
              
              const Spacer(),
              
              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vous pourrez modifier votre choix plus tard dans les paramètres',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
    required Gradient gradient,
  }) {
    final isSelected = _selectedRole == role;
    final isLoading = _isLoading && isSelected;

    return GestureDetector(
      onTap: _isLoading ? null : () => _selectRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFF4CAF50),
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              )
            : Column(
                children: [
                  Icon(
                    icon,
                    size: 60,
                    color: isSelected ? Colors.white : const Color(0xFF4CAF50),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? Colors.white70 : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
