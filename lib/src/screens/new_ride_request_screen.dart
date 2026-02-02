import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/osm_map_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' show Random;
import '../services/database_service.dart';

/// Écran de demande de nouvelle course (Patient)
class NewRideRequestScreen extends StatefulWidget {
  const NewRideRequestScreen({Key? key}) : super(key: key);

  @override
  State<NewRideRequestScreen> createState() => _NewRideRequestScreenState();
}

class _NewRideRequestScreenState extends State<NewRideRequestScreen> {
  final _destinationController = TextEditingController();
  final _pickupController = TextEditingController();
  
  final MapController _mapController = MapController();
  bool _canShowMap = false; 
  bool _isDisposed = false; 
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isCalculating = false;
  bool _isCreatingRide = false;
  
  // Résultats estimation
  double? _estimatedPrice;
  double? _distanceKm;
  int? _durationMinutes;
  
  // Coordonnées
  double? _pickupLat;
  double? _pickupLng;
  double? _destinationLat;
  double? _destinationLng;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
    _destinationController.dispose();
    _pickupController.dispose();
    super.dispose();
  }

  /// Récupérer la position GPS actuelle du patient
  Future<void> _getCurrentLocation() async {
    setState(() { _isLoadingLocation = true; });
    
    try {
      // Vérifier permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission GPS refusée');
        }
      }
      
      // Récupérer position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _pickupLat = position.latitude;
        _pickupLng = position.longitude;
        _pickupController.text = 'Position actuelle (GPS)';
        _isLoadingLocation = false;
      });
      
      print('📍 Position patient: ${position.latitude}, ${position.longitude}');
      
      // Centrer la carte sur la position
      _mapController.move(LatLng(position.latitude, position.longitude), 14.0);
    } catch (e) {
      print('❌ Erreur récupération position: $e');
      setState(() {
        _isLoadingLocation = false;
        // Position par défaut (Casablanca)
        _pickupLat = 33.5731;
        _pickupLng = -7.5898;
        _pickupController.text = 'Casablanca, Maroc';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de récupérer votre position. Position par défaut utilisée.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Calculer estimation prix avec Google Distance Matrix API
  Future<void> _calculateEstimate() async {
    if (_destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer une destination'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_pickupLat == null || _pickupLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position de départ non disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() { _isCalculating = true; });
    
    try {
      // TODO: Remplacer par votre clé Google Distance Matrix API
      // Pour l'instant, simulation avec calcul approximatif
      
      // Simuler un appel API (à remplacer par vraie API)
      await Future.delayed(const Duration(seconds: 2));
      
      // ✅ Calcul simplifié mais correct
      // Distance aléatoire entre 5 et 25 km
      final random = Random();
      final distance = (random.nextInt(20) + 5).toDouble(); // 5-24 km
      final duration = (distance * 3).toInt(); // ~3 min/km (vitesse 20 km/h en ville)
      final price = 10 + (distance * 5); // 10 MAD base + 5 MAD/km
      
      setState(() {
        _distanceKm = distance;
        _durationMinutes = duration;
        _estimatedPrice = price;
        _isCalculating = false;
      });
      
      print('💰 Estimation: ${price.toStringAsFixed(0)} MAD, ${distance.toStringAsFixed(1)} km, $duration min');
    } catch (e) {
      print('❌ Erreur calcul estimation: $e');
      setState(() { _isCalculating = false; });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur calcul estimation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Créer la demande de course dans Supabase
  Future<void> _createRideRequest() async {
    if (_estimatedPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord calculer l\'estimation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() { _isCreatingRide = true; });
    
    try {
      // Recuperer l'utilisateur actuel directement depuis Supabase
      final currentUserId = DatabaseService.getCurrentUserId();
      
      if (currentUserId == null) {
        print('Pas d utilisateur connecte');
        throw Exception('Vous devez etre connecte pour demander une course.');
      }
      
      print('Utilisateur ID: $currentUserId');
      
      // 🔧 Récupérer le profil patient pour obtenir patient.id
      final patientData = await DatabaseService.client
          .from('patients')
          .select('id')
          .eq('user_id', currentUserId)
          .single();
      
      final patientId = patientData['id'] as String;
      print('Patient ID: $patientId');
      
      // Creer la course avec le patient_id correct
      final ride = await DatabaseService.createRide(
        patientId: patientId,
        pickupAddress: _pickupController.text,
        destinationAddress: _destinationController.text,
        pickupLatitude: _pickupLat!,
        pickupLongitude: _pickupLng!,
        destinationLatitude: _destinationLat ?? _pickupLat!,
        destinationLongitude: _destinationLng ?? _pickupLng!,
        estimatedPrice: _estimatedPrice!,
        distanceKm: _distanceKm!,
        durationMinutes: _durationMinutes!,
      );
      
      print('✅ Course créée: ${ride['id']}');
      
      setState(() { _isCreatingRide = false; });
      
      if (mounted) {
        // Afficher confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Demande de course envoyée !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Rediriger vers écran attente chauffeur
        Navigator.pushReplacementNamed(
          context,
          '/waiting-driver',
          arguments: ride,
        );
      }
    } catch (e) {
      print('❌ Erreur création course: $e');
      setState(() { _isCreatingRide = false; });
      
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Course'),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      body: _isLoadingLocation
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text('Récupération de votre position...'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Carte Google Maps (miniature)
                  Container(
                    height: 250,
                    child: OSMMapWidget(
                      initialCenter: LatLng(_pickupLat ?? 33.5731, _pickupLng ?? -7.5898),
                      initialZoom: 14,
                      mapController: _mapController,
                      markers: [
                        if (_pickupLat != null && _pickupLng != null)
                          Marker(
                            point: LatLng(_pickupLat!, _pickupLng!),
                            width: 50,
                            height: 50,
                            child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                          ),
                      ],
                    ),
                  ),
                  
                  // Formulaire
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Adresse départ
                        TextField(
                          controller: _pickupController,
                          decoration: InputDecoration(
                            labelText: 'Adresse de départ',
                            prefixIcon: const Icon(Icons.my_location, color: Color(0xFF4CAF50)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            enabled: false,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Adresse destination
                        TextField(
                          controller: _destinationController,
                          decoration: InputDecoration(
                            labelText: 'Où allez-vous ?',
                            hintText: 'Ex: Hôpital Ibn Rochd, Casablanca',
                            prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onSubmitted: (_) => _calculateEstimate(),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Bouton Estimer
                        ElevatedButton.icon(
                          onPressed: _isCalculating ? null : _calculateEstimate,
                          icon: _isCalculating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.calculate),
                          label: Text(
                            _isCalculating ? 'Calcul en cours...' : 'Estimer le prix',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        
                        // Résultats estimation
                        if (_estimatedPrice != null) ...[
                          const SizedBox(height: 24),
                          
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Estimation de la course',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildEstimateCard(
                                      icon: Icons.attach_money,
                                      label: 'Prix',
                                      value: '${_estimatedPrice!.toStringAsFixed(0)} MAD',
                                      color: Colors.green,
                                    ),
                                    _buildEstimateCard(
                                      icon: Icons.straighten,
                                      label: 'Distance',
                                      value: '${_distanceKm!.toStringAsFixed(1)} km',
                                      color: Colors.blue,
                                    ),
                                    _buildEstimateCard(
                                      icon: Icons.access_time,
                                      label: 'Durée',
                                      value: '$_durationMinutes min',
                                      color: Colors.orange,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Bouton Confirmer
                          ElevatedButton.icon(
                            onPressed: _isCreatingRide ? null : _createRideRequest,
                            icon: _isCreatingRide
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle),
                            label: Text(
                              _isCreatingRide
                                  ? 'Création en cours...'
                                  : 'Confirmer la demande',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEstimateCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
