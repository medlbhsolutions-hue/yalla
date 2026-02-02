import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';

/// Écran de profil patient COMPLET avec toutes les informations
/// Sections: Personnel, Médical, Contacts Urgence, Assurance
class PatientProfileCompleteScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProfile;
  
  const PatientProfileCompleteScreen({
    Key? key,
    this.existingProfile,
  }) : super(key: key);

  @override
  State<PatientProfileCompleteScreen> createState() => _PatientProfileCompleteScreenState();
}

class _PatientProfileCompleteScreenState extends State<PatientProfileCompleteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  
  // SECTION 1: Informations Personnelles
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _dateOfBirth;
  String _gender = 'male';
  
  // SECTION 2: Informations Médicales
  final _allergiesController = TextEditingController();
  final _chronicDiseasesController = TextEditingController();
  final _medicationsController = TextEditingController();
  String? _bloodGroup;
  final _medicalNotesController = TextEditingController();
  
  // SECTION 3: Contacts d'Urgence (2 contacts)
  final _emergency1NameController = TextEditingController();
  final _emergency1PhoneController = TextEditingController();
  final _emergency1RelationController = TextEditingController();
  
  final _emergency2NameController = TextEditingController();
  final _emergency2PhoneController = TextEditingController();
  final _emergency2RelationController = TextEditingController();
  
  // SECTION 4: Assurance
  final _insuranceNumberController = TextEditingController();
  final _insuranceCompanyController = TextEditingController();
  DateTime? _insuranceExpiryDate;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    if (widget.existingProfile != null) {
      final profile = widget.existingProfile!;
      
      // Section 1: Personnel
      _firstNameController.text = profile['first_name'] ?? '';
      _lastNameController.text = profile['last_name'] ?? '';
      _phoneController.text = profile['phone'] ?? '';
      _emailController.text = profile['email'] ?? '';
      _addressController.text = profile['address'] ?? '';
      _gender = profile['gender'] ?? 'male';
      
      if (profile['date_of_birth'] != null) {
        _dateOfBirth = DateTime.tryParse(profile['date_of_birth']);
      }
      
      // Section 2: Médical
      _allergiesController.text = profile['allergies'] ?? '';
      _chronicDiseasesController.text = profile['chronic_diseases'] ?? '';
      _medicationsController.text = profile['current_medications'] ?? '';
      _bloodGroup = profile['blood_group'];
      _medicalNotesController.text = profile['medical_notes'] ?? '';
      
      // Section 3: Contacts Urgence
      _emergency1NameController.text = profile['emergency_contact_1_name'] ?? '';
      _emergency1PhoneController.text = profile['emergency_contact_1_phone'] ?? '';
      _emergency1RelationController.text = profile['emergency_contact_1_relation'] ?? '';
      
      _emergency2NameController.text = profile['emergency_contact_2_name'] ?? '';
      _emergency2PhoneController.text = profile['emergency_contact_2_phone'] ?? '';
      _emergency2RelationController.text = profile['emergency_contact_2_relation'] ?? '';
      
      // Section 4: Assurance
      _insuranceNumberController.text = profile['insurance_number'] ?? '';
      _insuranceCompanyController.text = profile['insurance_company'] ?? '';
      
      if (profile['insurance_expiry_date'] != null) {
        _insuranceExpiryDate = DateTime.tryParse(profile['insurance_expiry_date']);
      }
    }
  }

  @override
  void dispose() {
    // Dispose tous les controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _allergiesController.dispose();
    _chronicDiseasesController.dispose();
    _medicationsController.dispose();
    _medicalNotesController.dispose();
    _emergency1NameController.dispose();
    _emergency1PhoneController.dispose();
    _emergency1RelationController.dispose();
    _emergency2NameController.dispose();
    _emergency2PhoneController.dispose();
    _emergency2RelationController.dispose();
    _insuranceNumberController.dispose();
    _insuranceCompanyController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final profileData = {
        'user_id': userId,
        // Section 1: Personnel
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'date_of_birth': _dateOfBirth?.toIso8601String(),
        'gender': _gender,
        
        // Section 2: Médical
        'allergies': _allergiesController.text.trim(),
        'chronic_diseases': _chronicDiseasesController.text.trim(),
        'current_medications': _medicationsController.text.trim(),
        'blood_group': _bloodGroup,
        'medical_notes': _medicalNotesController.text.trim(),
        
        // Section 3: Contacts Urgence
        'emergency_contact_1_name': _emergency1NameController.text.trim(),
        'emergency_contact_1_phone': _emergency1PhoneController.text.trim(),
        'emergency_contact_1_relation': _emergency1RelationController.text.trim(),
        'emergency_contact_2_name': _emergency2NameController.text.trim(),
        'emergency_contact_2_phone': _emergency2PhoneController.text.trim(),
        'emergency_contact_2_relation': _emergency2RelationController.text.trim(),
        
        // Section 4: Assurance
        'insurance_number': _insuranceNumberController.text.trim(),
        'insurance_company': _insuranceCompanyController.text.trim(),
        'insurance_expiry_date': _insuranceExpiryDate?.toIso8601String(),
        
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await DatabaseService.updatePatientProfile(profileData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profil enregistré avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      print('❌ Erreur sauvegarde profil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil Complet'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // SECTION 1: Informations Personnelles
            _buildSectionHeader('📋 Informations Personnelles', Icons.person),
            _buildTextField(
              controller: _firstNameController,
              label: 'Prénom',
              icon: Icons.person_outline,
              required: true,
            ),
            _buildTextField(
              controller: _lastNameController,
              label: 'Nom',
              icon: Icons.person_outline,
              required: true,
            ),
            _buildTextField(
              controller: _phoneController,
              label: 'Téléphone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              required: true,
            ),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              required: true,
            ),
            _buildTextField(
              controller: _addressController,
              label: 'Adresse',
              icon: Icons.home,
              maxLines: 2,
            ),
            _buildDateField(
              label: 'Date de naissance',
              date: _dateOfBirth,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(1990),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _dateOfBirth = picked);
                }
              },
            ),
            _buildGenderField(),
            
            const SizedBox(height: 32),
            
            // SECTION 2: Informations Médicales
            _buildSectionHeader('🏥 Informations Médicales', Icons.medical_services),
            _buildTextField(
              controller: _allergiesController,
              label: 'Allergies (séparées par des virgules)',
              icon: Icons.warning_amber,
              hint: 'Ex: Pénicilline, Arachides, Lactose',
              maxLines: 2,
            ),
            _buildTextField(
              controller: _chronicDiseasesController,
              label: 'Maladies chroniques',
              icon: Icons.local_hospital,
              hint: 'Ex: Diabète, Hypertension, Asthme',
              maxLines: 2,
            ),
            _buildTextField(
              controller: _medicationsController,
              label: 'Médicaments actuels',
              icon: Icons.medication,
              hint: 'Ex: Insuline, Aspirine',
              maxLines: 2,
            ),
            _buildBloodGroupField(),
            _buildTextField(
              controller: _medicalNotesController,
              label: 'Notes médicales supplémentaires',
              icon: Icons.note_add,
              maxLines: 3,
              hint: 'Informations importantes pour les soignants',
            ),
            
            const SizedBox(height: 32),
            
            // SECTION 3: Contacts d'Urgence
            _buildSectionHeader('🚨 Contacts d\'Urgence', Icons.emergency),
            const Text(
              'Contact d\'urgence 1',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emergency1NameController,
              label: 'Nom complet',
              icon: Icons.person,
              required: true,
            ),
            _buildTextField(
              controller: _emergency1PhoneController,
              label: 'Téléphone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              required: true,
            ),
            _buildTextField(
              controller: _emergency1RelationController,
              label: 'Relation',
              icon: Icons.family_restroom,
              hint: 'Ex: Époux/se, Parent, Ami(e)',
              required: true,
            ),
            
            const SizedBox(height: 16),
            const Text(
              'Contact d\'urgence 2 (optionnel)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emergency2NameController,
              label: 'Nom complet',
              icon: Icons.person,
            ),
            _buildTextField(
              controller: _emergency2PhoneController,
              label: 'Téléphone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              controller: _emergency2RelationController,
              label: 'Relation',
              icon: Icons.family_restroom,
              hint: 'Ex: Frère/Sœur, Voisin(e)',
            ),
            
            const SizedBox(height: 32),
            
            // SECTION 4: Assurance
            _buildSectionHeader('🛡️ Assurance Médicale', Icons.shield),
            _buildTextField(
              controller: _insuranceNumberController,
              label: 'Numéro d\'assurance',
              icon: Icons.credit_card,
            ),
            _buildTextField(
              controller: _insuranceCompanyController,
              label: 'Compagnie d\'assurance',
              icon: Icons.business,
              hint: 'Ex: CNSS, CNOPS, Wafa Assurance',
            ),
            _buildDateField(
              label: 'Date d\'expiration',
              date: _insuranceExpiryDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _insuranceExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) {
                  setState(() => _insuranceExpiryDate = picked);
                }
              },
            ),
            
            const SizedBox(height: 32),
            
            // Bouton Enregistrer
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
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '💾 Enregistrer le profil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ce champ est obligatoire';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF4CAF50)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            date != null
                ? '${date.day}/${date.month}/${date.year}'
                : 'Sélectionner une date',
            style: TextStyle(
              color: date != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Genre',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Homme'),
                  value: 'male',
                  groupValue: _gender,
                  onChanged: (value) => setState(() => _gender = value!),
                  activeColor: const Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Femme'),
                  value: 'female',
                  groupValue: _gender,
                  onChanged: (value) => setState(() => _gender = value!),
                  activeColor: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupField() {
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _bloodGroup,
        decoration: InputDecoration(
          labelText: 'Groupe sanguin',
          prefixIcon: const Icon(Icons.bloodtype, color: Color(0xFF4CAF50)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: bloodGroups.map((group) {
          return DropdownMenuItem(
            value: group,
            child: Text(group),
          );
        }).toList(),
        onChanged: (value) => setState(() => _bloodGroup = value),
      ),
    );
  }
}
