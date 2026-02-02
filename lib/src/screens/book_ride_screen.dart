import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import '../services/database_service.dart';
import 'ride_confirmation_screen.dart';

/// Écran de réservation de course
/// Permet de saisir pickup/destination et créer une course
class BookRideScreen extends StatefulWidget {
  final Map<String, dynamic> driver;

  const BookRideScreen({
    Key? key,
    required this.driver,
  }) : super(key: key);

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  
  String _selectedPriority = 'normal';
  bool _isLoading = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  /// Récupérer la position GPS actuelle
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      print('📍 Position actuelle: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Erreur GPS: $e');
      // Position par défaut (Casablanca)
      setState(() {
        _currentPosition = Position(
          latitude: 33.5731,
          longitude: -7.5898,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      });
    }
  }

  /// Calculer la distance entre deux points (formule Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Rayon de la Terre en km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// Calculer le prix estimé
  double _calculateEstimatedPrice(double distanceKm) {
    const baseFare = 20.0; // Prix de base en MAD
    const perKmRate = 5.0; // Prix par km en MAD
    
    // Majoration selon priorité
    double priorityMultiplier = 1.0;
    switch (_selectedPriority) {
      case 'urgent':
        priorityMultiplier = 1.5;
        break;
      case 'emergency':
        priorityMultiplier = 2.0;
        break;
      default:
        priorityMultiplier = 1.0;
    }
    
    return (baseFare + (distanceKm * perKmRate)) * priorityMultiplier;
  }

  /// Créer la course
  Future<void> _createRide() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position GPS non disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Coordonnées de destination simulées (Rabat Hassan pour démo)
      final destinationLat = 33.9716;
      final destinationLng = -6.8498;

      // Calculer la distance
      final distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        destinationLat,
        destinationLng,
      );

      // Calculer le prix
      final estimatedPrice = _calculateEstimatedPrice(distance);
      
      // Estimer la durée (60 km/h moyenne = 1 km/min)
      final durationMinutes = distance.round(); // 60 km/h = 1 km par minute

      // Récupérer l'utilisateur actuel
      final currentUserId = DatabaseService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('Utilisateur non connecté');
      }

      print('🎫 Création course:');
      print('   Pickup: ${_pickupController.text}');
      print('   Destination: ${_destinationController.text}');
      print('   Distance: ${distance.toStringAsFixed(2)} km');
      print('   Durée: $durationMinutes min');
      print('   Prix: ${estimatedPrice.toStringAsFixed(2)} MAD');
      print('   Priorité: $_selectedPriority');

      // Créer la course dans Supabase
      final rideData = await DatabaseService.createRide(
        patientId: currentUserId,
        driverId: widget.driver['id'],
        pickupAddress: _pickupController.text,
        pickupLatitude: _currentPosition!.latitude,
        pickupLongitude: _currentPosition!.longitude,
        destinationAddress: _destinationController.text,
        destinationLatitude: destinationLat,
        destinationLongitude: destinationLng,
        distanceKm: distance,
        durationMinutes: durationMinutes,
        priority: _selectedPriority,
        estimatedPrice: estimatedPrice,
      );

      print('✅ Course créée avec ID: ${rideData['id']}');

      // Navigation vers écran de confirmation
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RideConfirmationScreen(
              rideData: rideData,
              driver: widget.driver,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur création course: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = '${widget.driver['first_name']} ${widget.driver['last_name']}';
    final vehicleInfo = widget.driver['vehicles'];
    final vehicleDisplay = vehicleInfo != null
        ? '${vehicleInfo['make']} ${vehicleInfo['model']}'
        : 'Véhicule';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réserver une course'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info chauffeur
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chauffeur sélectionné',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green,
                                  radius: 30,
                                  child: Text(
                                    widget.driver['first_name'][0] +
                                        widget.driver['last_name'][0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        driverName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.driver['rating'].toString(),
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        vehicleDisplay,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
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
                    const SizedBox(height: 24),

                    // Adresse de départ
                    TextFormField(
                      controller: _pickupController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse de départ',
                        hintText: 'Ex: 123 Avenue Mohammed V, Casablanca',
                        prefixIcon: Icon(Icons.my_location, color: Colors.green),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir l\'adresse de départ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Adresse d'arrivée
                    TextFormField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse d\'arrivée',
                        hintText: 'Ex: Hôpital Ibn Sina, Rabat',
                        prefixIcon: Icon(Icons.location_on, color: Colors.red),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir l\'adresse d\'arrivée';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Priorité
                    const Text(
                      'Type de course',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'normal',
                          label: Text('Normal'),
                          icon: Icon(Icons.directions_car),
                        ),
                        ButtonSegment(
                          value: 'urgent',
                          label: Text('Urgent'),
                          icon: Icon(Icons.priority_high),
                        ),
                        ButtonSegment(
                          value: 'emergency',
                          label: Text('Urgence'),
                          icon: Icon(Icons.emergency),
                        ),
                      ],
                      selected: {_selectedPriority},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedPriority = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedPriority == 'normal'
                          ? 'Prix standard'
                          : _selectedPriority == 'urgent'
                              ? 'Prix +50%'
                              : 'Prix +100%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Bouton de réservation
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Confirmer la réservation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
