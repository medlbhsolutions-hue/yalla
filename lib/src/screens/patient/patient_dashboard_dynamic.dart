import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import '../../services/auth_service_complete.dart';
import '../../utils/app_colors.dart';
import 'ride_request_screen.dart';
import 'ride_tracking_screen.dart';
import 'patient_live_tracking_screen.dart';
import '../rating_screen.dart';
import 'pharmacy_map_screen.dart';
import 'dart:ui';

/// Dashboard Patient Dynamique avec design "Tech & Glow"
class PatientDashboardDynamic extends StatefulWidget {
  const PatientDashboardDynamic({super.key});

  @override
  State<PatientDashboardDynamic> createState() => _PatientDashboardDynamicState();
}

class _PatientDashboardDynamicState extends State<PatientDashboardDynamic> {
  final _supabase = Supabase.instance.client;
  
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _activeRides = [];
  List<Map<String, dynamic>> _recentRides = [];
  int _totalRides = 0;
  double _averageRating = 0.0;
  bool _isLoading = true;
  
  RealtimeChannel? _ridesChannel;
  String _transportType = 'non-urgent';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('transportType')) {
      setState(() {
        _transportType = args['transportType'];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _subscribeToRides();
  }

  @override
  void dispose() {
    _ridesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _showError('Utilisateur non connecté');
        return;
      }

      // Charger le profil utilisateur
      _userProfile = await AuthServiceComplete.getUserProfile(userId);

      // Charger les courses actives
      await _loadActiveRides(userId);

      // Charger l'historique récent
      await _loadRecentRides(userId);

      // Compter le total de courses
      await _loadTotalRides(userId);

    } catch (e) {
      print('❌ Erreur chargement données: $e');
      _showError('Erreur lors du chargement des données');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadActiveRides(String userId) async {
    try {
      final response = await _supabase
          .from('rides')
          .select('''
            *,
            driver:drivers(
              id,
              user_id,
              first_name,
              last_name,
              phone_number,
              vehicle:vehicles(make, model, plate_number, color)
            )
          ''')
          .eq('patient_id', userId)
          .inFilter('status', ['pending', 'accepted', 'in_progress'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activeRides = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('❌ Erreur chargement courses actives: $e');
    }
  }

  Future<void> _loadRecentRides(String userId) async {
    try {
      final response = await _supabase
          .from('rides')
          .select('''
            *,
            driver:drivers(
              id,
              user_id,
              first_name,
              last_name
            )
          ''')
          .eq('patient_id', userId)
          .inFilter('status', ['completed', 'cancelled'])
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _recentRides = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('❌ Erreur chargement historique: $e');
    }
  }

  Future<void> _loadTotalRides(String userId) async {
    try {
      final response = await _supabase
          .from('rides')
          .select('id, patient_rating')
          .eq('patient_id', userId)
          .eq('status', 'completed');

      double totalRating = 0.0;
      int ratedRides = 0;
      for (var ride in response) {
        if (ride['patient_rating'] != null) {
          totalRating += (ride['patient_rating'] as num).toDouble();
          ratedRides++;
        }
      }

      if (mounted) {
        setState(() {
          _totalRides = response.length;
          _averageRating = ratedRides > 0 ? totalRating / ratedRides : 0.0;
        });
      }
    } catch (e) {
      print('❌ Erreur comptage courses: $e');
    }
  }

  void _subscribeToRides() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _ridesChannel = _supabase
        .channel('patient_rides_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: userId,
          ),
          callback: (payload) {
            _loadUserData();
          },
        )
        .subscribe();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header avec Profil & Greeting
          _buildSliverHeader(),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte Stats Glow
                  _buildGlowStatsCard(),
                  
                  const SizedBox(height: 32),
                  
                  // Courses actives (Si il y en a)
                  if (_activeRides.isNotEmpty) ...[
                    _buildSectionTitle('Trajets en cours', true),
                    const SizedBox(height: 16),
                    ..._activeRides.map((ride) => _buildActiveRideCard(ride)),
                    const SizedBox(height: 32),
                  ],

                  // Accès Rapide / Pharmacie
                  _buildQuickAccessCard(),
                  
                  const SizedBox(height: 32),
                  
                  // Sélection du Transport
                   // Sélection du Transport
                  _buildSectionTitle(_transportType == 'urgent' ? 'Services d\'Urgence' : 'Services Médicaux', false),
                  Text(
                    _transportType == 'urgent' ? 'Transport urgent (Ambulance)' : 'Transport non urgent (Standard)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTransportGrid(),
                  
                  const SizedBox(height: 32),
                  
                  // Historique Récent
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Historique récent', false),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Tout voir', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_recentRides.isEmpty)
                    _buildEmptyState()
                  else
                    ..._recentRides.map((ride) => _buildHistoryCard(ride)),
                  
                  const SizedBox(height: 100), // Espace pour le FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCustomFAB(),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.primary, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -30,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(60, 50, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour, 👋',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                          Text(
                            _userProfile?['first_name'] ?? 'Chargement...',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A202C),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF4A5568), size: 28),
                      onPressed: () {},
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

  Widget _buildGlowStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem('Courses', '$_totalRides', Icons.directions_car_filled_rounded),
          Container(height: 40, width: 1, color: Colors.white.withOpacity(0.15)),
          _buildStatItem('Note', _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '5.0', Icons.star_rounded),
          Container(height: 40, width: 1, color: Colors.white.withOpacity(0.15)),
          _buildStatItem('Rang', 'Or', Icons.verified_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PharmacyMapScreen())),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3748),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_pharmacy_rounded, color: AppColors.green, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pharmacie de garde',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Trouvez les services ouverts 24h/7',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildLuxuryTransportCard('Ambulance', Icons.medical_services_rounded, Colors.redAccent, 'Urgence'),
        _buildLuxuryTransportCard('Standard', Icons.directions_car_rounded, AppColors.primary, 'Visite'),
        _buildLuxuryTransportCard('Hôpital', Icons.account_balance_rounded, Colors.orangeAccent, 'Rendez-vous'),
        _buildLuxuryTransportCard('Laboratoire', Icons.biotech_rounded, Colors.purpleAccent, 'Analyses'),
      ],
    );
  }

  Widget _buildLuxuryTransportCard(String title, IconData icon, Color color, String sub) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RideRequestScreen())),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(sub, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isUrgent) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Color(0xFF1A1A1A),
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildActiveRideCard(Map<String, dynamic> ride) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_searching_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Destination', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      ride['destination_address'] ?? 'Adresse non spécifiée',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildStatusPill(ride['status']),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientLiveTrackingScreen(
                        rideId: ride['id'],
                        pickupAddress: ride['pickup_address'] ?? '',
                        destinationAddress: ride['destination_address'] ?? '',
                        estimatedPrice: ride['estimated_price']?.toString() ?? '0',
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Suivi en direct', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color color = AppColors.primary;
    String label = status;
    
    if (status == 'pending') { color = Colors.orange; label = 'Attente'; }
    if (status == 'accepted') { color = AppColors.green; label = 'Arrivée'; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> ride) {
    final status = ride['status'];
    final isCompleted = status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
            child: Icon(
              isCompleted ? Icons.check_circle_outline_rounded : Icons.history_rounded, 
              color: isCompleted ? AppColors.green : Colors.grey[400], 
              size: 24
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride['destination_address'] ?? 'Course archivée', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(isCompleted ? 'Effectuée' : 'Annulée', 
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          Text('${ride['estimated_price'] ?? '0'} DH', 
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(Icons.history_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun historique pour le moment',
            style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFAB() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RideRequestScreen())),
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        label: const Text(
          'DEMANDER UN TRAJET', 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)
        ),
        icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      _userProfile?['first_name']?[0] ?? 'P',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_userProfile?['first_name'] ?? ''} ${_userProfile?['last_name'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _supabase.auth.currentUser?.email ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(Icons.history_rounded, 'Mes trajets', () {}),
                  _buildDrawerItem(Icons.person_outline_rounded, 'Mon profil', () {}),
                  _buildDrawerItem(Icons.local_pharmacy_outlined, 'Pharmacies de garde', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PharmacyMapScreen()));
                  }),
                  _buildDrawerItem(Icons.help_outline_rounded, 'Aide & Support', () {}),
                  const Divider(),
                  _buildDrawerItem(Icons.logout_rounded, 'Déconnexion', () async {
                    await AuthServiceComplete.signOut();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
                    }
                  }, isDestructive: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary.withOpacity(0.7)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : const Color(0xFF2D3748),
        ),
      ),
      onTap: onTap,
    );
  }
}
