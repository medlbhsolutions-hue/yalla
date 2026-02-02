import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';

/// Écran de profil chauffeur COMPLET - Design Tech & Glow
class DriverProfileCompleteScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProfile;
  
  const DriverProfileCompleteScreen({
    Key? key,
    this.existingProfile,
  }) : super(key: key);

  @override
  State<DriverProfileCompleteScreen> createState() => _DriverProfileCompleteScreenState();
}

class _DriverProfileCompleteScreenState extends State<DriverProfileCompleteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingRecords = true;
  
  // SECTION 1: Informations Personnelles
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _photoUrl;
  
  // SECTION 2: Véhicule
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  int _vehicleSeats = 4;
  bool _hasAirConditioning = true;
  bool _wheelchairAccessible = false;
  String _vehicleType = 'sedan';
  
  // SECTION 3: Documents
  final Map<String, DocumentInfo> _documents = {
    'license': DocumentInfo('Permis de conduire', Icons.credit_card),
    'insurance': DocumentInfo('Assurance véhicule', Icons.shield),
    'registration': DocumentInfo('Carte grise', Icons.description),
    'criminal_record': DocumentInfo('Casier judiciaire', Icons.gavel),
  };
  
  // SECTION 4: Informations Bancaires
  final _ibanController = TextEditingController();
  final _ribController = TextEditingController();
  final _bankNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllInitialData();
  }

  Future<void> _loadAllInitialData() async {
    setState(() => _isLoadingRecords = true);
    
    // 1. Charger les données du profil
    _loadExistingProfileData();
    
    // 2. Charger les statuts des documents depuis la DB
    await _loadExistingDocuments();
    
    if (mounted) {
      setState(() => _isLoadingRecords = false);
    }
  }

  void _loadExistingProfileData() {
    if (widget.existingProfile != null) {
      final profile = widget.existingProfile!;
      
      _firstNameController.text = profile['first_name'] ?? '';
      _lastNameController.text = profile['last_name'] ?? '';
      _phoneController.text = profile['phone_number'] ?? '';
      _emailController.text = DatabaseService.currentUser?.email ?? '';
      _addressController.text = profile['address'] ?? '';
      _photoUrl = profile['avatar'];
      
      if (profile['date_of_birth'] != null) {
        _dateOfBirth = DateTime.tryParse(profile['date_of_birth'].toString());
      }
      
      _vehicleBrandController.text = profile['vehicle_brand'] ?? '';
      _vehicleModelController.text = profile['vehicle_model'] ?? '';
      _vehicleYearController.text = profile['vehicle_year']?.toString() ?? '';
      _vehicleColorController.text = profile['vehicle_color'] ?? '';
      _vehiclePlateController.text = profile['vehicle_plate_number'] ?? '';
      _vehicleSeats = profile['vehicle_capacity'] ?? 4;
      _hasAirConditioning = profile['has_air_conditioning'] ?? true;
      _wheelchairAccessible = profile['wheelchair_accessible'] ?? false;
      _vehicleType = profile['vehicle_type'] ?? 'sedan';
      
      _ibanController.text = profile['bank_iban'] ?? '';
      _bankNameController.text = profile['bank_name'] ?? '';
    }
  }

  Future<void> _loadExistingDocuments() async {
    try {
      final docs = await DatabaseService.getDriverDocuments();
      for (var doc in docs) {
        final type = doc['document_type'];
        if (_documents.containsKey(type)) {
          setState(() {
            _documents[type]!.uploadedUrl = doc['file_url'];
            _documents[type]!.status = doc['status'];
            _documents[type]!.adminNotes = doc['admin_notes'];
          });
        }
      }
    } catch (e) {
      print('⚠️ Erreur chargement documents existants: $e');
    }
  }

  Future<void> _pickDocument(String documentType) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _documents[documentType]!.isUploading = true;
        });
        
        final bytes = await image.readAsBytes();
        final fileUrl = await DatabaseService.uploadDriverDocument(
          filePath: image.path,
          documentType: documentType,
          fileName: image.name,
          fileBytes: bytes,
        );
        
        setState(() {
          _documents[documentType]!.isUploading = false;
          _documents[documentType]!.uploadedUrl = fileUrl;
          _documents[documentType]!.status = 'pending';
          _documents[documentType]!.localPath = image.path;
          _documents[documentType]!.fileSize = bytes.length;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_documents[documentType]!.label} uploadé'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _documents[documentType]!.isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur upload: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final userId = DatabaseService.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      final profileData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'date_of_birth': _dateOfBirth?.toIso8601String(),
        'vehicle_brand': _vehicleBrandController.text.trim(),
        'vehicle_model': _vehicleModelController.text.trim(),
        'vehicle_year': int.tryParse(_vehicleYearController.text.trim()),
        'vehicle_color': _vehicleColorController.text.trim(),
        'vehicle_plate_number': _vehiclePlateController.text.trim().toUpperCase(),
        'vehicle_capacity': _vehicleSeats,
        'bank_iban': _ibanController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await DatabaseService.updateDriverProfile(profileData);
      
      // Sauvegarder les métadonnées des nouveaux documents
      final driver = await DatabaseService.getDriverProfile();
      if (driver != null) {
        for (final entry in _documents.entries) {
          // Uniquement si on vient de l'uploader (localPath présent)
          if (entry.value.localPath != null && entry.value.uploadedUrl != null) {
            await DatabaseService.saveDocumentMetadata(
              driverId: driver['id'],
              documentType: entry.key,
              fileUrl: entry.value.uploadedUrl!,
              fileName: entry.value.localPath!.split('/').last,
              fileSize: entry.value.fileSize ?? 0,
            );
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profil et documents mis à jour'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Background effects
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withOpacity(0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isLoadingRecords 
                  ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                  : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSectionHeader('👤 Informations Personnel'),
                        _buildGlassContainer(
                          Column(
                            children: [
                              _buildTextField(controller: _firstNameController, label: 'Prénom', icon: Icons.person_outline),
                              const SizedBox(height: 15),
                              _buildTextField(controller: _lastNameController, label: 'Nom', icon: Icons.person_outline),
                              const SizedBox(height: 15),
                              _buildTextField(controller: _phoneController, label: 'Téléphone', icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                              const SizedBox(height: 15),
                              _buildTextField(controller: _addressController, label: 'Adresse complète', icon: Icons.home_rounded, maxLines: 2),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        _buildSectionHeader('🚗 Véhicule & Capacité'),
                        _buildGlassContainer(
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildTextField(controller: _vehicleBrandController, label: 'Marque', icon: Icons.branding_watermark)),
                                  const SizedBox(width: 15),
                                  Expanded(child: _buildTextField(controller: _vehicleModelController, label: 'Modèle', icon: Icons.car_rental)),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField(controller: _vehicleYearController, label: 'Année', icon: Icons.calendar_month, keyboardType: TextInputType.number)),
                                  const SizedBox(width: 15),
                                  Expanded(child: _buildTextField(controller: _vehiclePlateController, label: 'Immatriculation', icon: Icons.pin_end_rounded)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text('Nombre de places passagers', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 10),
                              _buildSeatsSelector(),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        _buildSectionHeader('📄 Documents officiels'),
                        const Text(
                          'Uploadez des photos claires de vos documents pour validation.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 15),
                        ..._documents.entries.map((e) => _buildModernDocumentTile(e.key, e.value)).toList(),
                        
                        const SizedBox(height: 30),
                        _buildSectionHeader('🏦 Paiements (Optionnel)'),
                        _buildGlassContainer(
                          Column(
                            children: [
                              _buildTextField(controller: _ibanController, label: 'IBAN (RIB)', icon: Icons.account_balance_rounded),
                              const SizedBox(height: 15),
                              _buildTextField(controller: _bankNameController, label: 'Nom de la Banque', icon: Icons.business_rounded),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        _buildSubmitButton(),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MON PROFIL',
                style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              Text(
                'Partenaire Chauffeur',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 5),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildGlassContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.greenAccent, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.greenAccent, width: 1),
        ),
      ),
      validator: (v) => v?.isEmpty ?? true ? 'Champ requis' : null,
    );
  }

  Widget _buildSeatsSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(6, (i) {
        final seats = i + 2;
        final isSelected = _vehicleSeats == seats;
        return GestureDetector(
          onTap: () => setState(() => _vehicleSeats = seats),
          child: Container(
            width: 45,
            height: 45,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? Colors.greenAccent : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Colors.greenAccent : Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              seats.toString(),
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildModernDocumentTile(String type, DocumentInfo info) {
    bool hasDoc = info.uploadedUrl != null;
    Color statusColor;
    String statusLabel;
    
    switch (info.status) {
      case 'approved': statusColor = Colors.greenAccent; statusLabel = 'Validé'; break;
      case 'rejected': statusColor = Colors.redAccent; statusLabel = 'Rejeté'; break;
      default: statusColor = Colors.orangeAccent; statusLabel = hasDoc ? 'En attente' : 'Manquant';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasDoc ? statusColor.withOpacity(0.3) : Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: info.isUploading ? null : () => _pickDocument(type),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(info.icon, color: statusColor, size: 22),
        ),
        title: Text(info.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          info.adminNotes != null ? "⚠️ Note: ${info.adminNotes}" : statusLabel,
          style: TextStyle(color: statusColor.withOpacity(0.7), fontSize: 12),
        ),
        trailing: info.isUploading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent))
          : Icon(hasDoc ? Icons.check_circle_rounded : Icons.add_a_photo_rounded, color: statusColor, size: 24),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.successGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isSaving
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'ENREGISTRER MON PROFIL',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
      ),
    );
  }
}

class DocumentInfo {
  final String label;
  final IconData icon;
  String? localPath;
  String? uploadedUrl;
  String? status;
  String? adminNotes;
  bool isUploading = false;
  int? fileSize;
  
  DocumentInfo(this.label, this.icon);
}
