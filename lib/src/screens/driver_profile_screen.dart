import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';

/// Écran de profil chauffeur complet - Afficher et modifier les informations
class DriverProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? driverProfile;

  const DriverProfileScreen({Key? key, this.driverProfile}) : super(key: key);

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isEditing = false;
  bool _isSaving = false;
  
  // Controllers pour les champs chauffeur
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _licenseExpiryController = TextEditingController();
  
  // Controllers pour le véhicule
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehicleCapacityController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    // Si le profil est passé en paramètre, l'utiliser
    if (widget.driverProfile != null) {
      _fillFormWithData(widget.driverProfile!);
    } else {
      // Sinon, charger depuis la base de données
      try {
        final profile = await DatabaseService.getDriverProfile();
        if (profile != null && mounted) {
          _fillFormWithData(profile);
        }
      } catch (e) {
        print('[ERROR] Erreur chargement profil driver: $e');
      }
    }
  }

  void _fillFormWithData(Map<String, dynamic> profile) {
    _firstNameController.text = profile['first_name'] ?? '';
    _lastNameController.text = profile['last_name'] ?? '';
    _phoneController.text = profile['phone_number'] ?? '';
    _licenseNumberController.text = profile['license_number'] ?? '';
    _licenseExpiryController.text = profile['license_expiry_date'] ?? '';
    
    _vehicleBrandController.text = profile['vehicle_brand'] ?? '';
    _vehicleModelController.text = profile['vehicle_model'] ?? '';
    _vehiclePlateController.text = profile['vehicle_plate_number'] ?? '';
    _vehicleYearController.text = profile['vehicle_year']?.toString() ?? '';
    _vehicleColorController.text = profile['vehicle_color'] ?? '';
    _vehicleCapacityController.text = profile['vehicle_capacity']?.toString() ?? '';
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _vehicleCapacityController.dispose();
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
        'license_number': _licenseNumberController.text.trim(),
        'license_expiry_date': _licenseExpiryController.text.trim(),
        'vehicle_brand': _vehicleBrandController.text.trim(),
        'vehicle_model': _vehicleModelController.text.trim(),
        'vehicle_plate_number': _vehiclePlateController.text.trim(),
        'vehicle_year': int.tryParse(_vehicleYearController.text.trim()),
        'vehicle_color': _vehicleColorController.text.trim(),
        'vehicle_capacity': int.tryParse(_vehicleCapacityController.text.trim()),
      };
      
      await DatabaseService.updateDriverProfile(updatedData);
      
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
          'Mon Profil Chauffeur',
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
            
            // Permis de conduire
            _buildSection(
              title: 'Permis de conduire',
              icon: Icons.badge,
              children: [
                _buildTextField(
                  controller: _licenseNumberController,
                  label: 'Numéro de permis',
                  icon: Icons.credit_card,
                  enabled: _isEditing,
                  validator: (val) => val?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _licenseExpiryController,
                  label: 'Date d\'expiration (JJ/MM/AAAA)',
                  icon: Icons.calendar_today,
                  enabled: _isEditing,
                  hint: '31/12/2025',
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Informations véhicule
            _buildSection(
              title: 'Informations du véhicule',
              icon: Icons.directions_car,
              children: [
                _buildTextField(
                  controller: _vehicleBrandController,
                  label: 'Marque',
                  icon: Icons.local_offer,
                  enabled: _isEditing,
                  hint: 'Dacia, Renault, Peugeot...',
                  validator: (val) => val?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _vehicleModelController,
                  label: 'Modèle',
                  icon: Icons.local_offer,
                  enabled: _isEditing,
                  hint: 'Logan, Clio, 208...',
                  validator: (val) => val?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _vehiclePlateController,
                  label: 'Immatriculation',
                  icon: Icons.pin,
                  enabled: _isEditing,
                  hint: '12345-أ-67',
                  validator: (val) => val?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _vehicleYearController,
                        label: 'Année',
                        icon: Icons.calendar_today,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        hint: '2020',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _vehicleCapacityController,
                        label: 'Capacité',
                        icon: Icons.people,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        hint: '4 places',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _vehicleColorController,
                  label: 'Couleur',
                  icon: Icons.palette,
                  enabled: _isEditing,
                  hint: 'Blanc, Noir, Gris...',
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
              Icons.local_taxi,
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
