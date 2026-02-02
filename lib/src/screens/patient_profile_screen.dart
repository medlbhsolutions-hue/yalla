import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';

/// Écran de profil complet - Afficher et modifier les informations patient
class PatientProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? patientProfile;

  const PatientProfileScreen({Key? key, this.patientProfile}) : super(key: key);

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isEditing = false;
  bool _isSaving = false;
  
  // Controllers pour les champs
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    // Si le profil est passé en paramètre, l'utiliser
    if (widget.patientProfile != null) {
      _fillFormWithData(widget.patientProfile!);
    } else {
      // Sinon, charger depuis la base de données
      try {
        final profile = await DatabaseService.getPatientProfile();
        if (profile != null && mounted) {
          _fillFormWithData(profile);
        }
      } catch (e) {
        print('[ERROR] Erreur chargement profil patient: $e');
      }
    }
  }

  void _fillFormWithData(Map<String, dynamic> profile) {
    _firstNameController.text = profile['first_name'] ?? '';
    _lastNameController.text = profile['last_name'] ?? '';
    _phoneController.text = profile['phone_number'] ?? '';
    _emergencyContactNameController.text = profile['emergency_contact_name'] ?? '';
    _emergencyContactPhoneController.text = profile['emergency_contact_phone'] ?? '';
    
    // ✅ FIX: Gérer medical_conditions qui peut être une List ou une String
    final medicalConditions = profile['medical_conditions'];
    if (medicalConditions is List) {
      _medicalConditionsController.text = medicalConditions.join(', ');
    } else if (medicalConditions is String) {
      _medicalConditionsController.text = medicalConditions;
    } else {
      _medicalConditionsController.text = '';
    }
    
    // ✅ FIX: Gérer allergies qui peut être une List ou une String
    final allergies = profile['allergies'];
    if (allergies is List) {
      _allergiesController.text = allergies.join(', ');
    } else if (allergies is String) {
      _allergiesController.text = allergies;
    } else {
      _allergiesController.text = '';
    }
    
    _notesController.text = profile['notes'] ?? '';
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _medicalConditionsController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isSaving = true; });
    
    try {
      final updatedData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'emergency_contact_name': _emergencyContactNameController.text.trim(),
        'emergency_contact_phone': _emergencyContactPhoneController.text.trim(),
        // ✅ FIX: Convertir les String en List pour correspondre au schéma DB
        'medical_conditions': _medicalConditionsController.text.trim().isEmpty 
            ? [] 
            : _medicalConditionsController.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'allergies': _allergiesController.text.trim().isEmpty 
            ? [] 
            : _allergiesController.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'notes': _notesController.text.trim(),
      };
      
      await DatabaseService.updatePatientProfile(updatedData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profil mis à jour avec succès'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mon Profil',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF4CAF50)),
              onPressed: () => setState(() { _isEditing = true; }),
            )
          else
            TextButton(
              onPressed: () {
                setState(() { _isEditing = false; });
                _loadProfileData(); // Reset changes
              },
              child: const Text('Annuler', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo de profil (placeholder)
            _buildProfilePhoto(),
            
            const SizedBox(height: 24),
            
            // Informations personnelles
            _buildSection(
              title: 'Informations personnelles',
              icon: Icons.person,
              children: [
                _buildTextField(
                  controller: _firstNameController,
                  label: 'Prénom',
                  icon: Icons.person_outline,
                  enabled: _isEditing,
                  validator: (val) => val?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _lastNameController,
                  label: 'Nom',
                  icon: Icons.person_outline,
                  enabled: _isEditing,
                  validator: (val) => val?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Téléphone',
                  icon: Icons.phone,
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val?.isEmpty ?? true ? 'Requis' : null,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Contact d'urgence
            _buildSection(
              title: 'Contact d\'urgence',
              icon: Icons.emergency,
              children: [
                _buildTextField(
                  controller: _emergencyContactNameController,
                  label: 'Nom du contact',
                  icon: Icons.person,
                  enabled: _isEditing,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _emergencyContactPhoneController,
                  label: 'Téléphone',
                  icon: Icons.phone,
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Informations médicales
            _buildSection(
              title: 'Informations médicales',
              icon: Icons.medical_services,
              children: [
                _buildTextField(
                  controller: _medicalConditionsController,
                  label: 'Conditions médicales',
                  icon: Icons.local_hospital,
                  enabled: _isEditing,
                  maxLines: 3,
                  hint: 'Ex: Diabète, hypertension...',
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _allergiesController,
                  label: 'Allergies',
                  icon: Icons.warning_amber,
                  enabled: _isEditing,
                  maxLines: 2,
                  hint: 'Ex: Pénicilline, arachides...',
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _notesController,
                  label: 'Notes supplémentaires',
                  icon: Icons.note,
                  enabled: _isEditing,
                  maxLines: 3,
                  hint: 'Informations utiles pour les chauffeurs',
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Bouton de sauvegarde
            if (_isEditing)
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Enregistrer les modifications',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
            child: const Icon(
              Icons.person,
              size: 80,
              color: Color(0xFF4CAF50),
            ),
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4CAF50), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: enabled ? Colors.black : Colors.grey[700],
        fontWeight: enabled ? FontWeight.normal : FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
        filled: true,
        fillColor: enabled ? Colors.grey[100] : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
