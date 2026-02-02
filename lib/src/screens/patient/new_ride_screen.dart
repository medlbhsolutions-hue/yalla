import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/database_service.dart';
import '../../services/pricing_service.dart';
import '../../services/osm_service.dart';
import '../../widgets/osm_map_widget.dart';
import '../../widgets/address_autocomplete_field.dart';
import 'patient_live_tracking_screen.dart';
import 'package:uuid/uuid.dart';

/// 🎨 NOUVELLE VERSION - Design moderne type Uber/Bolt
class NewRideScreen extends StatefulWidget {
  final Map<String, dynamic>? patientProfile;
  
  const NewRideScreen({Key? key, this.patientProfile}) : super(key: key);

  @override
  State<NewRideScreen> createState() => _NewRideScreenState();
}

class _NewRideScreenState extends State<NewRideScreen> {
  final MapController _mapController = MapController();
  bool _isDisposed = false;
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  
  bool _isLoadingLocation = true;
  bool _isCalculatingPrice = false;
  bool _isCreatingRide = false;
  
  Map<String, dynamic>? _priceEstimate;
  
  String _rideType = 'standard';
  String _vehicleType = 'ambulance';
  String _pickupAddress = '';
  String _destinationAddress = '';
  final TextEditingController _destinationController = TextEditingController();
  
  String? _sessionToken;

  LatLng _mapCenter = const LatLng(33.5731, -7.5898);
  bool _isMoving = false;
  String _centerAddress = 'Recherche de l\'adresse...';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _sessionToken = const Uuid().v4();
    _getCurrentLocation();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _destinationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() { _isLoadingLocation = true; });
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        _showError('Permission de localisation refusée');
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final latLng = LatLng(position.latitude, position.longitude);
      final address = await OSMService.reverseGeocode(latLng);
      
      setState(() {
        _currentPosition = latLng;
        _mapCenter = latLng;
        _pickupAddress = address ?? 'Ma position';
        _centerAddress = _pickupAddress;
        _isLoadingLocation = false;
        
        _markers.add(Marker(
          point: _currentPosition!,
          width: 50,
          height: 50,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
        ));
      });
      
      _mapController.move(_currentPosition!, 16);
    } catch (e) {
      print('❌ Erreur GPS: $e');
      setState(() {
        _currentPosition = const LatLng(33.5731, -7.5898);
        _mapCenter = _currentPosition!;
        _pickupAddress = 'Casablanca';
        _centerAddress = _pickupAddress;
        _isLoadingLocation = false;
      });
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    
    setState(() {
      _mapCenter = camera.center;
      _isMoving = true;
    });

    // Debounce reverse geocoding
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final address = await OSMService.reverseGeocode(_mapCenter);
      if (!_isDisposed) {
        setState(() {
          _centerAddress = address ?? 'Adresse inconnue';
          _isMoving = false;
        });
      }
    });
  }

  void _confirmPosition() {
    if (_destinationPosition == null) {
      // Si on choisit la destination
      _onDestinationSelected({
        'lat': _mapCenter.latitude,
        'lng': _mapCenter.longitude,
        'description': _centerAddress,
        'name': _centerAddress.split(',').first,
      });
    } else {
      // Si on change le départ
      setState(() {
        _currentPosition = _mapCenter;
        _pickupAddress = _centerAddress;
      });
      _calculatePrice();
    }
  }

  Future<void> _onDestinationSelected(Map<String, dynamic> place) async {
    double? lat;
    double? lng;
    String address = '';
    
    if (place['geometry'] != null && place['geometry']['location'] != null) {
      lat = place['geometry']['location']['lat']?.toDouble();
      lng = place['geometry']['location']['lng']?.toDouble();
      address = place['formatted_address'] ?? place['description'] ?? '';
    } 
    else if (place['lat'] != null && place['lng'] != null) {
      lat = place['lat']?.toDouble();
      lng = place['lng']?.toDouble();
      address = place['description'] ?? place['name'] ?? '';
    }
    else if (place['latitude'] != null && place['longitude'] != null) {
      lat = place['latitude']?.toDouble();
      lng = place['longitude']?.toDouble();
      address = place['description'] ?? place['address'] ?? '';
    }
    
    if (lat == null || lng == null) {
      _showError('Impossible de localiser cette adresse');
      return;
    }
    
    setState(() {
      _destinationPosition = LatLng(lat!, lng!);
      _destinationAddress = address;
      _destinationController.text = address;
      
      _markers.removeWhere((m) => m.child is Icon && (m.child as Icon).icon == Icons.flag);
      _markers.add(Marker(
        point: _destinationPosition!,
        width: 50,
        height: 50,
        child: const Icon(Icons.flag, color: Colors.red, size: 40),
      ));
    });
    
    _mapController.move(_destinationPosition!, 15);
    await _calculatePrice();
  }

  Future<void> _calculatePrice() async {
    if (_currentPosition == null || _destinationPosition == null) return;
    
    setState(() { _isCalculatingPrice = true; });
    
    try {
      final estimate = await PricingService.calculatePriceEstimateWithDirections(
        pickup: _currentPosition!,
        destination: _destinationPosition!,
      );
      
      setState(() {
        _priceEstimate = estimate;
        _isCalculatingPrice = false;
        
        if (estimate['polyline'] != null) {
          _polylines.clear();
          _polylines.add(Polyline(
            points: _decodePolyline(estimate['polyline']),
            color: const Color(0xFF467DB0),
            strokeWidth: 5,
          ));
        }
      });
      
      // Ajuster la vue pour voir tout le trajet
      final bounds = LatLngBounds.fromPoints([_currentPosition!, _destinationPosition!]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
      
    } catch (e) {
      print('❌ Erreur calcul prix: $e');
      setState(() { _isCalculatingPrice = false; });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _createRide() async {
    if (_currentPosition == null || _destinationPosition == null) {
      _showError('Veuillez sélectionner une destination');
      return;
    }
    
    if (widget.patientProfile == null) {
      _showError('Profil patient introuvable');
      return;
    }
    
    setState(() { _isCreatingRide = true; });
    
    try {
      final response = await DatabaseService.createRide(
        patientId: widget.patientProfile!['id'],
        pickupAddress: _pickupAddress,
        destinationAddress: _destinationAddress,
        pickupLatitude: _currentPosition!.latitude,
        pickupLongitude: _currentPosition!.longitude,
        destinationLatitude: _destinationPosition!.latitude,
        destinationLongitude: _destinationPosition!.longitude,
        estimatedPrice: _priceEstimate?['price_mad'] ?? 0.0,
        distanceKm: _priceEstimate?['distance_km'] ?? 0.0,
        durationMinutes: (_priceEstimate?['duration_minutes'] ?? 0).toInt(),
        priority: _rideType == 'urgent' ? 'urgent' : 'medium',
        medicalNotes: '',
        specialRequirements: {'vehicle_type': _vehicleType},
      );
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PatientLiveTrackingScreen(rideId: response['id']),
          ),
        );
      }
    } catch (e) {
      setState(() { _isCreatingRide = false; });
      _showError('Erreur lors de la création de la course');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF467DB0)))
          : Stack(
              children: [
                // 🗺️ CARTE MODERNE
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: 16,
                    onPositionChanged: _onMapPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                
                // 🎯 PIN CENTRAL (Comme dans Uber/Bolt)
                if (_destinationPosition == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 35),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // La bulle "Utilisez Ce Point"
                          if (!_isMoving)
                            Transform.translate(
                              offset: const Offset(0, -60),
                              child: GestureDetector(
                                onTap: _confirmPosition,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                                  ),
                                  child: const Text(
                                    'Utilisez Ce Point',
                                    style: TextStyle(color: Color(0xFF467DB0), fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                          // Le Pin
                          Icon(Icons.location_on, size: 50, color: const Color(0xFF467DB0).withOpacity(_isMoving ? 0.6 : 1.0)),
                        ],
                      ),
                    ),
                  ),

                // 🔙 BOUTON RETOUR
                Positioned(
                  top: 50,
                  left: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 22, color: Colors.black87),
                    ),
                  ),
                ),
                
                // 📍 BOTTOM SHEET (DESIGN CAPTURE)
                DraggableScrollableSheet(
                  initialChildSize: _destinationPosition == null ? 0.38 : 0.65,
                  minChildSize: 0.25,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 25)],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                        children: [
                          // Titre
                          const Center(
                            child: Text(
                              'Ajouter ma position',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            ),
                          ),
                          const SizedBox(height: 35),
                          
                          // Option "Utiliser la position actuelle"
                          GestureDetector(
                            onTap: _getCurrentLocation,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F7FA), // Bleu très clair/Cyan
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.near_me_outlined, color: Color(0xFF00BCD4), size: 26),
                                ),
                                const SizedBox(width: 18),
                                const Text(
                                  'Utiliser la position actuelle',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF467DB0)),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 15),
                          const Divider(height: 1, color: Color(0xFFF5F5F5)),
                          const SizedBox(height: 25),
                          
                          // Champ de recherche dynamique
                          const Text('Rechercher une adresse', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _showSearchBottomSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFEEEEEE)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search, color: Colors.black45, size: 22),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Text(
                                      _isMoving ? 'Localisation en cours...' : _centerAddress,
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _isMoving ? Colors.blueGrey : Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          if (_destinationPosition != null) ...[
                            const SizedBox(height: 30),
                            // Options véhicules et confirmation (si destination choisie)
                            const Text('Type de transport', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(child: _buildVehicleCard('ambulance', Icons.local_hospital, 'Ambulance', Colors.red)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildVehicleCard('taxi', Icons.local_taxi, 'Taxi', Colors.orange)),
                              ],
                            ),
                            const SizedBox(height: 30),
                            // Bouton Confirmer
                            if (_priceEstimate != null) ...[
                               Text(
                                 'Estimation: ${_priceEstimate!['price_mad'].toStringAsFixed(0)} MAD',
                                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF467DB0)),
                                 textAlign: TextAlign.center,
                               ),
                               const SizedBox(height: 15),
                               SizedBox(
                                 width: double.infinity,
                                 height: 55,
                                 child: ElevatedButton(
                                   onPressed: _isCreatingRide ? null : _createRide,
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: const Color(0xFF467DB0),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                   ),
                                   child: const Text('Confirmer la course', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                 ),
                               ),
                            ],
                          ] else ...[
                            const SizedBox(height: 30),
                            const Center(
                              child: Text(
                                'Vous n\'avez aucune adresse.',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildVehicleCard(String type, IconData icon, String label, Color color) {
    final isSelected = _vehicleType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _vehicleType = type);
        _calculatePrice();
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? color : Colors.grey[200]!, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 30),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showSearchBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: AddressAutocompleteField(
          controller: _destinationController,
          label: 'Rechercher une adresse',
          hint: 'Ex: Hôpital Ibn Sina...',
          icon: Icons.search,
          sessionToken: _sessionToken,
          currentLocation: _currentPosition,
          onPlaceSelected: (place) async {
            await _onDestinationSelected(place);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
