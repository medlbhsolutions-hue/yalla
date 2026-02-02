import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../src/widgets/osm_map_widget.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../src/utils/format_utils.dart';
// import 'package:maps_launcher/maps_launcher.dart'; // Supprimé - utilise Google Maps
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../src/utils/logger.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  final String patientName;
  final String destination;
  final double destinationLat;
  final double destinationLng;
  final bool isDriver;

  const RideTrackingScreen({
    Key? key,
    required this.rideId,
    required this.patientName,
    required this.destination,
    required this.destinationLat,
    required this.destinationLng,
    this.isDriver = false,
  }) : super(key: key);

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final MapController _mapController = MapController();
  bool _canShowMap = false; 
  bool _isDisposed = false; 
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  StreamSubscription<Position>? _positionSubscription;
  
  bool _isLoading = true;
  bool _rideStarted = false;
  bool _rideCompleted = false;
  List<LatLng> _routePoints = [];
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  
  String _currentStatus = 'En attente...';
  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
    // Retarder l'affichage de la carte pour éviter l'erreur dispose sur Web
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
    _positionSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      setState(() {
        _currentStatus = 'Initialisation du suivi...';
      });

      // Obtenir la position actuelle
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          _currentStatus = widget.isDriver ? 'Prêt à démarrer' : 'En attente du chauffeur';
        });

        _updateMarkers();
        _startLocationTracking();
      } else {
        setState(() {
          _currentStatus = 'Erreur de géolocalisation';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentStatus = 'Erreur: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _startLocationTracking() {
    _positionSubscription = _locationService.positionStream.listen(
      (Position position) {
        setState(() {
          _currentPosition = position;
          _currentSpeed = position.speed * 3.6; // Convertir m/s en km/h
        });

        if (_rideStarted && !_rideCompleted) {
          _updateRoute(position);
          _checkIfNearDestination(position);
        }

        _updateMarkers();
        _updateCameraPosition(position);
      },
    );

    _locationService.startLocationTracking();
  }

  void _updateRoute(Position position) {
    LatLng newPoint = LatLng(position.latitude, position.longitude);
    
    if (_routePoints.isNotEmpty) {
      LatLng lastPoint = _routePoints.last;
      double distance = _locationService.calculateDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        position.latitude,
        position.longitude,
      );
      _totalDistance += distance;
    }

    _routePoints.add(newPoint);
    _drawRoute();
  }

  void _drawRoute() {
    if (_routePoints.length > 1) {
      _polylines.clear();
      _polylines.add(
        Polyline(
          points: _routePoints,
          color: const Color(0xFF2E7D32),
          strokeWidth: 4,
        ),
      );

      // Route vers la destination
      if (_currentPosition != null) {
        _polylines.add(
          Polyline(
            points: [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              LatLng(widget.destinationLat, widget.destinationLng),
            ],
            color: Colors.blue,
            strokeWidth: 3,
          ),
        );
      }
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Marqueur position actuelle
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 50,
          height: 50,
          child: Icon(
            Icons.location_on,
            color: widget.isDriver ? Colors.green : Colors.blue,
            size: 40
          ),
        ),
      );
    }

    // Marqueur destination
    _markers.add(
      Marker(
        point: LatLng(widget.destinationLat, widget.destinationLng),
        width: 50,
        height: 50,
        child: const Icon(Icons.flag, color: Colors.red, size: 40),
      ),
    );
  }

  void _updateCameraPosition(Position position) {
    if (_mapController != null) {
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      15,
    );
    }
  }

  void _checkIfNearDestination(Position position) {
    bool isNear = _locationService.isNearDestination(
      position,
      widget.destinationLat,
      widget.destinationLng,
      radiusInMeters: 50, // 50 mètres de rayon
    );

    if (isNear && !_rideCompleted) {
      _completeRide();
    }
  }

  Future<void> _startRide() async {
    if (!_rideStarted) {
      setState(() {
        _rideStarted = true;
        _startTime = DateTime.now();
        _currentStatus = 'Course en cours';
      });

      _startTimer();
      _saveRideData();

      if (_currentPosition != null) {
        _routePoints.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      }
      
      // ✅ UPDATE SUPABASE
      try {
        await Supabase.instance.client.from('rides').update({
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.rideId);
        Logger.info('Course démarrée (in_progress)', 'DRIVER_TRACKING');
      } catch (e) {
        Logger.error('Erreur start ride', e, null, 'DRIVER_TRACKING');
      }
    }
  }

  Future<void> _completeRide() async {
    setState(() {
      _rideCompleted = true;
      _currentStatus = 'Course terminée';
    });

    _timer?.cancel();
    _positionSubscription?.cancel();
    _saveRideCompletion();
    
    // ✅ UPDATE SUPABASE
    try {
      await Supabase.instance.client.from('rides').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'actual_distance': _totalDistance / 1000,
        'actual_duration': _elapsedTime.inMinutes,
        'price': _calculateEarnings(), // Prix final
      }).eq('id', widget.rideId);
      Logger.success('Course terminée (completed)', 'DRIVER_TRACKING');
    } catch (e) {
      Logger.error('Erreur complete ride', e, null, 'DRIVER_TRACKING');
    }

    _showCompletionDialog();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  Future<void> _saveRideData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_ride_id', widget.rideId);
      await prefs.setBool('ride_in_progress', true);
      await prefs.setString('ride_start_time', _startTime!.toIso8601String());
    } catch (e) {
      print('Erreur lors de la sauvegarde: $e');
    }
  }

  Future<void> _saveRideCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_ride_id');
      await prefs.setBool('ride_in_progress', false);
      await prefs.setString('last_ride_completion', DateTime.now().toIso8601String());
      await prefs.setDouble('last_ride_distance', _totalDistance);
      await prefs.setString('last_ride_duration', _elapsedTime.toString());
    } catch (e) {
      print('Erreur lors de la sauvegarde de fin: $e');
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Course Terminée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${widget.patientName}'),
            Text('Destination: ${widget.destination}'),
            const SizedBox(height: 8),
            Text('Durée: ${_formatDuration(_elapsedTime)}'),
            Text('Distance: ${(_totalDistance / 1000).toStringAsFixed(1)} km'),
            if (widget.isDriver)
              Text('Revenus estimés: ${_calculateEarnings().toStringAsFixed(0)} DH'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Retour au dashboard
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  double _calculateEarnings() {
    // Calcul simple: 3 DH/km + 50 DH de base
    double basePrice = 50.0;
    double distancePrice = (_totalDistance / 1000) * 3.0;
    return basePrice + distancePrice;
  }

  String _formatDuration(Duration duration) {
    return formatDurationTimer(duration);
  }

  String _getRemainingDistance() {
    if (_currentPosition != null) {
      double distance = _locationService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        widget.destinationLat,
        widget.destinationLng,
      );
      
      if (distance < 1000) {
        return '${distance.toStringAsFixed(0)} m';
      } else {
        return '${(distance / 1000).toStringAsFixed(1)} km';
      }
    }
    return '---';
  }

  void _openNavigation() {
    // Navigation GPS intégrée
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigation vers ${widget.destination}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Course ${widget.rideId}'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: _openNavigation,
            tooltip: 'Navigation',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (_canShowMap)
                  OSMMapWidget(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : LatLng(widget.destinationLat, widget.destinationLng),
                    initialZoom: 15,
                    mapController: _mapController,
                    markers: _markers,
                    polylines: _polylines,
                  ),

                // Panneau d'informations
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                            Icon(
                              _rideCompleted ? Icons.check_circle :
                              _rideStarted ? Icons.directions_car :
                              Icons.hourglass_empty,
                              color: _rideCompleted ? Colors.green :
                                     _rideStarted ? const Color(0xFF2E7D32) :
                                     Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentStatus,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Patient: ${widget.patientName}'),
                        Text('Destination: ${widget.destination}'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Durée: ${_formatDuration(_elapsedTime)}'),
                                Text('Distance: ${(_totalDistance / 1000).toStringAsFixed(1)} km'),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Restant: ${_getRemainingDistance()}'),
                                Text('Vitesse: ${_currentSpeed.toStringAsFixed(0)} km/h'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Boutons d'action
                if (!_rideCompleted)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        if (widget.isDriver && !_rideStarted)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _startRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Démarrer la course',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        if (_rideStarted) ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _openNavigation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Navigation GPS',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (widget.isDriver)
                            ElevatedButton(
                              onPressed: _completeRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              ),
                              child: const Text(
                                'Terminer',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}