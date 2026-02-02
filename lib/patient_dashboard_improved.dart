import 'dart:async'; // 🔄 Pour Timer de rafraîchissement
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;
import 'src/services/database_service.dart';
import 'src/services/notification_service.dart'; // 🔔 NOUVEAU
import 'src/screens/onboarding_screens.dart'; // 🎨 NOUVEAU : Onboarding
import 'src/screens/available_drivers_screen.dart';
import 'src/screens/patient/new_ride_screen.dart';
import 'src/screens/patient_profile_screen.dart';
import 'src/screens/patient_rides_history_screen.dart';
import 'src/screens/patient_statistics_screen.dart';
import 'src/screens/notifications_screen.dart'; // 🔔 NOUVEAU
import 'screens/patient_ride_tracking_screen.dart'; // 📍 Tracking pour patient
import 'src/screens/patient/pharmacy_map_screen.dart';
import 'src/utils/app_colors.dart';

/// Dashboard Patient Amélioré avec Statistiques, Historique et Profil
class PatientDashboard extends StatefulWidget {
  const PatientDashboard({Key? key}) : super(key: key);

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _patientProfile;
  bool _isLoadingProfile = true;
  String _userName = 'Patient';
  String _userPhone = '';
  
  // Statistiques
  int _totalRides = 0;
  double _totalSpent = 0.0;
  double _averageRating = 0.0;
  
  // Courses récentes
  List<Map<String, dynamic>> _recentRides = [];
  bool _isLoadingRides = false;
  
  // Course active (en cours)
  Map<String, dynamic>? _activeRide;
  
  // 🔄 Timer pour rafraîchir automatiquement
  Timer? _refreshTimer;

  // 🚑 Type de transport choisi à l'inscription
  String _transportType = 'non-urgent';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Récupérer le type de transport depuis les arguments
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
    WidgetsBinding.instance.addObserver(this);
    _loadPatientData();
    
    // ⏲️ Rafraîchir toutes les 5 secondes pour voir si un chauffeur accepte
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        print('🔄 Auto-refresh dashboard patient...');
        _loadRecentRides();
      }
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel(); // 🛑 Arrêter le timer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // L'app est revenue au premier plan, rafraîchir les données
      print('🔄 App resumed, rafraîchissement dashboard patient...');
      _loadStatistics();
      _loadRecentRides();
    }
  }

  Future<void> _loadPatientData() async {
    setState(() { _isLoadingProfile = true; });
    
    try {
      // ⚠️ Ne plus créer automatiquement - l'utilisateur doit choisir son rôle
      // Récupérer le profil existant
      final userId = DatabaseService.getCurrentUserId();
      if (userId == null) {
        print('❌ Utilisateur non connecté');
        setState(() { _isLoadingProfile = false; });
        return;
      }
      
      final profile = await DatabaseService.client
          .from('patients')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (profile != null) {
        setState(() {
          _patientProfile = profile;
          _userName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
          if (_userName.isEmpty) _userName = 'Patient';
          _userPhone = profile['phone_number'] ?? profile['emergency_contact_phone'] ?? '+212 6XX XXX XXX';
          _isLoadingProfile = false;
        });
        
        // Charger statistiques et courses en parallèle
        await Future.wait([
          _loadStatistics(),
          _loadRecentRides(),
        ]);
      } else {
        setState(() {
          _userName = 'Patient YALLA L\'TBIB';
          _userPhone = '+212 6XX XXX XXX';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement profil: $e');
      setState(() {
        _userName = 'Patient';
        _userPhone = '+212 6XX XXX XXX';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    if (_patientProfile == null) return;
    
    try {
      // Récupérer toutes les courses du patient
      final allRides = await DatabaseService.getPatientRides(
        patientId: _patientProfile!['id'],
      );
      
      // Calculer statistiques
      int totalRides = allRides.length;
      double totalSpent = 0.0;
      double totalRating = 0.0;
      int ratedRides = 0;
      
      for (var ride in allRides) {
        // Total dépensé
        if (ride['total_price'] != null) {
          totalSpent += (ride['total_price'] as num).toDouble();
        }
        
        // Note moyenne (si le patient a noté le driver)
        if (ride['patient_rating'] != null) {
          totalRating += (ride['patient_rating'] as num).toDouble();
          ratedRides++;
        }
      }
      
      double averageRating = ratedRides > 0 ? totalRating / ratedRides : 0.0;
      
      setState(() {
        _totalRides = totalRides;
        _totalSpent = totalSpent;
        _averageRating = averageRating;
      });
    } catch (e) {
      print('❌ Erreur chargement statistiques: $e');
    }
  }

  Future<void> _loadRecentRides() async {
    if (_patientProfile == null) return;
    
    setState(() { _isLoadingRides = true; });
    
    try {
      final rides = await DatabaseService.getPatientRides(
        patientId: _patientProfile!['id'],
        limit: 20, // Charger plus pour trouver une course active
      );
      
      // Trouver s'il y a une course active
      final activeRide = rides.firstWhere(
        (ride) {
          final status = ride['status'] ?? '';
          return status == 'accepted' || 
                 status == 'in_progress' || 
                 status == 'driver_en_route' || 
                 status == 'arrived';
        },
        orElse: () => {},
      );
      
      setState(() {
        _recentRides = rides.take(5).toList();
        _activeRide = activeRide.isEmpty ? null : activeRide;
        _isLoadingRides = false;
      });
    } catch (e) {
      print('❌ Erreur chargement courses: $e');
      setState(() { _isLoadingRides = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF467DB0)),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSidebar(context),
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // 🌊 FOND GRADIENT "TECH & GLOW"
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [
                    AppColors.accentGlow.withOpacity(0.15),
                    AppColors.darkBg,
                  ],
                ),
              ),
            ),
          ),
          
          // ✨ Points de lumière décoratifs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGlow.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadPatientData,
              color: const Color(0xFF467DB0),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 👤 EN-TÊTE PROFIL
                  SliverToBoxAdapter(child: _buildHeader()),

                  // 🔎 BARRE DE RECHERCHE "OÙ ALLEZ-VOUS ?"
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewRideScreen(patientProfile: _patientProfile),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGlow.withOpacity(0.05),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGlow.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.search_rounded, color: AppColors.accentGlow, size: 24),
                              ),
                              const SizedBox(width: 15),
                              Text(
                                'Où voulez-vous aller ?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),

                  // 🚑 SERVICES PRINCIPAUX
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _transportType == 'urgent' ? 'Service de Transport Urgent' : 'Service de Transport Standard',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            _transportType == 'urgent' ? 'Ambulance & Urgence Médicale' : 'Rendez-vous & Transport Médical',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.accentGlow.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildServiceGrid(),
                          const SizedBox(height: 20),
                          _buildPharmacyButton(),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),

                  // 🚗 COURSE ACTIVE (SI EXISTE)
                  if (_activeRide != null)
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildActiveRideCard(context),
                    )),

                  // 📊 STATISTIQUES RAPIDES
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildQuickStats(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),

                  // 🕒 COURSES RÉCENTES
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildRecentRidesHeader(),
                    ),
                  ),
                  
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: _isLoadingRides
                        ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
                        : _recentRides.isEmpty
                            ? SliverToBoxAdapter(child: _buildEmptyRidesCard())
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildRideCard(_recentRides[index]),
                                  childCount: _recentRides.length,
                                ),
                              ),
                  ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          
          // 🧭 NAVIGATION CUSTOM
          Positioned(
            bottom: 25,
            left: 20,
            right: 20,
            child: _buildCustomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour,',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Bouton Notifications
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                ),
              ),
              const SizedBox(width: 12),
              // Profil / Menu
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: AppColors.glowGradient,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.darkBg,
                    child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid() {
    if (_transportType == 'urgent') {
      return _buildServiceCard(
        'Urgence',
        'Ambulance 24/7',
        Icons.emergency,
        const Color(0xFFFF5252),
        () => _startNewRide('urgent'),
      );
    } else {
      return _buildServiceCard(
        'Médecin',
        'Soin Standard',
        Icons.health_and_safety,
        const Color(0xFF467DB0),
        () => _startNewRide('non-urgent'),
      );
    }
  }

  Widget _buildPharmacyButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PharmacyMapScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_pharmacy_rounded, color: Colors.greenAccent, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pharmacie de garde',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Trouvez les services ouverts 24h/7',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }

  void _startNewRide(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewRideScreen(patientProfile: _patientProfile),
      ),
    );
  }

  Widget _buildServiceCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.2), blurRadius: 15, spreadRadius: 0),
                ],
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGlow.withOpacity(0.1),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('Courses', _totalRides.toString(), Icons.directions_car_rounded, AppColors.accentGlow),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
          _buildMiniStat('Note', _averageRating.toStringAsFixed(1), Icons.star_rounded, Colors.amber),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
          _buildMiniStat('Rang', 'Or', Icons.verified_rounded, Colors.purpleAccent),
        ],
      ),
    );
  }
  
  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }


  Widget _buildCustomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(35),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavIcon(Icons.home_filled, true),
          _buildNavIcon(Icons.history, false, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PatientRidesHistoryScreen(patientProfile: _patientProfile)))),
          _buildNavIcon(Icons.notifications_none, false, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
          _buildNavIcon(Icons.person_outline_rounded, false, onTap: () => _scaffoldKey.currentState?.openDrawer()),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, bool active, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF467DB0) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? Colors.white : Colors.white60, size: 26),
      ),
    );
  }

  Widget _buildRecentRidesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Courses Récentes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PatientRidesHistoryScreen(patientProfile: _patientProfile))),
          child: const Text('Voir tout', style: TextStyle(color: Color(0xFF467DB0), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  /// Widget pour afficher une course active
  Widget _buildActiveRideCard(BuildContext context) {
    if (_activeRide == null) return const SizedBox.shrink();

    final status = _activeRide!['status'] ?? 'pending';
    final destination = _activeRide!['destination_address'] ?? 'Destination';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_taxi, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COURSE EN COURS',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                    ),
                    Text(
                      destination,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _navigateToActiveRide(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF467DB0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text('Suivre'),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildRecentRidesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Courses récentes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatientRidesHistoryScreen(
                      patientProfile: _patientProfile,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Historique'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        _isLoadingRides
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                ),
              )
            : _recentRides.isEmpty
                ? _buildEmptyRidesCard()
                : Column(
                    children: _recentRides.map((ride) => _buildRideCard(ride)).toList(),
                  ),
      ],
    );
  }

  Widget _buildEmptyRidesCard() {
    return Container(
      padding: const EdgeInsets.all(32),
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
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucune course récente',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commandez votre premier transport !',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    String status = ride['status'] ?? 'pending';
    IconData statusIcon;
    Color statusColor;
    String statusText;
    bool showTrackButton = false;
    
    switch (status) {
      case 'pending':
        statusIcon = Icons.schedule;
        statusColor = Colors.orange;
        statusText = 'En attente';
        break;
      case 'accepted':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Acceptée';
        showTrackButton = true;
        break;
      case 'driver_en_route':
        statusIcon = Icons.drive_eta;
        statusColor = Colors.blue;
        statusText = 'Chauffeur en route';
        showTrackButton = true;
        break;
      case 'arrived':
        statusIcon = Icons.location_on;
        statusColor = Colors.green;
        statusText = 'Chauffeur arrivé';
        showTrackButton = true;
        break;
      case 'in_progress':
        statusIcon = Icons.local_taxi;
        statusColor = Colors.blue;
        statusText = 'En cours';
        showTrackButton = true;
        break;
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Terminée';
        break;
      case 'cancelled':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        statusText = 'Annulée';
        break;
      default:
        statusIcon = Icons.help;
        statusColor = Colors.grey;
        statusText = 'Statut inconnu';
    }
    
    // Formatter la date
    String dateStr = 'Date inconnue';
    if (ride['created_at'] != null) {
      try {
        DateTime date = DateTime.parse(ride['created_at']);
        dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(date);
      } catch (e) {
        dateStr = ride['created_at'].toString();
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showRideDetails(ride),
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride['destination_address'] ?? 'Destination',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${ride['total_price'] ?? 0} MAD',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 4),
                  if (showTrackButton)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Text('Suivi dispo', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRideDetails(Map<String, dynamic> ride) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Détails de la course',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.location_on, 'Destination', ride['destination_address'] ?? '-'),
            _buildDetailRow(Icons.payments, 'Prix total', '${ride['total_price'] ?? 0} DH'),
            _buildDetailRow(Icons.route, 'Distance', '${ride['distance_km'] ?? 0} km'),
            _buildDetailRow(Icons.schedule, 'Statut', ride['status'] ?? '-'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4CAF50)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFBFBFE),
      child: Column(
        children: [
          // 🎭 HEADER PREMIUM PATIENT (BLEU)
          Container(
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF467DB0), Color(0xFF2D5A88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(50)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Color(0xFF467DB0)),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _userPhone.isNotEmpty ? _userPhone : 'Patient YALLA L\'TBIB',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 📜 LISTE DES OPTIONS
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              children: [
                _buildSidebarSection('SERVICES'),
                _buildSidebarItem(Icons.home_outlined, 'Tableau de bord', true, () => Navigator.pop(context)),
                _buildSidebarItem(Icons.history_rounded, 'Mon Historique', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PatientRidesHistoryScreen(patientProfile: _patientProfile)));
                }),
                _buildSidebarItem(Icons.analytics_outlined, 'Mes Statistiques', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PatientStatisticsScreen(patientProfile: _patientProfile)));
                }),

                const SizedBox(height: 25),
                _buildSidebarSection('MON COMPTE'),
                _buildSidebarItem(Icons.person_outline_rounded, 'Profil & Informations', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PatientProfileScreen(patientProfile: _patientProfile)));
                }),
                _buildSidebarItem(Icons.notifications_active_outlined, 'Notifications', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                }),

                const SizedBox(height: 25),
                _buildSidebarSection('AIDE'),
                _buildSidebarItem(Icons.contact_support_outlined, 'Support Technique', false, () {}),
                _buildSidebarItem(Icons.info_outline_rounded, 'À propos', false, () {}),
              ],
            ),
          ),

          // 🚪 BOUTON DÉCONNEXION
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Déconnexion', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await DatabaseService.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, bottom: 10),
      child: Text(
        title,
        style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accentGlow.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isActive ? AppColors.accentGlow : Colors.grey[700], size: 24),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? AppColors.accentGlow : Colors.grey[800],
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: isActive 
          ? Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.accentGlow, borderRadius: BorderRadius.circular(10)))
          : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }
  /// Navigation vers le tracking de la course active
  Future<void> _navigateToActiveRide(BuildContext context) async {
    if (_activeRide == null) return;
    
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PatientRideTrackingScreen(rideId: _activeRide!['id'])),
      ).then((_) => _loadRecentRides());
    } catch (e) {
      print('❌ Erreur navigation: $e');
    }
  }
}
