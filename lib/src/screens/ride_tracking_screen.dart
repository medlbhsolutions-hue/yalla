import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import '../services/database_service.dart';
import '../services/ride_status_service.dart';
import '../services/osm_service.dart';
import '../widgets/osm_map_widget.dart';
import '../utils/logger.dart';

/// Écran de tracking en temps réel d'une course
class RideTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final Map<String, dynamic> driver;

  const RideTrackingScreen({
    Key? key,
    required this.rideData,
    required this.driver,
  }) : super(key: key);

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final MapController _mapController = MapController();
  bool _canShowMap = false; 
  bool _isDisposed = false; 
  LatLng? _patientPosition;
  LatLng _driverPosition = const LatLng(33.9716, -6.8498); 
  Timer? _locationUpdateTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _locationSubscription;
  String _rideStatus = 'pending';
  int _eta = 15; 

  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  
  // Style JSON pour masquer les POIs (Points of Interest)
  final String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "transit",
      "stylers": [{ "visibility": "off" }]
    }
  ]
  ''';

  /// Mettre à jour les marqueurs sur la carte (Version OSM)
  void _updateMarkers() {
    setState(() {
      _markers.clear();
      _polylines.clear();

      // Marqueur patient (Départ)
      if (_patientPosition != null) {
        _markers.add(
          Marker(
            point: _patientPosition!,
            width: 50,
            height: 50,
            child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
          ),
        );
      }
      
      // Marqueur Destination
      final destLat = widget.rideData['destination_latitude'];
      final destLng = widget.rideData['destination_longitude'];
      if (destLat != null && destLng != null) {
        _markers.add(
          Marker(
            point: LatLng(destLat.toDouble(), destLng.toDouble()),
            width: 50,
            height: 50,
            child: const Icon(Icons.flag, color: Colors.red, size: 40),
          ),
        );
      }

      // Marqueur chauffeur
      _markers.add(
        Marker(
          point: _driverPosition,
          width: 60,
          height: 60,
          child: const Icon(Icons.directions_car, color: Colors.purple, size: 45),
        ),
      );

      // Ligne entre patient et chauffeur (Ligne directe pour l'instant)
      if (_patientPosition != null) {
        _polylines.add(
          Polyline(
            points: [_patientPosition!, _driverPosition],
            color: Colors.blue,
            strokeWidth: 4,
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeTracking();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isDisposed) {
        setState(() => _canShowMap = true);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _canShowMap = false;
    _locationUpdateTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Initialiser le tracking
  Future<void> _initializeTracking() async {
    // Récupérer position patient
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _patientPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // Position par défaut (Casablanca)
      setState(() {
        _patientPosition = const LatLng(33.5731, -7.5898);
      });
    }

    // Récupérer position chauffeur depuis les données
    try {
      final driverLocation = widget.driver['current_location'];
      if (driverLocation != null && driverLocation is Map) {
        setState(() {
          _driverPosition = LatLng(
            (driverLocation['latitude'] as num).toDouble(),
            (driverLocation['longitude'] as num).toDouble(),
          );
        });
      } else {
        // Position par défaut si pas de current_location
        Logger.debug('Pas de current_location pour le chauffeur, utilisation position par défaut', 'MAP');
      }
    } catch (e) {
      Logger.error('Erreur récupération position chauffeur', e, null, 'MAP');
      // Garder la position par défaut (_driverPosition déjà initialisée)
    }

    _updateMarkers();
    _startLocationUpdates();
  }



  /// Démarrer les mises à jour de position (🎯 NOUVEAU : REALTIME depuis Supabase)
  void _startLocationUpdates() {
    final driverId = widget.driver['id'];
    
    print('🔥 Démarrage écoute Realtime pour driver: $driverId');
    
    // ✅ SUPABASE REALTIME : Écouter les changements GPS du chauffeur
    _locationSubscription = DatabaseService.client
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .listen((List<Map<String, dynamic>> data) {
          if (!mounted) return;
          
          if (data.isNotEmpty) {
            final location = data.first;
            // CORRECTION: Utiliser lat/lng comme défini dans location_tracking_service.dart
            final lat = location['lat'] ?? location['latitude'] ?? 0.0;
            final lng = location['lng'] ?? location['longitude'] ?? 0.0;
            final timestamp = location['updated_at'] ?? location['timestamp'];
            
            Logger.debug('Position reçue: ($lat, $lng) à $timestamp', 'GPS');
            
            setState(() {
              _driverPosition = LatLng(lat.toDouble(), lng.toDouble());
              _updateMarkers();
              _updateETA();
            });
            
            // Vérifier si chauffeur est arrivé (< 100m)
            if (_patientPosition != null) {
              final distance = _calculateDistance(
                _driverPosition.latitude,
                _driverPosition.longitude,
                _patientPosition!.latitude,
                _patientPosition!.longitude,
              );
              
              if (distance < 0.1 && _rideStatus != 'arrived') {
                Logger.success('Chauffeur arrivé (distance: ${distance.toStringAsFixed(2)} km)', 'RIDE');
                setState(() => _rideStatus = 'arrived');
              }
            }
          } else {
            Logger.debug('Aucune position disponible pour driver $driverId', 'GPS');
          }
        }, onError: (error) {
          Logger.error('Erreur Realtime', error, null, 'GPS');
        });
    
    // Charger le statut actuel de la course
    _loadCurrentRideStatus();
  }
  
  /// Charger le statut actuel de la course depuis Supabase
  Future<void> _loadCurrentRideStatus() async {
    try {
      final rideId = widget.rideData['id'];
      final response = await DatabaseService.client
          .from('rides')
          .select('status')
          .eq('id', rideId)
          .single();
      
      if (mounted) {
        setState(() {
          _rideStatus = response['status'] ?? 'pending';
          Logger.info('Statut course chargé: $_rideStatus', 'RIDE');
        });
      }
    } catch (e) {
      Logger.error('Erreur chargement statut', e, null, 'RIDE');
    }
  }

  /// Calculer la distance (formule Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// Mettre à jour l'ETA
  void _updateETA() {
    if (_patientPosition == null) return;

    final distance = _calculateDistance(
      _driverPosition.latitude,
      _driverPosition.longitude,
      _patientPosition!.latitude,
      _patientPosition!.longitude,
    );

    // Vitesse moyenne en ville : 30 km/h
    final timeHours = distance / 30;
    final timeMinutes = (timeHours * 60).ceil();

    setState(() {
      _eta = timeMinutes > 0 ? timeMinutes : 0;
    });
  }

  /// Obtenir la couleur du statut
  Color _getStatusColor() {
    switch (_rideStatus) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      case 'arrived':
        return Colors.purple;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// Obtenir le libellé du statut
  String _getStatusLabel() {
    switch (_rideStatus) {
      case 'pending':
        return 'En attente de confirmation...';
      case 'accepted':
        return 'Chauffeur en route';
      case 'in_progress':
        return 'Course en cours';
      case 'arrived':
        return 'Chauffeur arrivé';
      case 'completed':
        return 'Course terminée';
      default:
        return 'Statut inconnu';
    }
  }

  /// Obtenir l'icône du statut
  IconData _getStatusIcon() {
    switch (_rideStatus) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.directions_car;
      case 'in_progress':
        return Icons.local_shipping;
      case 'arrived':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = '${widget.driver['first_name']} ${widget.driver['last_name']}';
    
    // Gérer vehicles qui peut être un List ou null
    final vehicles = widget.driver['vehicles'];
    final vehicleInfo = (vehicles is List && vehicles.isNotEmpty) ? vehicles[0] : null;
    final vehicleDisplay = vehicleInfo != null
        ? '${vehicleInfo['make']} ${vehicleInfo['model']}'
        : 'Véhicule';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de la course'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _simulateDriverMovement,
        backgroundColor: Colors.purple,
        mini: true,
        tooltip: 'Simuler déplacement (Debug)',
        child: const Icon(Icons.videogame_asset),
      ),
      body: Stack(
        children: [
          // Carte Google Maps
          _patientPosition == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : OSMMapWidget(
                  initialCenter: _patientPosition!,
                  initialZoom: 14,
                  mapController: _mapController,
                  markers: _markers,
                  polylines: _polylines,
                ),

          // Informations en overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Statut
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getStatusLabel(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Info chauffeur
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green,
                          radius: 20,
                          child: Text(
                            widget.driver['first_name'][0] +
                                widget.driver['last_name'][0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                vehicleDisplay,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ETA
                        if (_rideStatus == 'in_progress' || _rideStatus == 'accepted')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_eta min',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🎯 BOUTONS WORKFLOW (Arrivé / Démarrer / Terminer)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildWorkflowButtons(),
          ),
        ],
      ),
    );
  }
  
  /// 🎯 NOUVEAU : Boutons workflow selon statut
  Widget _buildWorkflowButtons() {
    switch (_rideStatus) {
      case 'accepted':
        // Chauffeur en route vers patient
        return ElevatedButton.icon(
          onPressed: _markAsArrived,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.location_on),
          label: const Text(
            '📍 Je suis arrivé',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );
      
      case 'arrived':
        // Chauffeur arrivé, attends patient
        return ElevatedButton.icon(
          onPressed: _startRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text(
            '🚀 Démarrer la course',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );
      
      case 'in_progress':
        // Course en cours
        return ElevatedButton.icon(
          onPressed: _completeRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.check_circle),
          label: const Text(
            '✅ Terminer la course',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );
      
      case 'completed':
        // Course terminée
        return ElevatedButton.icon(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.home),
          label: const Text(
            'Retour au tableau de bord',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );
      
      default:
        return const SizedBox.shrink();
    }
  }
  
  /// 🎯 Action 1: Marquer comme arrivé
  Future<void> _markAsArrived() async {
    try {
      final rideId = widget.rideData['id'];
      final success = await RideStatusService.updateRideStatus(
        rideId: rideId,
        newStatus: RideStatusService.statusArrived,
      );
      
      if (!success) {
        throw Exception('Transition de statut non autorisée');
      }
      
      setState(() => _rideStatus = 'arrived');
      print('✅ Statut mis à jour: arrivé');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Vous êtes arrivé !'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Erreur marquer arrivé: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  /// 🎯 Action 2: Démarrer course
  Future<void> _startRide() async {
    try {
      final rideId = widget.rideData['id'];
      final success = await RideStatusService.updateRideStatus(
        rideId: rideId,
        newStatus: RideStatusService.statusInProgress,
      );
      
      if (!success) {
        throw Exception('Transition de statut non autorisée');
      }
      
      setState(() => _rideStatus = 'in_progress');
      print('✅ Course démarrée');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 Course démarrée !'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Erreur démarrer course: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  /// 🎯 Action 3: Terminer course
  Future<void> _completeRide() async {
    try {
      final rideId = widget.rideData['id'];
      final success = await RideStatusService.updateRideStatus(
        rideId: rideId,
        newStatus: RideStatusService.statusCompleted,
      );
      
      if (!success) {
        throw Exception('Transition de statut non autorisée');
      }
      
      setState(() => _rideStatus = 'completed');
      print('✅ Course terminée');
      
      // Arrêter tracking GPS - remettre le chauffeur disponible
      await DatabaseService.client
          .from('drivers')
          .update({'is_available': true})
          .eq('id', widget.driver['id']);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Course terminée avec succès !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Erreur terminer course: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 🧪 SIMULATION: Faire bouger le chauffeur
  Future<void> _simulateDriverMovement() async {
    final driverId = widget.driver['id'];
    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Pas d\'ID chauffeur pour la simulation')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎮 Simulation démarrée...'),
        backgroundColor: Colors.purple,
        duration: Duration(seconds: 2),
      ),
    );

    // Point de départ (celui actuel ou Rabat)
    double lat = _driverPosition.latitude;
    double lng = _driverPosition.longitude;

    // Simuler 20 déplacements
    for (int i = 0; i < 20; i++) {
        if (!mounted) break;
        
        // Déplacement aléatoire vers le sud-est
        lat += 0.0002;
        lng += 0.0002;
        
        try {
            await DatabaseService.client.from('driver_locations').upsert({
                'driver_id': driverId,
                'lat': lat,  // Vérifié: colonnes lat/lng
                'lng': lng,
                'heading': 135.0,
                'speed': 45.0,
                'accuracy': 5.0,
                'updated_at': DateTime.now().toIso8601String(),
            });
            print('🎮 Simu update: $lat, $lng');
        } catch (e) {
            print('❌ Erreur simu: $e');
        }
        
        // Attendre 1 seconde entre chaque mouvement
        await Future.delayed(const Duration(seconds: 1));
    }
    
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🏁 Simulation terminée')),
        );
    }
  }
}
