import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/osm_map_widget.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/app_colors.dart';
import '../../services/osm_service.dart';

class PharmacyMapScreen extends StatefulWidget {
  const PharmacyMapScreen({super.key});

  @override
  State<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends State<PharmacyMapScreen> {
  final MapController _mapController = MapController();
  LatLng _centerPosition = const LatLng(33.5731, -7.5898); // Default Casablanca
  String _selectedCity = 'Casablanca';
  bool _isLoading = true;
  List<Marker> _markers = [];
  
  // Coordinates for main Moroccan cities (Fallback)
  final Map<String, LatLng> _cityCoordinates = {
    'Casablanca': const LatLng(33.5731, -7.5898),
    'Rabat': const LatLng(34.0209, -6.8416),
    'Marrakech': const LatLng(31.6295, -7.9811),
    'Tanger': const LatLng(35.7595, -5.8340),
    'Agadir': const LatLng(30.4278, -9.5981),
  };

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Get real user location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        _centerPosition = LatLng(position.latitude, position.longitude);
        print('📍 Position réelle trouvée: ${_centerPosition.latitude}, ${_centerPosition.longitude}');
      }
      
      // 2. Fetch real pharmacies
      await _fetchPharmacies(_centerPosition);
      
    } catch (e) {
      print('❌ Erreur initialisation: $e');
      // Fallback on Casablanca if location fails
      await _fetchPharmacies(_centerPosition);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchPharmacies(LatLng location) async {
    final pharmacies = await OSMService.getNearbyPharmacies(location);
    
    final List<Marker> newMarkers = [];
    
    // User location marker
    newMarkers.add(
      Marker(
        point: location,
        width: 60,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
        ),
      ),
    );

    // Pharmacy markers
    for (var p in pharmacies) {
      newMarkers.add(
        Marker(
          point: LatLng(p['lat'], p['lng']),
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () => _showPharmacyDetails(p),
            child: const Icon(Icons.local_pharmacy_rounded, color: Colors.red, size: 35),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _centerPosition = location;
      });
      _mapController.move(location, 14.0);
    }
  }

  void _showPharmacyDetails(Map<String, dynamic> pharmacy) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_pharmacy, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pharmacy['name'],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DetailItem(icon: Icons.access_time, label: 'Horaires', value: pharmacy['opening_hours']),
            DetailItem(icon: Icons.phone, label: 'Téléphone', value: pharmacy['phone']),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Direct to Yalla Tbib ride?
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.local_taxi),
                label: const Text('Y ALLER AVEC YALLA L\'TBIB'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // THE MAP
          OSMMapWidget(
            mapController: _mapController,
            initialCenter: _centerPosition,
            initialZoom: 13.0,
            markers: _markers,
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // TOP HEADER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // City Selector
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCity,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
                          items: _cityCoordinates.keys.map((String city) {
                            return DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setState(() => _selectedCity = newValue);
                              _fetchPharmacies(_cityCoordinates[newValue]!);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM BUTTON
          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: GestureDetector(
              onTap: () => _fetchPharmacies(_centerPosition),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0091FF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0091FF).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'pharmacies à proximité',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailItem({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label : ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey[800]))),
        ],
      ),
    );
  }
}
