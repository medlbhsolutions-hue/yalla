import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/osm_map_widget.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/database_service.dart';
import '../../services/pricing_service.dart';
import '../../services/osm_service.dart';
import '../../widgets/address_autocomplete_field.dart';
import 'package:uuid/uuid.dart';

/// 🎨 NOUVELLE VERSION - Design moderne type Uber/Bolt
class NewRideScreenV2 extends StatefulWidget {
  final Map<String, dynamic>? patientProfile;
  
  const NewRideScreenV2({Key? key, this.patientProfile}) : super(key: key);

  @override
  State<NewRideScreenV2> createState() => _NewRideScreenV2State();
}

class _NewRideScreenV2State extends State<NewRideScreenV2> {
  final MapController _mapController = MapController();
  bool _canShowMap = false; 
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

  @override
  void initState() {
    super.initState();
    _sessionToken = const Uuid().v4();
    _getCurrentLocation();
    // Retarder l'affichage de la carte pour éviter l'erreur dispose sur Web
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _canShowMap = true);
      }
    });
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _canShowMap = false;
    _destinationController.dispose();
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
      
      final address = await OSMService.reverseGeocode(
        location: LatLng(position.latitude, position.longitude),
      );
      
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _pickupAddress = address ?? 'Position actuelle';
        _isLoadingLocation = false;
        
        _markers.add(Marker(
          point: _currentPosition!,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ));
      });
      
      _mapController.move(_currentPosition!, 14);
    } catch (e) {
      print('❌ Erreur GPS: $e');
      setState(() {
        _currentPosition = const LatLng(33.5731, -7.5898);
        _pickupAddress = 'Casablanca (par défaut)';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _onDestinationSelected(Map<String, dynamic> place) async {
    final lat = place['geometry']['location']['lat'];
    final lng = place['geometry']['location']['lng'];
    final address = place['formatted_address'] ?? place['description'];
    
    setState(() {
      _destinationPosition = LatLng(lat, lng);
      _destinationAddress = address;
      _destinationController.text = address;
      
      _markers.removeWhere((m) => m is Marker && m.point == _destinationPosition); // Approximatif
      _markers.add(Marker(
        point: _destinationPosition!,
        width: 50,
        height: 50,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ));
    });
    
    _mapController.move(_destinationPosition!, 14);
    
    await _calculatePrice();
  }

  Future<void> _calculatePrice() async {
    if (_currentPosition == null || _destinationPosition == null) return;
    
    setState(() { _isCalculatingPrice = true; });
    
    try {
      final estimate = await PricingService.calculatePriceEstimateWithDirections(
        pickupLat: _currentPosition!.latitude,
        pickupLng: _currentPosition!.longitude,
        destinationLat: _destinationPosition!.latitude,
        destinationLng: _destinationPosition!.longitude,
      );
      
      setState(() {
        _priceEstimate = estimate;
        _isCalculatingPrice = false;
        
        if (estimate['polyline'] != null) {
          _polylines.clear();
          _polylines.add(Polyline(
            points: OSMService.decodePolyline(estimate['polyline']),
            color: const Color(0xFF4CAF50),
            strokeWidth: 4,
          ));
        }
      });
    } catch (e) {
      print('❌ Erreur calcul prix: $e');
      setState(() { _isCalculatingPrice = false; });
      _showError('Erreur lors du calcul du prix');
    }
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
      final user = DatabaseService.client.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      
      print('Utilisateur ID: ${user.id}');
      print('Patient ID: ${widget.patientProfile!['id']}');
      
      final response = await DatabaseService.createRide(
        patientId: widget.patientProfile!['id'],
        pickupAddress: _pickupAddress.isNotEmpty ? _pickupAddress : 'Position actuelle (GPS)',
        destinationAddress: _destinationAddress.isNotEmpty ? _destinationAddress : 'Destination',
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
      
      print('✅ Course créée: ${response['id']}');
      
      setState(() { _isCreatingRide = false; });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Course créée ! Recherche d\'un chauffeur...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      print('❌ Erreur création course: $e');
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text('Détection de votre position...'),
                ],
              ),
            )
          : Stack(
              children: [
                // 🗺️ CARTE GOOGLE MAPS (affichée seulement après un délai)
                if (_canShowMap)
                  OSMMapWidget(
                    initialCenter: _currentPosition ?? const LatLng(33.5731, -7.5898),
                    initialZoom: 14,
                    mapController: _mapController,
                    markers: _markers,
                    polylines: _polylines,
                  )
                else
                  Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                
                // 🔙 BOUTON RETOUR
                Positioned(
                  top: 40,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                
                // 📍 FORMULAIRE EN BAS
                DraggableScrollableSheet(
                  initialChildSize: 0.6,
                  minChildSize: 0.4,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, -5),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Barre drag
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // 📌 DÉPART
                          _buildLocationCard(
                            icon: Icons.my_location,
                            iconColor: Colors.green,
                            title: 'Point de départ',
                            address: _pickupAddress.isNotEmpty ? _pickupAddress : 'Chargement...',
                          ),
                          const SizedBox(height: 12),
                          
                          // 📍 DESTINATION
                          GestureDetector(
                            onTap: _showDestinationBottomSheet,
                            child: _buildLocationCard(
                              icon: Icons.location_on,
                              iconColor: Colors.red,
                              title: 'Destination',
                              address: _destinationAddress.isEmpty ? 'Où allez-vous ?' : _destinationAddress,
                              isClickable: true,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // OPTIONS (si destination sélectionnée)
                          if (_destinationPosition != null) ...[
                            // 🚗 VÉHICULES
                            const Text(
                              'Choisissez votre véhicule',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildVehicleCard('ambulance', Icons.local_hospital, 'Ambulance', Colors.red)),
                                const SizedBox(width: 10),
                                Expanded(child: _buildVehicleCard('vsl', Icons.accessible, 'VSL', Colors.blue)),
                                const SizedBox(width: 10),
                                Expanded(child: _buildVehicleCard('taxi', Icons.local_taxi, 'Taxi', Colors.orange)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // ⚡ PRIORITÉ
                            const Text(
                              'Priorité',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildPriorityCard('standard', '⏱️ Standard', Colors.green)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildPriorityCard('urgent', '🚨 Urgent', Colors.orange)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // 💰 PRIX
                            if (_priceEstimate != null)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Prix estimé', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_priceEstimate!['price_mad'].toStringAsFixed(0)} MAD',
                                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${_priceEstimate!['distance_km'].toStringAsFixed(1)} km',
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_priceEstimate!['duration_minutes']} min',
                                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 20),
                            
                            // ✅ BOUTON CONFIRMER
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isCreatingRide ? null : _createRide,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: _isCreatingRide
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Confirmer la course',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 40),
                            const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.location_searching, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'Choisissez une destination\npour voir les options',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                ],
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

  Widget _buildLocationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    bool isClickable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: address.contains('?') ? Colors.grey : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isClickable) Icon(Icons.edit, color: Colors.grey.shade400, size: 20),
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityCard(String type, String label, Color color) {
    final isSelected = _rideType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _rideType = type);
        _calculatePrice();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  void _showDestinationBottomSheet() {
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Où allez-vous ?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: AddressAutocompleteField(
                controller: _destinationController,
                label: 'Rechercher une adresse',
                hint: 'Ex: Hôpital Ibn Sina, Casa Port...',
                icon: Icons.search,
                sessionToken: _sessionToken,
                currentLocation: _currentPosition,
                onPlaceSelected: (place) async {
                  await _onDestinationSelected(place);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
