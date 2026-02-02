import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service_complete.dart';
import '../../utils/app_colors.dart';

class DocumentVerificationScreen extends StatefulWidget {
  final String driverId;
  const DocumentVerificationScreen({super.key, required this.driverId});

  @override
  State<DocumentVerificationScreen> createState() => _DocumentVerificationScreenState();
}

class _DocumentVerificationScreenState extends State<DocumentVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, Map<String, dynamic>> _docsStatus = {
    'license': {'label': 'Permis de conduire', 'status': 'missing', 'url': null},
    'insurance': {'label': 'Assurance véhicule', 'status': 'missing', 'url': null},
    'registration': {'label': 'Carte grise', 'status': 'missing', 'url': null},
    'criminal_record': {'label': 'Casier judiciaire', 'status': 'missing', 'url': null},
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await AuthServiceComplete.getDriverDocuments(widget.driverId);
    
    if (mounted) {
      setState(() {
        for (var doc in docs) {
          final type = doc['document_type'];
          if (_docsStatus.containsKey(type)) {
            _docsStatus[type]!['status'] = doc['status'];
            _docsStatus[type]!['url'] = doc['file_url'];
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadDoc(String type) async {
    try {
      final XFile? image = await showModalBottomSheet<XFile?>(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sélectionner un document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Prendre une photo'),
                onTap: () async => Navigator.pop(context, await _picker.pickImage(source: ImageSource.camera)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choisir dans la galerie'),
                onTap: () async => Navigator.pop(context, await _picker.pickImage(source: ImageSource.gallery)),
              ),
            ],
          ),
        ),
      );

      if (image == null) return;

      setState(() => _docsStatus[type]!['status'] = 'uploading');

      final result = await AuthServiceComplete.uploadDriverDocument(
        driverId: widget.driverId,
        docType: type,
        file: File(image.path),
        fileName: image.name,
      );

      if (result['success']) {
        _loadDocuments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document envoyé avec succès'), backgroundColor: AppColors.green),
        );
      } else {
        setState(() => _docsStatus[type]!['status'] = 'missing');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${result['error']}'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      print('❌ Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool allApproved = _docsStatus.values.every((doc) => doc['status'] == 'approved');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.white, size: 60),
                      const SizedBox(height: 10),
                      const Text(
                        'Vérification du profil',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Étape obligatoire pour les chauffeurs',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Documents Requis',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Veuillez uploader des photos claires de vos documents originaux.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ..._docsStatus.entries.map((entry) => _buildDocCard(entry.key, entry.value)),
                  
                  const SizedBox(height: 40),
                  
                  if (allApproved)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.green, size: 40),
                          SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              'Félicitations ! Votre compte est validé. Vous pouvez maintenant accepter des courses.',
                              style: TextStyle(color: AppColors.greenDark, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_rounded, color: Colors.amber, size: 40),
                          SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              'Une fois les documents envoyés, notre équipe les validera sous 24h à 48h.',
                              style: TextStyle(color: Colors.brown, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: allApproved ? () => Navigator.pop(context) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: const Text('ACCÉDER AU DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(String type, Map<String, dynamic> data) {
    Color statusColor = Colors.grey;
    String statusText = 'Non envoyé';
    IconData icon = Icons.upload_file_rounded;

    if (data['status'] == 'pending') {
      statusColor = Colors.orange;
      statusText = 'En attente de validation';
      icon = Icons.access_time_rounded;
    } else if (data['status'] == 'approved') {
      statusColor = AppColors.green;
      statusText = 'Approuvé';
      icon = Icons.check_circle_rounded;
    } else if (data['status'] == 'rejected') {
      statusColor = AppColors.error;
      statusText = 'Refusé (Réessayer)';
      icon = Icons.error_rounded;
    } else if (data['status'] == 'uploading') {
      statusColor = AppColors.primary;
      statusText = 'Envoi en cours...';
      icon = Icons.cloud_upload_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (data['status'] == 'missing' || data['status'] == 'rejected') ? () => _uploadDoc(type) : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: statusColor, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['label'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (data['status'] == 'missing' || data['status'] == 'rejected')
                  const Icon(Icons.add_a_photo_rounded, color: AppColors.primary)
                else if (data['status'] == 'approved')
                  const Icon(Icons.verified_rounded, color: AppColors.green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
