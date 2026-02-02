import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/location_tracking_service.dart'; // 🎯 NOUVEAU
import '../supabase_service.dart';
import 'ride_tracking_screen.dart';
import 'onboarding_screens.dart';
import 'driver_profile_screen.dart';
import 'driver_rides_history_screen.dart';
import 'driver_statistics_screen.dart';

import 'driver/document_verification_screen.dart';

/// Dashboard pour les chauffeurs avec liste des courses en attente
class DriverDashboardReal extends StatefulWidget {
  final String driverId;
  
  const DriverDashboardReal({
    Key? key,
    required this.driverId,
  }) : super(key: key);

  @override
  State<DriverDashboardReal> createState() => _DriverDashboardRealState();
}

class _DriverDashboardRealState extends State<DriverDashboardReal> with WidgetsBindingObserver {
  bool _isOnline = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRides = [];
  Timer? _pollingTimer;
  
  // Stats du chauffeur
  Map<String, dynamic>? _driverProfile;
  int _todayCompletedRides = 0;
  double _todayEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDashboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // L'app est revenue au premier plan, rafraîchir les données
      print('🔄 App resumed, rafraîchissement dashboard driver...');
      _loadTodayStats();
      _loadPendingRides();
    }
  }

  Future<void> _initializeDashboard() async {
    await _loadDriverProfile();
    await _loadTodayStats();
    await _loadPendingRides();
    
    // ✅ Vérifier s'il y a une course active sauvegardée
    await _checkAndRestoreActiveRide();
    
    setState(() => _isLoading = false);
    
    // Démarrer le polling pour les nouvelles courses
    _startPolling();
  }
  
  /// Vérifie et restaure une course en cours si l'app a été fermée
  Future<void> _checkAndRestoreActiveRide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeRideId = prefs.getString('active_ride_id');
      final savedDriverId = prefs.getString('active_ride_driver_id');
      
      // Vérifier que c'est bien pour ce chauffeur
      if (activeRideId != null && savedDriverId == widget.driverId) {
        print('🔍 Course active trouvée: $activeRideId, vérification du statut...');
        
        // Récupérer la course depuis la DB
        final ride = await DatabaseService.client
            .from('rides')
            .select('*')
            .eq('id', activeRideId)
            .single();
        
        final status = ride['status'] as String;
        
        // Si la course n'est pas terminée, la restaurer
        if (status != 'completed' && status != 'cancelled') {
          print('🔄 Restauration de la course en cours: $activeRideId (statut: $status)');
          
          // Récupérer les infos du chauffeur
          final driverData = await DatabaseService.client
              .from('drivers')
              .select('''
                *,
                vehicles(*)
              ''')
              .eq('id', widget.driverId)
              .single();
          
          // Rediriger automatiquement vers l'écran de tracking
          if (mounted) {
            Future.delayed(Duration(milliseconds: 500), () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RideTrackingScreen(
                    rideData: ride,
                    driver: driverData,
                  ),
                ),
              ).then((_) async {
                // Quand on revient, rafraîchir et supprimer si terminée
                _loadTodayStats();
                _loadPendingRides();
                
                final updatedRide = await DatabaseService.client
                    .from('rides')
                    .select('status')
                    .eq('id', activeRideId)
                    .single();
                
                if (updatedRide['status'] == 'completed' || updatedRide['status'] == 'cancelled') {
                  await prefs.remove('active_ride_id');
                  await prefs.remove('active_ride_driver_id');
                  print('🗑️ Course active supprimée (terminée après retour)');
                }
              });
            });
          }
        } else {
          // Course déjà terminée, nettoyer
          await prefs.remove('active_ride_id');
          await prefs.remove('active_ride_driver_id');
          print('🗑️ Course sauvegardée déjà terminée, nettoyage');
        }
      }
    } catch (e) {
      print('❌ Erreur vérification course active: $e');
      // En cas d'erreur, nettoyer quand même
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_ride_id');
      await prefs.remove('active_ride_driver_id');
    }
  }

  Future<void> _loadDriverProfile() async {
    try {
      final profile = await DatabaseService.client
          .from('drivers')
          .select('''
            *,
            vehicles(*)
          ''')
          .eq('id', widget.driverId)
          .single();
      
      setState(() {
        _driverProfile = profile;
        _isOnline = profile['is_available'] ?? false;
      });
      
      print('✅ Profil chauffeur chargé: ${profile['first_name']} ${profile['last_name']}');
    } catch (e) {
      print('❌ Erreur chargement profil chauffeur: $e');
    }
  }

  Future<void> _loadTodayStats() async {
    try {
      // Charger TOUTES les courses complétées (pas seulement aujourd'hui)
      final stats = await DatabaseService.client
          .from('rides')
          .select('status, total_price, created_at')
          .eq('driver_id', widget.driverId)
          .eq('status', 'completed');
      
      int totalCompletedCount = 0;
      double totalEarnings = 0.0;
      
      // Calculer le total de TOUTES les courses
      for (var ride in stats) {
        totalCompletedCount++;
        totalEarnings += (ride['total_price'] as num?)?.toDouble() ?? 0.0;
      }
      
      setState(() {
        _todayCompletedRides = totalCompletedCount;
        _todayEarnings = totalEarnings;
      });
      
      print('📊 Stats totales: $totalCompletedCount courses complétées, $totalEarnings MAD gagnés');
    } catch (e) {
      print('❌ Erreur chargement stats: $e');
    }
  }

  Future<void> _loadPendingRides() async {
    try {
      final rides = await DatabaseService.client
          .from('rides')
          .select('''
            *,
            patients!inner(
              first_name,
              last_name
            )
          ''')
          .eq('status', 'pending')
          .isFilter('driver_id', null)
          .order('created_at', ascending: false)
          .limit(20);
      
      setState(() {
        _pendingRides = List<Map<String, dynamic>>.from(rides);
      });
      
      print('🚗 ${rides.length} courses en attente chargées');
    } catch (e) {
      print('❌ Erreur chargement courses en attente: $e');
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isOnline && mounted) {
        _loadPendingRides();
      }
    });
  }

  Future<void> _toggleOnlineStatus() async {
    try {
      // 🛡️ Vérification du compte avant de passer en ligne
      if (_driverProfile?['status'] != 'active') {
        _showSnackBar('🚫 Votre compte doit être vérifié avant de passer en ligne', Colors.red);
        return;
      }

      final newStatus = !_isOnline;
      
      await DatabaseService.client
          .from('drivers')
          .update({'is_available': newStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', widget.driverId);
      
      setState(() => _isOnline = newStatus);
      
      if (newStatus) {
        // ✅ GPS AUTO-START quand passe EN LIGNE
        print('📍 Démarrage tracking GPS pour driver: ${widget.driverId}');
        await LocationTrackingService.startTracking(driverId: widget.driverId);
        
        _showSnackBar('✅ Vous êtes maintenant EN LIGNE', Colors.green);
        // 🔥 NOUVEAU : Charger immédiatement les courses + stats
        await _loadPendingRides();
        await _loadTodayStats();
        print('🔄 Courses rechargées après passage EN LIGNE');
      } else {
        // 🛑 GPS STOP quand passe HORS LIGNE
        print('🛑 Arrêt tracking GPS');
        await LocationTrackingService.stopTracking();
        
        _showSnackBar('🔴 Vous êtes maintenant HORS LIGNE', Colors.orange);
      }
    } catch (e) {
      print('❌ Erreur changement statut: $e');
      _showSnackBar('❌ Erreur de connexion', Colors.red);
    }
  }

  Future<void> _acceptRide(Map<String, dynamic> ride) async {
    try {
      final rideId = ride['id'] as String;
      
      // Mise à jour de la course
      await DatabaseService.client
          .from('rides')
          .update({
            'driver_id': widget.driverId,
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);
      
      // ✅ IMPORTANT: Sauvegarder l'ID de la course en cours
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_ride_id', rideId);
      await prefs.setString('active_ride_driver_id', widget.driverId);
      print('💾 Course active sauvegardée: $rideId');
      
      _showSnackBar('✅ Course acceptée !', Colors.green);
      
      // Recharger la liste ET les stats
      await _loadPendingRides();
      await _loadTodayStats();
      
      // Récupérer les infos complètes du chauffeur avec véhicule
      final driverData = await DatabaseService.client
          .from('drivers')
          .select('''
            *,
            vehicles(*)
          ''')
          .eq('id', widget.driverId)
          .single();
      
      // Navigation vers l'écran de tracking
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RideTrackingScreen(
              rideData: ride,
              driver: driverData,
            ),
          ),
        ).then((_) async {
          // Quand on revient du tracking, rafraîchir les stats
          _loadTodayStats();
          _loadPendingRides();
          
          // Supprimer la course active si elle est terminée
          final updatedRide = await DatabaseService.client
              .from('rides')
              .select('status')
              .eq('id', rideId)
              .single();
          
          if (updatedRide['status'] == 'completed' || updatedRide['status'] == 'cancelled') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('active_ride_id');
            await prefs.remove('active_ride_driver_id');
            print('🗑️ Course active supprimée (terminée)');
          }
        });
      }
    } catch (e) {
      print('❌ Erreur acceptation course: $e');
      _showSnackBar('❌ Erreur lors de l\'acceptation', Colors.red);
    }
  }

  Future<void> _rejectRide(Map<String, dynamic> ride) async {
    // Pour l'instant, on retire juste de la liste
    // En production, on pourrait marquer comme "rejetée par ce chauffeur"
    _showSnackBar('Course ignorée', Colors.orange);
    await _loadPendingRides();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 📋 Drawer (Sidebar) avec options de navigation
  Widget _buildDrawer(BuildContext context, String driverName) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header du Drawer
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.green,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.green),
                ),
                const SizedBox(height: 12),
                Text(
                  driverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _driverProfile?['email'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Option : Dashboard
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.green),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context); // Fermer le drawer
            },
          ),
          
          // Option : Profil
          ListTile(
            leading: const Icon(Icons.person, color: Colors.green),
            title: const Text('Mon Profil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DriverProfileScreen(
                    driverProfile: _driverProfile,
                  ),
                ),
              );
            },
          ),
          
          // Option : Historique
          ListTile(
            leading: const Icon(Icons.history, color: Colors.green),
            title: const Text('Historique des Courses'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DriverRidesHistoryScreen(
                    driverProfile: _driverProfile,
                  ),
                ),
              );
            },
          ),
          
          // Option : Statistiques
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.green),
            title: const Text('Statistiques'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DriverStatisticsScreen(
                    driverProfile: _driverProfile,
                  ),
                ),
              );
            },
          ),
          
          const Divider(),
          
          // Option : Paramètres
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('Paramètres'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
              );
            },
          ),
          
          // Option : Aide
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.grey),
            title: const Text('Aide & Support'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
              );
            },
          ),
          
          const Divider(),
          
          // 🚪 Option : DÉCONNEXION (EN ROUGE)
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text(
              'Se Déconnecter',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              // Confirmation avant déconnexion
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Déconnexion'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true && mounted) {
                // Passer hors ligne avant de se déconnecter
                await DatabaseService.client
                    .from('drivers')
                    .update({'is_available': false})
                    .eq('id', widget.driverId);
                
                // Déconnexion Supabase
                await SupabaseService.client.auth.signOut();
                
                // Retour à l'écran d'onboarding
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                    (route) => false,
                  );
                }
                
                print('👋 Déconnexion réussie');
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final driverName = _driverProfile != null
        ? '${_driverProfile!['first_name']} ${_driverProfile!['last_name']}'
        : 'Chauffeur';

    return Scaffold(
      appBar: AppBar(
        // 🍔 NOUVEAU : Bouton menu hamburger pour ouvrir le Drawer
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard Chauffeur', style: TextStyle(fontSize: 18)),
            Text(
              driverName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Toggle En ligne / Hors ligne
          Row(
            children: [
              Text(
                _isOnline ? 'EN LIGNE' : 'HORS LIGNE',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _isOnline,
                onChanged: (value) => _toggleOnlineStatus(),
                activeColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 📋 NOUVEAU : Drawer (sidebar) avec menu
      drawer: _buildDrawer(context, driverName),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadPendingRides();
          await _loadTodayStats();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🛡️ Bannière de vérification (Glow Style)
            if (_driverProfile?['status'] != 'active')
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
                        SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'Vérification requise',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Veuillez uploader vos documents pour commencer à accepter des courses.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DocumentVerificationScreen(driverId: widget.driverId),
                          ),
                        ).then((_) => _loadDriverProfile());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('VÉRIFIER MON COMPTE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Statut
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isOnline ? Colors.green[50] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isOnline ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOnline ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _isOnline ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? 'Vous êtes EN LIGNE' : 'Vous êtes HORS LIGNE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isOnline ? Colors.green[800] : Colors.grey[700],
                          ),
                        ),
                        Text(
                          _isOnline
                              ? 'Vous pouvez recevoir des courses'
                              : 'Activez pour recevoir des courses',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Statistiques TOTALES (pas seulement aujourd'hui)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Courses complétées',
                    _todayCompletedRides.toString(),
                    Icons.check_circle,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Revenus totaux',
                    '${_todayEarnings.toStringAsFixed(0)} MAD',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Liste des courses en attente
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Courses en attente',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadPendingRides,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!_isOnline)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Activez le mode EN LIGNE pour voir les courses disponibles',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            if (_isOnline && _pendingRides.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune course en attente pour le moment',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nous vous notifierons dès qu\'une nouvelle course sera disponible',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            if (_isOnline)
              ..._pendingRides.map((ride) => _buildRideCard(ride)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final patient = ride['patients'];
    final patientName = patient != null
        ? '${patient['first_name']} ${patient['last_name']}'
        : 'Patient';
    
    final pickupAddress = ride['pickup_address'] ?? 'Adresse de départ';
    final destinationAddress = ride['destination_address'] ?? 'Destination';
    final totalPrice = (ride['total_price'] as num?)?.toDouble() ?? 0.0;
    final distance = (ride['distance_km'] as num?)?.toDouble() ?? 0.0;
    final duration = (ride['duration_minutes'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Course ${ride['ride_type']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalPrice MAD',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Trajet
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle, size: 12, color: Colors.blue),
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.grey[300],
                    ),
                    const Icon(Icons.location_on, size: 16, color: Colors.red),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickupAddress,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        destinationAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Infos course
            Row(
              children: [
                Icon(Icons.route, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${distance.toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$duration min',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRide(ride),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _acceptRide(ride),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accepter la course'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
