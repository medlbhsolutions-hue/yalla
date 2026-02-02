import 'package:flutter/material.dart';
import 'dart:async'; // ✅ Ajouté pour StreamSubscription
import '../screens/map_screen.dart';
import '../screens/ride_tracking_screen.dart';
import '../services/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../src/utils/logger.dart'; // Pour debug

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({Key? key}) : super(key: key);

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final LocationService _locationService = LocationService();
  bool _isOnline = false;
  bool _hasActiveRide = false;
  
  // Données de course active (simulation)
  String _activeRideId = '';
  String _patientName = '';
  String _destination = '';
  double _destinationLat = 0.0;
  double _destinationLng = 0.0;

  // Statistiques journalières
  int _ridesCompleted = 0;
  double _todayEarnings = 0.0;
  double _distanceTraveled = 0.0;
  
  // Abonnement Supabase
  StreamSubscription<List<Map<String, dynamic>>>? _ridesSubscription;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  Future<void> _initializeDriver() async {
    // Charger les données sauvegardées
    _loadDriverData();
    // Écouter les demandes réelles
    _listenToRideRequests();
  }

  @override
  void dispose() {
    _ridesSubscription?.cancel();
    super.dispose();
  }

  void _listenToRideRequests() {
    Logger.info('🎧 Écoute des nouvelles courses (pending)...', 'DRIVER');
    _ridesSubscription = _supabase
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(1)
        .listen((List<Map<String, dynamic>> rides) {
          if (rides.isNotEmpty) {
            final ride = rides.first;
            // Vérifier si c'est une nouvelle demande (éviter de spammer si déjà affichée)
            if (ride['id'] != _activeRideId && !_hasActiveRide) {
              Logger.info('🔔 Nouvelle course reçue: ${ride['id']}', 'DRIVER');
              _showRideRequest(rideData: ride);
            }
          }
        }, onError: (error) {
          Logger.error('Erreur écoute courses', error, null, 'DRIVER');
        });
  }

  void _loadDriverData() {
    // Simulation de données - en production, ces données viendraient d'une API
    setState(() {
      _ridesCompleted = 3;
      _todayEarnings = 245.50;
      _distanceTraveled = 87.3;
    });
  }

  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });

    if (_isOnline) {
      _locationService.startLocationTracking();
      _showSnackBar('Vous êtes maintenant en ligne et visible aux patients');
    } else {
      _locationService.stopLocationTracking();
      _showSnackBar('Vous êtes maintenant hors ligne');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openMapView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapScreen(),
      ),
    );
  }

  void _simulateNewRide() {
    // Simulation d'une nouvelle demande de course
    final fakeRide = {
      'id': 'RX${DateTime.now().millisecondsSinceEpoch}',
      'pickup_address': 'Position actuelle (Simulée)',
      'destination_address': 'Hôpital Mohammed V, Rabat',
      'destination_latitude': 34.0209,
      'destination_longitude': -6.8416,
      'estimated_price': 75.0,
      'est_distance': 8.5, // Fake field
      'est_duration': 15, // Fake field
    };

    _showRideRequest(rideData: fakeRide, isSimulation: true);
  }

  void _showRideRequest({required Map<String, dynamic> rideData, bool isSimulation = false}) {
    // Mettre à jour les variables d'état pour affichage
    setState(() {
      _activeRideId = rideData['id'];
      _patientName = isSimulation ? 'Patient Test' : 'Patient (ID: ...${rideData['patient_id'].toString().substring(0,4)})';
      _destination = rideData['destination_address'] ?? 'Destination inconnue';
      // Ajuster selon format (double ou string)
      _destinationLat = (rideData['destination_latitude'] is String) 
          ? double.parse(rideData['destination_latitude']) 
          : (rideData['destination_latitude'] ?? 0.0);
      _destinationLng = (rideData['destination_longitude'] is String)
          ? double.parse(rideData['destination_longitude'])
          : (rideData['destination_longitude'] ?? 0.0);
    });

    final price = rideData['estimated_price']?.toString() ?? '?';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle Demande de Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trajet vers: $_destination', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Revenus estimés: $price MAD'),
            if (isSimulation) const Text('(Simulation)', style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectRide();
            },
            child: const Text('Refuser'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _acceptRide(rideData, isSimulation);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Accepter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRide(Map<String, dynamic> rideData, bool isSimulation) async {
    try {
      if (!isSimulation) {
        // Mettre à jour Supabase pour dire "J'accepte !"
        final currentUser = _supabase.auth.currentUser;
        if (currentUser == null) {
          _showSnackBar('Erreur: Non connecté');
          return;
        }

        Logger.info('Activation course ${rideData['id']} pour chauffeur ${currentUser.id}', 'DRIVER');
        
        await _supabase.from('rides').update({
          'driver_id': currentUser.id,
          'status': 'accepted',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', rideData['id']);
        
        Logger.success('Course acceptée !', 'DRIVER');
      }

      // Naviguer vers le tracking
      if (!mounted) return;
      
      setState(() {
        _hasActiveRide = true;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideTrackingScreen(
            rideId: _activeRideId,
            patientName: _patientName,
            destination: _destination,
            destinationLat: _destinationLat,
            destinationLng: _destinationLng,
            isDriver: true,
          ),
        ),
      ).then((value) {
        // Retour du suivi de course
        setState(() {
          _hasActiveRide = false;
          _ridesCompleted++;
          _todayEarnings += (rideData['estimated_price'] is num ? rideData['estimated_price'] : 0.0);
        });
      });
      
    } catch (e) {
      Logger.error('Erreur acceptation course', e, null, 'DRIVER');
      _showSnackBar('Erreur lors de l\'acceptation');
      setState(() => _hasActiveRide = false);
    }
  }

  void _rejectRide() {
    setState(() {
      _hasActiveRide = false;
    });
    _showSnackBar('Course refusée');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord - Chauffeur'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (value) => _toggleOnlineStatus(),
            activeColor: Colors.white,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut en ligne
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0xFF4CAF50) : Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOnline ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isOnline ? 'En ligne - Disponible' : 'Hors ligne',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Statistiques du jour
            const Text(
              'Statistiques Aujourd\'hui',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Courses',
                    _ridesCompleted.toString(),
                    Icons.local_taxi,
                    const Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Revenus',
                    '${_todayEarnings.toStringAsFixed(0)} DH',
                    Icons.monetization_on,
                    const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Distance',
                    '${_distanceTraveled.toStringAsFixed(1)} km',
                    Icons.route,
                    const Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Temps Actif',
                    '6h 24m',
                    Icons.access_time,
                    const Color(0xFF9C27B0),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Actions rapides
            const Text(
              'Actions Rapides',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildActionCard(
                  'Voir la Carte',
                  Icons.map,
                  const Color(0xFF2196F3),
                  _openMapView,
                ),
                _buildActionCard(
                  'Historique',
                  Icons.history,
                  const Color(0xFF607D8B),
                  () => _showSnackBar('Historique en développement'),
                ),
                _buildActionCard(
                  'Paramètres',
                  Icons.settings,
                  const Color(0xFF795548),
                  () => _showSnackBar('Paramètres en développement'),
                ),
                _buildActionCard(
                  'Support',
                  Icons.support_agent,
                  const Color(0xFFE91E63),
                  () => _showSnackBar('Support en développement'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Zone de test
            if (_isOnline && !_hasActiveRide)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Zone de Test',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _simulateNewRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        'Simuler une Nouvelle Course',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}