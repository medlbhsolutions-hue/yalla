import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/locale_helper.dart';
import '../../services/admin_service.dart';
import 'widgets/admin_status_badge.dart';

/// Écran de gestion des utilisateurs (patients, drivers)
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  
  // Filtres
  String? _roleFilter;
  String? _statusFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final users = await AdminService.getUsers(
        roleFilter: _roleFilter,
        statusFilter: _statusFilter,
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement utilisateurs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    final success = await AdminService.toggleUserStatus(userId, !currentStatus);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Statut utilisateur ${!currentStatus ? 'activé' : 'désactivé'}'),
          backgroundColor: Colors.green,
        ),
      );
      _loadUsers(); // Recharger la liste
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur modification statut'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _validateDriver(String driverId, String driverName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider le chauffeur'),
        content: Text('Confirmer la validation de $driverName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminService.validateDriver(driverId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Chauffeur validé'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de filtres et recherche
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              // Recherche
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher par email ou téléphone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadUsers();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => _loadUsers(),
              ),
              const SizedBox(height: 12),
              
              // Filtres
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _roleFilter,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Rôle',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tous')),
                        DropdownMenuItem(value: 'patient', child: Text('Patients')),
                        DropdownMenuItem(value: 'driver', child: Text('Chauffeurs')),
                        DropdownMenuItem(value: 'admin', child: Text('Admins')),
                      ],
                      onChanged: (value) {
                        setState(() => _roleFilter = value);
                        _loadUsers();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _statusFilter,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tous')),
                        DropdownMenuItem(value: 'active', child: Text('Actifs')),
                        DropdownMenuItem(value: 'inactive', child: Text('Inactifs')),
                      ],
                      onChanged: (value) {
                        setState(() => _statusFilter = value);
                        _loadUsers();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Liste des utilisateurs
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4CAF50),
                  ),
                )
              : _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun utilisateur trouvé',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return _buildUserCard(user);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'unknown';
    final isActive = user['is_active'] ?? false;
  final createdAt = user['created_at'] != null
    ? LocaleHelper.formatDateSafe(DateTime.parse(user['created_at']), pattern: 'dd/MM/yyyy')
    : '-';

    // Infos spécifiques driver
    final driverInfo = user['drivers'] is List && (user['drivers'] as List).isNotEmpty
        ? (user['drivers'] as List).first
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _getRoleColor(role).withOpacity(0.1),
                  child: Icon(
                    _getRoleIcon(role),
                    color: _getRoleColor(role),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Infos principales
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AdminStatusBadge(
                            status: isActive ? 'active' : 'inactive',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? '-',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user['phone'] ?? '-',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Badge rôle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getRoleLabel(role),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Infos supplémentaires
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Inscription: $createdAt',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'ID: ${user['id'].toString().substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            // Infos spécifiques driver
            if (driverInfo != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  AdminStatusBadge(
                    status: driverInfo['status'] ?? 'pending',
                  ),
                  const SizedBox(width: 12),
                  if (driverInfo['rating'] != null)
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${driverInfo['rating']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Toggle actif/inactif
                OutlinedButton.icon(
                  onPressed: () => _toggleUserStatus(user['id'], isActive),
                  icon: Icon(isActive ? Icons.block : Icons.check_circle),
                  label: Text(isActive ? 'Désactiver' : 'Activer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isActive ? Colors.red : Colors.green,
                  ),
                ),
                
                // Valider chauffeur (si pending)
                if (driverInfo != null && driverInfo['status'] == 'pending') ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _validateDriver(
                      driverInfo['id'],
                      '${user['first_name']} ${user['last_name']}',
                    ),
                    icon: const Icon(Icons.verified),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],

                const SizedBox(width: 8),
                // Voir détails
                IconButton(
                  onPressed: () => _showUserDetails(user),
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Détails',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'patient':
        return Colors.green;
      case 'driver':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'patient':
        return Icons.person;
      case 'driver':
        return Icons.drive_eta;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.help_outline;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'patient':
        return 'PATIENT';
      case 'driver':
        return 'CHAUFFEUR';
      case 'admin':
        return 'ADMIN';
      default:
        return role.toUpperCase();
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails: ${user['first_name']} ${user['last_name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', user['id']),
              _buildDetailRow('Email', user['email'] ?? '-'),
              _buildDetailRow('Téléphone', user['phone'] ?? '-'),
              _buildDetailRow('Rôle', user['role'] ?? '-'),
              _buildDetailRow('Statut', user['is_active'] == true ? 'Actif' : 'Inactif'),
        _buildDetailRow('Inscription', user['created_at'] != null
          ? LocaleHelper.formatDateSafe(DateTime.parse(user['created_at']), pattern: 'dd/MM/yyyy HH:mm')
          : '-'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
