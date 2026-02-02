import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import '../../services/admin_service.dart';
import '../../services/database_service.dart';
import 'admin_documents_validation_screen.dart';
import 'admin_users_screen.dart';
import 'admin_rides_screen.dart';
import 'admin_realtime_map_screen.dart';
import 'admin_financial_screen.dart'; // ✅ FINANCE
import 'widgets/admin_sidebar.dart';
import 'widgets/admin_kpi_card.dart';

/// 🎯 DASHBOARD ADMIN PROFESSIONNEL - VERSION PREMIUM
/// Gestion complète : Utilisateurs, Courses, Documents, Finances, Carte Temps Réel
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isLoading = true;

  // Statistiques
  Map<String, int> _userStats = {};
  Map<String, dynamic> _rideStats = {};
  int _pendingDocumentsCount = 0;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Charger toutes les données du dashboard
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Charger en parallèle
      final results = await Future.wait([
        AdminService.getUserStats(),
        AdminService.getRideStats(),
        DatabaseService.getAdminPendingDocuments(),
        DatabaseService.getUnreadNotificationsCount(),
      ]);

      setState(() {
        _userStats = results[0] as Map<String, int>;
        _rideStats = results[1] as Map<String, dynamic>;
        _pendingDocumentsCount = (results[2] as List).length;
        _unreadNotificationsCount = results[3] as int;
        _isLoading = false;
      });

      print('✅ Dashboard chargé: ${_userStats['total']} users, ${_rideStats['total_rides']} rides');
    } catch (e) {
      print('❌ Erreur chargement dashboard: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: _loadDashboardData,
            ),
          ),
        );
      }
    }
  }

  /// Naviguer vers l'écran correspondant
  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return const AdminUsersScreen();
      case 2:
        return const AdminRidesScreen();
      case 3:
        return const AdminRealtimeMapScreen();
      case 4:
        return const AdminFinancialScreen(); // ✅ ÉCRAN FINANCIER
      case 5:
        return _buildSettingsTab();
      default:
        return _buildOverviewTab();
    }
  }

  String _getSectionTitle() {
    switch (_selectedIndex) {
      case 0: return 'Vue d\'ensemble';
      case 1: return 'Utilisateurs';
      case 2: return 'Courses & Trajets';
      case 3: return 'Carte Live';
      case 4: return 'Analyses financières';
      case 5: return 'Paramètres';
      default: return 'Administration';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AdminSidebar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      backgroundColor: const Color(0xFFFBFBFE),
      body: Stack(
        children: [
          // 🌊 FOND GRADIENT ADMIN
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // 👤 HEADER PERSISTANT
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Administration',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                              ),
                              const Text(
                                'YALLA L\'TBIB',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              badges.Badge(
                                showBadge: _unreadNotificationsCount > 0,
                                badgeContent: Text('$_unreadNotificationsCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                child: IconButton(
                                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                                  onPressed: () {},
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  if (_selectedIndex == 0) {
                                    _scaffoldKey.currentState?.openDrawer();
                                  } else {
                                    setState(() => _selectedIndex = 0);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF1A237E),
                                    child: Icon(
                                      _selectedIndex == 0 ? Icons.menu_rounded : Icons.arrow_back_rounded, 
                                      color: Colors.white, 
                                      size: 28
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // 🏠 FIL D'ARIANE
                      if (_selectedIndex != 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _selectedIndex = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.home_rounded, color: Colors.white, size: 16),
                                      SizedBox(width: 8),
                                      Text('Retour au Dashboard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // 📱 CONTENU DYNAMIQUE
                Expanded(
                  child: _getCurrentScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 📊 ONGLET OVERVIEW (Dashboard principal)
  // ============================================
  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Chargement des statistiques...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sous-titre et date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getSectionTitle(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getFormattedDate(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // ⚠️ ALERTES IMPORTANTES
            if (_pendingDocumentsCount > 0) ...[
              _buildAlertCard(
                icon: Icons.warning_amber,
                color: Colors.orange,
                title: 'Documents en attente',
                subtitle: '$_pendingDocumentsCount document(s) chauffeur à valider',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDocumentsValidationScreen(),
                    ),
                  ).then((_) => _loadDashboardData());
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              // 🚀 QUICK ACTION: CLEAN UP RIDES (Simulation / Flexibilité)
              _buildAlertCard(
                icon: Icons.cleaning_services_rounded,
                color: const Color(0xFF1A237E),
                title: 'Nettoyage des courses',
                subtitle: 'Annuler les courses en attente (Test Admin)',
                onTap: () async {
                  final rides = await AdminService.getRides(statusFilter: 'pending');
                  for (var r in rides) {
                    await AdminService.cancelRide(r['id'], 'Annulation admin');
                  }
                  _loadDashboardData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Courses nettoyées avec succès')),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // 📈 KPI CARDS - Ligne 1: Utilisateurs
            const Text(
              '👥 Utilisateurs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AdminKpiCard(
                    title: 'Total',
                    value: '${_userStats['total'] ?? 0}',
                    icon: Icons.people,
                    color: const Color(0xFF1A237E),
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Actifs',
                    value: '${_userStats['active'] ?? 0}',
                    icon: Icons.verified_user,
                    color: const Color(0xFF43A047),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Patients',
                    value: '${_userStats['patients'] ?? 0}',
                    icon: Icons.person,
                    color: const Color(0xFF8E24AA),
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Chauffeurs',
                    value: '${_userStats['drivers'] ?? 0}',
                    icon: Icons.local_taxi,
                    color: const Color(0xFFFB8C00),
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 🚕 KPI CARDS - Ligne 2: Courses
            const Text(
              '🚕 Courses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AdminKpiCard(
                    title: 'Total',
                    value: '${_rideStats['total_rides'] ?? 0}',
                    icon: Icons.local_taxi,
                    color: const Color(0xFF546E7A),
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminKpiCard(
                    title: 'En cours',
                    value: '${_rideStats['active_rides'] ?? 0}',
                    icon: Icons.directions_car,
                    color: const Color(0xFFFFB300),
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Aujourd\'hui',
                    value: '${_rideStats['completed_today'] ?? 0}',
                    icon: Icons.done_all,
                    color: const Color(0xFF43A047),
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminKpiCard(
                    title: 'Revenus/jour',
                    value: '${(_rideStats['today_revenue'] ?? 0.0).toStringAsFixed(0)} DH',
                    icon: Icons.attach_money,
                    color: const Color(0xFF00ACC1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ⚡ ACTIONS RAPIDES
            const Text(
              '⚡ Actions rapides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
               _buildActionButton(
                  icon: Icons.map,
                  label: 'Carte Temps Réel',
                  color: Colors.redAccent,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                _buildActionButton(
                  icon: Icons.verified_user,
                  label: 'Valider documents',
                  color: const Color(0xFF43A047),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminDocumentsValidationScreen(),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                ),
                _buildActionButton(
                  icon: Icons.bar_chart,
                  label: 'Voir Finances',
                  color: const Color(0xFF00ACC1),
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // ⚙️ ONGLET PARAMÈTRES
  // ============================================
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '⚙️ Paramètres',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        
        _buildSettingsCard(
          title: 'Configuration générale',
          icon: Icons.settings,
          color: const Color(0xFF1A237E),
          onTap: () {},
        ),
        _buildSettingsCard(
          title: 'Tarification',
          icon: Icons.attach_money,
          color: const Color(0xFF43A047),
          onTap: () {},
        ),
        _buildSettingsCard(
          title: 'Notifications Push',
          icon: Icons.notifications,
          color: const Color(0xFFFB8C00),
          onTap: () {},
        ),
        _buildSettingsCard(
          title: 'Sauvegarde & Export',
          icon: Icons.backup,
          color: const Color(0xFF8E24AA),
          onTap: () {},
        ),
        _buildSettingsCard(
          title: 'Logs système',
          icon: Icons.history,
          color: const Color(0xFF546E7A),
          onTap: () {},
        ),
      ],
    );
  }

  // ============================================
  // 🎨 WIDGETS HELPERS
  // ============================================

  Widget _buildAlertCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
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
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
