import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../src/widgets/osm_map_widget.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
// import 'package:maps_launcher/maps_launcher.dart'; // Supprimé - utilise Google Maps

class MapScreen extends StatefulWidget {
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationName;
  final bool showNavigation;

  const MapScreen({
    Key? key,
    this.destinationLat,
    this.destinationLng,
    this.destinationName,
    this.showNavigation = false,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _canShowMap = false; 
  bool _isDisposed = false; 
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  StreamSubscription<Position>? _positionSubscription;
  bool _isLoading = true;
  String _statusMessage = 'Chargement de la carte...';

  @override
  void initState() {
    super.initState();
    _initializeMap();
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
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _statusMessage = 'Obtention de la position...';
      });

      // Obtenir la position actuelle
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });

        _updateMarkers();
        _startLocationTracking();
      } else {
        setState(() {
          _statusMessage = 'Impossible d\'obtenir la position. Vérifiez les permissions.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _startLocationTracking() {
    _positionSubscription = _locationService.positionStream.listen(
      (Position position) {
        setState(() {
          _currentPosition = position;
        });
        _updateCurrentLocationMarker();
        _updateCameraPosition(position);
      },
    );

    _locationService.startLocationTracking();
  }

  void _updateMarkers() {
    _markers.clear();

    // Marqueur position actuelle
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Ma position',
            snippet: 'Position actuelle',
          ),
        ),
      );
    }

    // Marqueur destination
    if (widget.destinationLat != null && widget.destinationLng != null) {
      _markers.add(
        Marker(
          point: LatLng(widget.destinationLat!, widget.destinationLng!),
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );

      // Tracer la route si on a les deux points
      if (_currentPosition != null) {
        _drawRoute();
      }
    }
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition != null) {
      _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Ma position',
            snippet: 'Position actuelle',
          ),
        ),
      );
    }
  }

  void _updateCameraPosition(Position position) {
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      _mapController.camera.zoom,
    );
  }

  void _drawRoute() {
    if (_currentPosition != null && widget.destinationLat != null && widget.destinationLng != null) {
      // Route simple (ligne droite) - dans un vrai projet, utilisez l'API Directions
      List<LatLng> routePoints = [
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(widget.destinationLat!, widget.destinationLng!),
      ];

      _polylines.add(
        Polyline(
          points: routePoints,
          color: const Color(0xFF2E7D32),
          strokeWidth: 4,
        ),
      );
    }
  }

  void _centerOnCurrentLocation() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16,
      );
    }
  }

  void _showBothLocations() {
    if (_currentPosition != null && widget.destinationLat != null) {
      _mapController.move(
        LatLng(
          (_currentPosition!.latitude + widget.destinationLat!) / 2,
          (_currentPosition!.longitude + widget.destinationLng!) / 2,
        ),
        14,
      );
    }
  }

  void _openInMapsApp() {
    if (widget.destinationLat != null && widget.destinationLng != null) {
      // Utilisation Google Maps intégrée
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigation vers ${widget.destinationName ?? "Destination"}')),
      );
    }
  }

  String _getDistanceString() {
    if (_currentPosition != null && widget.destinationLat != null && widget.destinationLng != null) {
      double distance = _locationService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        widget.destinationLat!,
        widget.destinationLng!,
      );
      
      if (distance < 1000) {
        return '${distance.toStringAsFixed(0)} m';
      } else {
        return '${(distance / 1000).toStringAsFixed(1)} km';
      }
    }
    return '';
  }

  String _getEstimatedTimeString() {
    if (_currentPosition != null && widget.destinationLat != null && widget.destinationLng != null) {
      double distance = _locationService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        widget.destinationLat!,
        widget.destinationLng!,
      );
      
      double timeInMinutes = _locationService.calculateEstimatedTime(distance);
      
      if (timeInMinutes < 60) {
        return '${timeInMinutes.toStringAsFixed(0)} min';
      } else {
        int hours = timeInMinutes ~/ 60;
        int minutes = (timeInMinutes % 60).round();
        return '${hours}h ${minutes}min';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.destinationName ?? 'Carte'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (widget.showNavigation)
            IconButton(
              icon: const Icon(Icons.navigation),
              onPressed: _openInMapsApp,
              tooltip: 'Ouvrir dans Google Maps',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                if (_canShowMap)
                  OSMMapWidget(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : const LatLng(33.9716, -6.8498), // Rabat par défaut
                    initialZoom: 14,
                    mapController: _mapController,
                    markers: _markers,
                    polylines: _polylines,
                  ),

                // Informations de trajet
                if (widget.destinationLat != null && _currentPosition != null)
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
                      child: Row(
                        children: [
                          const Icon(
                            Icons.medical_services,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.destinationName ?? 'Destination',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.straighten,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getDistanceString(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getEstimatedTimeString(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Boutons d'action
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        onPressed: _centerOnCurrentLocation,
                        backgroundColor: const Color(0xFF2E7D32),
                        child: const Icon(Icons.my_location, color: Colors.white),
                        heroTag: "location_btn",
                      ),
                      if (widget.destinationLat != null) ...[
                        const SizedBox(height: 12),
                        FloatingActionButton(
                          onPressed: _showBothLocations,
                          backgroundColor: const Color(0xFF2E7D32),
                          child: const Icon(Icons.zoom_out_map, color: Colors.white),
                          heroTag: "zoom_btn",
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