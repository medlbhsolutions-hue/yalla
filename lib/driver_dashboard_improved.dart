import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;
import 'package:latlong2/latlong.dart'; // Pour LatLng (OSM)
import 'package:geolocator/geolocator.dart'; // 📍 Pour position GPS
import 'package:supabase_flutter/supabase_flutter.dart'; // 🔔 Pour Realtime
import 'dart:async'; // 🔔 Pour Timer
import 'src/services/database_service.dart';
import 'src/services/notification_service.dart'; // 🔔 NOUVEAU
import 'src/services/location_tracking_service.dart'; // 📍 GPS Tracking
import 'src/services/ride_proposal_service.dart'; // 🎯 PHASE 2: Propositions
import 'src/screens/onboarding_screens.dart'; // 🎨 NOUVEAU : Onboarding
import 'src/screens/driver_profile_screen.dart';
import 'src/screens/driver/driver_profile_complete_screen.dart'; // 📄 Documents chauffeur
import 'src/screens/driver/driver_documents_status_screen.dart'; // 📊 Suivi validation documents
import 'src/screens/driver_rides_history_screen.dart';
import 'src/screens/driver_statistics_screen.dart';
import 'src/screens/notifications_screen.dart'; // 🔔 NOUVEAU
import 'src/screens/driver/available_rides_screen.dart'; // 🚀 PHASE 2.5: Courses disponibles
import 'src/screens/driver/active_ride_screen.dart'; // 🚗 Écran course active
import 'screens/ride_tracking_screen.dart'; // 🚗 Pour tracking GPS
import 'src/utils/app_colors.dart';

/// Dashboard Driver Amélioré avec Statistiques, Historique et Profil
class DriverDashboard extends StatefulWidget {
  const DriverDashboard({Key? key}) : super(key: key);

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _driverProfile;
  bool _isLoadingProfile = true;
  String _driverName = 'Chauffeur';
  String _vehicleInfo = '';
  bool _isOnline = false;
  String _driverPhone = '';
  
  // Statistiques
  int _totalRides = 0;
  int _todayRides = 0;
  double _totalEarnings = 0.0;
  double _todayEarnings = 0.0;
  double _averageRating = 0.0;
  
  // Courses récentes
  List<Map<String, dynamic>> _recentRides = [];
  bool _isLoadingRides = false;
  bool _isLoadingRecentRides = false;
  
  // Courses disponibles (sans chauffeur)
  List<Map<String, dynamic>> _availableRides = [];
  bool _isLoadingAvailableRides = false;
  
  // 🎯 PHASE 2: Propositions de courses
  List<Map<String, dynamic>> _proposedRides = [];
  bool _isLoadingProposals = false;
  
  // 🔔 REALTIME: Écoute des nouvelles courses
  RealtimeChannel? _ridesChannel;
  int _newRidesCount = 0; // Compteur de nouvelles courses non vues
  
  // 📍 Position GPS courante
  LatLng? _currentPosition;

  // 🚑 Type de transport (Urgent / Non-Urgent)
  String _transportType = 'non-urgent';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Récupérer le type de transport depuis les arguments de la route
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
    _loadDriverData();
    _loadAvailableRides(); // Charger les courses disponibles
    _loadProposedRides(); // 🎯 PHASE 2: Charger propositions
    _startLocationTracking(); // 📍 Démarrer tracking GPS
    _subscribeToNewRides(); // 🔔 Écouter nouvelles courses en temps réel
  }

  @override
  void dispose() {
    LocationTrackingService.stopTracking(); // 🛑 Arrêter tracking GPS
    _ridesChannel?.unsubscribe(); // 🛑 Arrêter écoute Realtime
    super.dispose();
  }
  
  /// 🔔 Écoute temps réel des nouvelles courses
  void _subscribeToNewRides() {
    final supabase = Supabase.instance.client;
    
    _ridesChannel = supabase
        .channel('new_rides_for_driver')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rides',
          callback: (payload) {
            print('🔔 NOUVELLE COURSE DÉTECTÉE: ${payload.newRecord}');
            
            // Vérifier que c'est une course en attente
            if (payload.newRecord['status'] == 'pending') {
              setState(() {
                _newRidesCount++;
              });
              
              // Afficher notification si chauffeur en ligne
              if (_isOnline) {
                _showNewRideNotification(payload.newRecord);
              }
              
              // Recharger les courses disponibles
              _loadAvailableRides();
            }
          },
        )
        .subscribe();
    
    print('🔔 Écoute temps réel des nouvelles courses activée');
  }
  
  /// 🔔 Afficher notification de nouvelle course
  void _showNewRideNotification(Map<String, dynamic> ride) {
    final price = ride['estimated_price'] ?? 0;
    final destination = ride['destination_address'] ?? 'Destination';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.local_taxi, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🚨 NOUVELLE COURSE !',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${price.toStringAsFixed(0)} MAD - $destination',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'VOIR',
          textColor: Colors.white,
          onPressed: () {
            // Naviguer vers les courses disponibles
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AvailableRidesScreen(
                  driverProfile: _driverProfile,
                  driverLocation: _currentPosition ?? const LatLng(33.5731, -7.5898),
                ),
              ),
            ).then((_) {
              setState(() => _newRidesCount = 0);
              _loadAvailableRides();
            });
          },
        ),
      ),
    );
  }

  /// Démarre le tracking GPS automatique
  Future<void> _startLocationTracking() async {
    // Attendre que le profil soit chargé
    await Future.delayed(const Duration(seconds: 2));
    
    // Obtenir la position actuelle
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print('⚠️ Erreur obtention position: $e');
      // Position par défaut: Casablanca
      setState(() {
        _currentPosition = const LatLng(33.5731, -7.5898);
      });
    }
    
    if (_driverProfile != null && _driverProfile!['id'] != null) {
      print('📍 Démarrage tracking GPS pour driver: ${_driverProfile!['id']}');
      await LocationTrackingService.startTracking(
        driverId: _driverProfile!['id'],
      );
    }
  }

  Future<void> _loadDriverData() async {
    setState(() { _isLoadingProfile = true; });
    
    try {
      // Créer automatiquement le profil s'il n'existe pas
      final profile = await DatabaseService.ensureDriverProfile();
      
      if (profile != null) {
        setState(() {
          _driverProfile = profile;
          _driverName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
          if (_driverName.isEmpty) _driverName = 'Chauffeur YALLA L\'TBIB';
          
          _isOnline = (profile['account_status'] == 'active') ? (profile['is_available'] ?? false) : false;
          _driverPhone = profile['phone_number'] ?? '';
          _isLoadingProfile = false;
        });
        
        // Charger véhicule séparément
        _loadVehicleInfo(profile['id']);
        
        // Charger statistiques et courses en parallèle
        await Future.wait([
          _loadStatistics(),
          _loadRecentRides(),
        ]);
      } else {
        setState(() {
          _driverName = 'Chauffeur YALLA L\'TBIB';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement profil driver: $e');
      setState(() {
        _driverName = 'Chauffeur';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadVehicleInfo(String driverId) async {
    try {
      final response = await DatabaseService.client
          .from('vehicles')
          .select('make, model, plate_number')
          .eq('driver_id', driverId)
          .maybeSingle();
      
      if (response != null && mounted) {
        setState(() {
          _vehicleInfo = '${response['make'] ?? ''} ${response['model'] ?? ''}'.trim();
        });
      }
    } catch (e) {
      print('⚠️ Erreur chargement véhicule: $e');
    }
  }

  Future<void> _loadStatistics() async {
    if (_driverProfile == null) return;
    
    try {
      final allRides = await DatabaseService.getDriverRides(
        driverId: _driverProfile!['id'],
      );
      
      int totalRides = 0;
      int todayRides = 0;
      double totalEarnings = 0.0;
      double todayEarnings = 0.0;
      double totalRating = 0.0;
      int ratedRides = 0;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      for (var ride in allRides) {
        if (ride['status'] == 'completed') {
          totalRides++;
          double earnings = ((ride['total_price'] as num?)?.toDouble() ?? 0.0) * 0.9;
          totalEarnings += earnings;
          
          // Vérifier si c'est aujourd'hui
          if (ride['created_at'] != null) {
            final createdAt = DateTime.parse(ride['created_at']);
            final rideDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
            if (rideDate.isAtSameMomentAs(today)) {
              todayRides++;
              todayEarnings += earnings;
            }
          }
          
          if (ride['driver_rating'] != null) {
            totalRating += (ride['driver_rating'] as num).toDouble();
            ratedRides++;
          }
        }
      }
      
      setState(() {
        _totalRides = totalRides;
        _todayRides = todayRides;
        _totalEarnings = totalEarnings;
        _todayEarnings = todayEarnings;
        _averageRating = ratedRides > 0 ? totalRating / ratedRides : 0.0;
      });
    } catch (e) {
      print('❌ Erreur chargement statistiques: $e');
    }
  }

  Future<void> _loadRecentRides() async {
    if (_driverProfile == null) return;
    
    setState(() { _isLoadingRides = true; });
    
    try {
      final rides = await DatabaseService.getDriverRides(
        driverId: _driverProfile!['id'],
        limit: 5,
      );
      
      setState(() {
        _recentRides = rides;
        _isLoadingRides = false;
      });
    } catch (e) {
      print('❌ Erreur chargement courses driver: $e');
      setState(() { _isLoadingRides = false; });
    }
  }

  Future<void> _loadAvailableRides() async {
    setState(() { _isLoadingAvailableRides = true; });
    
    try {
      final rides = await DatabaseService.getAvailableRides(limit: 20);
      
      setState(() {
        _availableRides = rides;
        _isLoadingAvailableRides = false;
      });
    } catch (e) {
      print('❌ Erreur chargement courses disponibles: $e');
      setState(() { _isLoadingAvailableRides = false; });
    }
  }

  /// 🎯 PHASE 2: Charger les propositions de courses
  Future<void> _loadProposedRides() async {
    if (_driverProfile == null) return;
    
    setState(() { _isLoadingProposals = true; });
    
    try {
      final proposals = await RideProposalService.getPendingProposals(
        driverId: _driverProfile!['id'],
      );
      
      setState(() {
        _proposedRides = proposals;
        _isLoadingProposals = false;
      });
      
      print('✅ ${proposals.length} propositions chargées');
    } catch (e) {
      print('❌ Erreur chargement propositions: $e');
      setState(() { _isLoadingProposals = false; });
    }
  }

  Future<void> _acceptRide(String rideId) async {
    if (_driverProfile == null) return;
    
    // Afficher dialog de confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accepter cette course ?'),
        content: const Text('Vous allez être assigné à cette course.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Afficher loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    
    try {
      final success = await DatabaseService.acceptRide(
        rideId: rideId,
        driverId: _driverProfile!['id'],
      );
      
      if (mounted) {
        Navigator.pop(context); // Fermer loading
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Course acceptée avec succès !'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
          
          // Recharger les listes
          await Future.wait([
            _loadAvailableRides(),
            _loadRecentRides(),
          ]);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Cette course a déjà été acceptée par un autre chauffeur'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fermer loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_driverProfile == null) return;
    
    // 🚨 Bloquer si le compte n'est pas actif (vérifié)
    if (_driverProfile!['account_status'] != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Votre compte doit être validé par un administrateur pour passer en ligne.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final newStatus = !_isOnline;
      await DatabaseService.updateDriverAvailability(newStatus);
      
      setState(() { _isOnline = newStatus; });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus 
              ? '✅ Vous êtes maintenant en ligne' 
              : '⏸️ Vous êtes maintenant hors ligne'),
            backgroundColor: newStatus ? const Color(0xFF4CAF50) : Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur changement statut: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
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
                    Colors.green.withOpacity(0.15),
                    AppColors.darkBg,
                  ],
                ),
              ),
            ),
          ),
          
          // ✨ Points de lumière décoratifs
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadDriverData,
              color: const Color(0xFF2E7D32),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 👤 EN-TÊTE CHAUFFEUR
                  SliverToBoxAdapter(child: _buildDriverHeader()),

                  // 🚨 BANNIÈRE DE VÉRIFICATION SI BESOIN
                  if (_driverProfile != null && _driverProfile!['account_status'] != 'active')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: _buildVerificationBanner(),
                      ),
                    ),

                  // 🔘 TOGGLE STATUT EN LIGNE
                  SliverToBoxAdapter(child: _buildPremiumStatusToggle()),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),

                  // 🎯 COURSES PROPOSÉES (ALERTE)
                  if (_isOnline && _proposedRides.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildProposedRidesSection(context),
                      ),
                    ),

                  // 📊 STATISTIQUES AUJOURD'HUI
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Aujourd'hui",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDriverQuickStats(),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),

                  // 🏠 GESTION DES COURSES
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _isOnline 
                        ? _buildAvailableRidesSection(context)
                        : _buildOfflinePlaceholder(),
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
                    sliver: _isLoadingRecentRides
                        ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
                        : _recentRides.isEmpty
                            ? SliverToBoxAdapter(child: _buildEmptyRidesCard())
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildRecentRideCard(_recentRides[index]),
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
            child: _buildCustomDriverNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard Chauffeur',
                style: TextStyle(
                  color: Colors.green.withOpacity(0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                _driverName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  _transportType == 'urgent' ? 'TRANSPORT URGENT' : 'TRANSPORT MÉDICAL STANDARD',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          // Profil / Menu
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: AppColors.successGradient,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.darkBg,
                child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatusToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: (_isOnline ? Colors.green : Colors.black).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.greenAccent : Colors.white38,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isOnline) BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  _isOnline ? 'EN LIGNE' : 'HORS LIGNE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _isOnline ? Colors.greenAccent : Colors.white38,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            Switch(
              value: _isOnline,
              onChanged: (value) => _toggleOnlineStatus(),
              activeColor: Colors.greenAccent,
              activeTrackColor: Colors.greenAccent.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverQuickStats() {
    return Row(
      children: [
        _buildDriverStatCard('Gains', '${_todayEarnings.toStringAsFixed(0)} MAD', Icons.wallet_rounded, Colors.greenAccent),
        const SizedBox(width: 15),
        _buildDriverStatCard('Note', _averageRating.toStringAsFixed(1), Icons.star_rounded, Colors.amberAccent),
        const SizedBox(width: 15),
        _buildDriverStatCard('Statut', 'Premium', Icons.verified_rounded, Colors.blueAccent),
      ],
    );
  }

  Widget _buildDriverStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDriverNavBar() {
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
          _buildNavIcon(Icons.dashboard_rounded, true),
          _buildNavIcon(Icons.history, false, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DriverRidesHistoryScreen(driverProfile: _driverProfile)))),
          _buildNavIcon(Icons.bar_chart_rounded, false, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DriverStatisticsScreen(driverProfile: _driverProfile)))),
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
          color: active ? const Color(0xFF2E7D32) : Colors.transparent,
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
          'Activités Récentes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DriverRidesHistoryScreen(driverProfile: _driverProfile))),
          child: const Text('Historique', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isOnline 
            ? [const Color(0xFF4CAF50), const Color(0xFF45a049)]
            : [Colors.grey[600]!, Colors.grey[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isOnline ? const Color(0xFF4CAF50) : Colors.grey).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Icon(
                  _isOnline ? Icons.check_circle : Icons.offline_bolt,
                  color: _isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                  size: 35,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline ? '🟢 Vous êtes en ligne' : '⚫ Vous êtes hors ligne',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnline 
                        ? 'Vous pouvez recevoir des demandes' 
                        : 'Activez pour recevoir des courses',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged: (value) => _toggleOnlineStatus(),
                activeColor: Colors.white,
                activeTrackColor: Colors.white24,
              ),
            ],
          ),
          
          if (_vehicleInfo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _vehicleInfo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mes statistiques',
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
                    builder: (context) => DriverStatisticsScreen(
                      driverProfile: _driverProfile,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Voir plus'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Grille de statistiques
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildStatCard(
              icon: Icons.directions_car,
              label: 'Courses',
              value: _totalRides.toString(),
              color: Colors.blue,
            ),
            _buildStatCard(
              icon: Icons.payments,
              label: 'Revenus',
              value: '${_totalEarnings.toStringAsFixed(0)} DH',
              color: Colors.green,
            ),
            _buildStatCard(
              icon: Icons.star,
              label: 'Note moy.',
              value: _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '-',
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 🎯 PHASE 2: Section des courses proposées
  Widget _buildProposedRidesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.deepOrange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 8),
              const Text(
                '🚨 Courses Proposées',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_proposedRides.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Répondez rapidement ! Les courses expirent après 60 secondes.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          
          // Liste des propositions
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _proposedRides.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final proposal = _proposedRides[index];
              final ride = proposal['rides'] as Map<String, dynamic>?;
              
              if (ride == null) return const SizedBox.shrink();
              
              return _buildProposalCard(context, proposal, ride);
            },
          ),
        ],
      ),
    );
  }

  /// Carte d'une proposition individuelle avec timer et boutons
  Widget _buildProposalCard(
    BuildContext context, 
    Map<String, dynamic> proposal, 
    Map<String, dynamic> ride
  ) {
    final expiresAt = proposal['expires_at'] as String;
    final expiresDateTime = DateTime.parse(expiresAt);
    final distanceKm = proposal['distance_km'] as num?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    StreamBuilder<int>(
                      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                      builder: (context, snapshot) {
                        final now = DateTime.now();
                        final remaining = expiresDateTime.difference(now).inSeconds;
                        return Text(
                          remaining > 0 ? '${remaining}s' : 'Expansé',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Text(
                '${ride['estimated_price'] ?? 0} MAD',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 24),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Destination', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      ride['destination_address'] ?? 'Destination',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectProposal(proposal['id']),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptProposal(proposal['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                  ),
                  child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Accepter une proposition de course
  Future<void> _acceptProposal(String proposalId) async {
    final result = await RideProposalService.acceptProposal(proposalId: proposalId);
    
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Course acceptée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Recharger les données
      await Future.wait([
        _loadProposedRides(),
        _loadRecentRides(),
      ]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['error'] ?? 'Erreur inconnue'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Refuser une proposition de course
  Future<void> _rejectProposal(String proposalId) async {
    final result = await RideProposalService.rejectProposal(proposalId: proposalId);
    
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course refusée'),
          backgroundColor: Colors.orange,
        ),
      );
      
      await _loadProposedRides();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['error'] ?? 'Erreur inconnue'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAvailableRidesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📋 Courses disponibles',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 🚀 PHASE 2.5: Bouton "Voir toutes"
            TextButton.icon(
              onPressed: () async {
                // Récupérer la position actuelle pour le tri
                LatLng? driverLocation;
                final currentPos = await LocationTrackingService.getCurrentPosition();
                if (currentPos != null) {
                  driverLocation = LatLng(currentPos.latitude, currentPos.longitude);
                }
                
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AvailableRidesScreen(
                      driverProfile: _driverProfile,
                      driverLocation: driverLocation,
                    ),
                  ),
                );
                
                // Rafraîchir si une course a été acceptée
                if (result == true) {
                  _loadDriverData();
                }
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Voir toutes'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        if (_isLoadingAvailableRides)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            ),
          )
        else if (_availableRides.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
                Icon(Icons.inbox_outlined, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Aucune course disponible pour le moment',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Les nouvelles courses apparaîtront ici',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _availableRides.length,
            itemBuilder: (context, index) {
              final ride = _availableRides[index];
              return _buildAvailableRideCard(context, ride);
            },
          ),
      ],
    );
  }

  Widget _buildAvailableRideCard(BuildContext context, Map<String, dynamic> ride) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_taxi, color: Color(0xFF2E7D32), size: 24),
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
                    Text(
                      '${(ride['distance_km'] as num?)?.toStringAsFixed(1) ?? '0'} km • Patient: ${ride['patient_name'] ?? 'Inconnu'}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${ride['total_price'] ?? 0} MAD',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
        ),
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
                    builder: (context) => DriverRidesHistoryScreen(
                      driverProfile: _driverProfile,
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
        
        _isLoadingRecentRides // Renamed from _isLoadingRides
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                ),
              )
            : _recentRides.isEmpty
                ? _buildEmptyRidesCard()
                : Column(
                    children: _recentRides.map((ride) => _buildRecentRideCard(ride)).toList(), // Changed to _buildRecentRideCard
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
            _isOnline 
              ? 'Attendez les demandes de course !'
              : 'Activez le mode en ligne pour commencer',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRideCard(Map<String, dynamic> ride) { // Renamed from _buildRideCard
    String status = ride['status'] ?? 'pending';
    IconData statusIcon;
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Terminée';
        break;
      case 'in_progress':
        statusIcon = Icons.local_taxi;
        statusColor = Colors.blue;
        statusText = 'En cours';
        break;
      case 'cancelled':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        statusText = 'Annulée';
        break;
      default:
        statusIcon = Icons.schedule;
        statusColor = Colors.orange;
        statusText = 'En attente';
    }
    
    // Formatter la date (Simplifié pour le design premium)
    String dateStr = 'Date inconnue';
    if (ride['created_at'] != null) {
      try {
        DateTime date = DateTime.parse(ride['created_at']);
        dateStr = DateFormat('dd/MM HH:mm').format(date);
      } catch (e) {
        dateStr = '-';
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
                  Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRideDetails(Map<String, dynamic> ride) {
    double netEarnings = 0.0;
    double commission = 0.0;
    if (ride['total_price'] != null) {
      double totalPrice = (ride['total_price'] as num).toDouble();
      commission = totalPrice * 0.1; // 10% commission
      netEarnings = totalPrice * 0.9; // 90% pour le chauffeur
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Padding(
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
                _buildDetailRow(Icons.person, 'Patient', ride['patient_name'] ?? '-'),
                _buildDetailRow(Icons.route, 'Distance', '${ride['distance_km'] ?? 0} km'),
                _buildDetailRow(Icons.schedule, 'Statut', ride['status'] ?? '-'),
                _buildDetailRow(Icons.payments, 'Prix total', '${ride['total_price'] ?? 0} DH'),
                _buildDetailRow(Icons.trending_down, 'Commission (10%)', '${commission.toStringAsFixed(0)} DH'),
                _buildDetailRow(Icons.account_balance_wallet, 'Votre revenu', '${netEarnings.toStringAsFixed(0)} DH', isHighlight: true),
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
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isHighlight ? const Color(0xFF4CAF50) : Colors.grey),
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                    color: isHighlight ? const Color(0xFF4CAF50) : Colors.black,
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
      backgroundColor: const Color(0xFFF8F9FB),
      child: Column(
        children: [
          // 🎭 HEADER PREMIUM
          Container(
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
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
                        child: Icon(Icons.local_taxi, size: 40, color: Color(0xFF2E7D32)),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        child: const Icon(Icons.verified, color: Colors.white, size: 14),
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
                        _driverName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                       Text(
                        _driverPhone.isNotEmpty ? _driverPhone : (_vehicleInfo.isNotEmpty ? _vehicleInfo : 'Chauffeur Partenaire'),
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
                _buildSidebarSection('GÉNÉRAL'),
                _buildSidebarItem(Icons.dashboard_outlined, 'Tableau de bord', true, () => Navigator.pop(context)),
                _buildSidebarItem(Icons.history_rounded, 'Historique des courses', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DriverRidesHistoryScreen(driverProfile: _driverProfile)));
                }),
                _buildSidebarItem(Icons.analytics_outlined, 'Statistiques de revenus', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DriverStatisticsScreen(driverProfile: _driverProfile)));
                }),

                const SizedBox(height: 25),
                _buildSidebarSection('MON ESPACE PARTENAIRE'),
                _buildSidebarItem(Icons.person_outline_rounded, 'Profil & Documents', false, () {
                  Navigator.pop(context);
                  // On ouvre le profil COMPLET qui contient la gestion des documents
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DriverProfileCompleteScreen(existingProfile: _driverProfile)));
                }),
                _buildSidebarItem(Icons.security_outlined, 'Vérification & Statuts', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverDocumentsStatusScreen()));
                }),

                const SizedBox(height: 25),
                _buildSidebarSection('SUPPORT'),
                _buildSidebarItem(Icons.settings_outlined, 'Paramètres', false, () {}),
                _buildSidebarItem(Icons.help_outline_rounded, 'Centre d\'aide', false, () {}),
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
        color: isActive ? const Color(0xFF2E7D32).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isActive ? const Color(0xFF2E7D32) : Colors.grey[700], size: 24),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF2E7D32) : Colors.grey[800],
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: isActive 
          ? Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(10)))
          : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }

  // --- NOUVEAUX WIDGETS PREMIUM ---

  Widget _buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vérification requise',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Veuillez uploader vos documents pour commencer à travailler.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DriverProfileCompleteScreen(existingProfile: _driverProfile)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('VÉRIFIER MON COMPTE', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflinePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.white.withOpacity(0.2), size: 60),
          const SizedBox(height: 15),
          Text(
            'Vous êtes HORS LIGNE',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            'Activez pour voir les courses disponibles',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
