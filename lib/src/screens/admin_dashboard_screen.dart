import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'admin/admin_documents_validation_screen.dart';

/// Dashboard Admin simple avec notifications
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _pendingDocumentsCount = 0;
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    
    try {
      final docs = await DatabaseService.getAdminPendingDocuments();
      final unread = await DatabaseService.getUnreadNotificationsCount();
      
      setState(() {
        _pendingDocumentsCount = docs.length;
        _unreadNotificationsCount = unread;
        _isLoading = false;
      });
    } catch (e) {
      print('[ERROR] Erreur chargement dashboard admin: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        backgroundColor: const Color(0xFF4CAF50),
        actions: [
          // Badge notifications
          if (_unreadNotificationsCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      // TODO: Ouvrir écran notifications
                    },
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_unreadNotificationsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCounts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // En-tête
                  const Text(
                    'Tableau de bord',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Cartes statistiques
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Documents en attente',
                          value: '$_pendingDocumentsCount',
                          icon: Icons.pending_actions,
                          color: Colors.orange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdminDocumentsValidationScreen(),
                              ),
                            ).then((_) => _loadCounts());
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Notifications',
                          value: '$_unreadNotificationsCount',
                          icon: Icons.notifications_active,
                          color: Colors.red,
                          onTap: () {
                            // TODO: Ouvrir notifications
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Menu actions rapides
                  const Text(
                    'Actions rapides',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildMenuTile(
                    title: 'Valider documents chauffeurs',
                    subtitle: '$_pendingDocumentsCount document(s) en attente',
                    icon: Icons.verified_user,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDocumentsValidationScreen(),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                  
                  _buildMenuTile(
                    title: 'Gestion chauffeurs',
                    subtitle: 'Voir tous les chauffeurs',
                    icon: Icons.people,
                    color: Colors.blue,
                    onTap: () {
                      // TODO: Écran liste chauffeurs
                    },
                  ),
                  
                  _buildMenuTile(
                    title: 'Gestion courses',
                    subtitle: 'Voir toutes les courses',
                    icon: Icons.local_taxi,
                    color: Colors.purple,
                    onTap: () {
                      // TODO: Écran liste courses
                    },
                  ),
                  
                  _buildMenuTile(
                    title: 'Statistiques',
                    subtitle: 'Rapports et analyses',
                    icon: Icons.analytics,
                    color: Colors.teal,
                    onTap: () {
                      // TODO: Écran statistiques
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
