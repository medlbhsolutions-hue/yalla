import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';

/// Écran Admin - Validation des documents chauffeurs
/// Liste tous les documents pending avec filtres et actions approve/reject
class AdminDocumentsValidationScreen extends StatefulWidget {
  const AdminDocumentsValidationScreen({Key? key}) : super(key: key);

  @override
  State<AdminDocumentsValidationScreen> createState() => _AdminDocumentsValidationScreenState();
}

class _AdminDocumentsValidationScreenState extends State<AdminDocumentsValidationScreen> {
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  String _filterStatus = 'pending';
  String? _filterType;

  final Map<String, String> _documentTypeLabels = {
    'license': '🪪 Permis de conduire',
    'insurance': '🛡️ Assurance',
    'registration': '📄 Carte grise',
    'criminal_record': '⚖️ Casier judiciaire',
  };

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    
    try {
      // Utiliser la nouvelle méthode avec filtre
      final docs = await DatabaseService.getAdminDocuments(statusFilter: _filterStatus);
      
      // Appliquer filtre par type si nécessaire
      var filtered = docs.asMap().entries.map((e) => e.value);
      
      if (_filterType != null) {
        filtered = filtered.where((doc) => doc['document_type'] == _filterType);
      }
      
      setState(() {
        _documents = filtered.toList();
        _isLoading = false;
      });
      
      print('✅ Documents chargés: ${_documents.length} (status: $_filterStatus)');
      
    } catch (e) {
      print('❌ Erreur chargement documents: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openDocument(String fileUrl, {bool isImage = true}) async {
    if (isImage) {
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black87,
          child: Stack(
            fit: StackFit.loose, // Important pour éviter overflow
            alignment: Alignment.center,
            children: [
              // ZOOMABLE IMAGE
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  fileUrl,
                  loadingBuilder: (context, child, event) {
                    if (event == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white, size: 48),
                        Text('Erreur chargement image', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              
              // CLOSE BUTTON
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
              
              // OPEN EXTERNAL BUTTON
              Positioned(
                bottom: 20,
                child: ElevatedButton.icon(
                  onPressed: () => _launchExternal(fileUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ouvrir dans le navigateur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      _launchExternal(fileUrl);
    }
  }

  Future<void> _launchExternal(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Erreur ouverture: $e');
    }
  }

  Future<void> _showValidationDialog(Map<String, dynamic> document, bool isApprove) async {
    final notesController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isApprove ? Icons.check_circle : Icons.cancel,
              color: isApprove ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isApprove ? 'Approuver le document' : 'Rejeter le document',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chauffeur: ${document['drivers']['first_name']} ${document['drivers']['last_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Type: ${_documentTypeLabels[document['document_type']]}'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: isApprove ? 'Notes (optionnel)' : 'Raison du rejet *',
                hintText: isApprove 
                    ? 'Document conforme' 
                    : 'Expliquez pourquoi le document est rejeté',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!isApprove && notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La raison du rejet est obligatoire'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green : Colors.red,
            ),
            child: Text(isApprove ? 'Approuver' : 'Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _validateDocument(
        document['id'],
        isApprove ? 'approved' : 'rejected',
        notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );
    }
    
    notesController.dispose();
  }

  Future<void> _validateDocument(String documentId, String status, String? notes) async {
    try {
      await DatabaseService.updateDocumentStatus(
        documentId: documentId,
        status: status,
        adminNotes: notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved' 
                  ? '✅ Document approuvé' 
                  : '❌ Document rejeté',
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.orange,
          ),
        );
        
        _loadDocuments(); // Recharger la liste
      }
      
    } catch (e) {
      print('❌ Erreur validation document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation Documents'),
        backgroundColor: const Color(0xFF1A237E), // Deep Blue Dashboard
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                // Filtre Statut
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('⏳ En attente')),
                      DropdownMenuItem(value: 'approved', child: Text('✅ Approuvés')),
                      DropdownMenuItem(value: 'rejected', child: Text('❌ Rejetés')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filterStatus = value);
                        _loadDocuments();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Filtre Type
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _filterType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous')),
                      ..._documentTypeLabels.entries.map(
                        (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _filterType = value);
                      _loadDocuments();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Liste documents
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun document $_filterStatus',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) => _buildDocumentCard(_documents[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final driver = document['drivers'];
    final uploadedAt = DateTime.parse(document['uploaded_at']);
    final status = document['status'];
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor, width: 2),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          '${driver['first_name']} ${driver['last_name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_documentTypeLabels[document['document_type']] ?? document['document_type']),
            Text(
              'Uploadé le ${uploadedAt.day}/${uploadedAt.month}/${uploadedAt.year} à ${uploadedAt.hour}:${uploadedAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Infos document
                _buildInfoRow('📱 Téléphone', driver['phone_number'] ?? 'Non renseigné'),
                _buildInfoRow('📄 Fichier', document['file_name']),
                _buildInfoRow('📊 Taille', '${(document['file_size'] / 1024).toStringAsFixed(1)} KB'),
                
                if (document['admin_notes'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow('📝 Notes Admin', document['admin_notes']),
                ],
                
                const SizedBox(height: 16),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openDocument(document['file_url']),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Voir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ),
                    
                    if (status == 'pending') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showValidationDialog(document, false),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Rejeter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showValidationDialog(document, true),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Approuver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
