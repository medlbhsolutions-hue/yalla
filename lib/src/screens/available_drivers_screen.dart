import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import 'book_ride_screen.dart';

/// Écran affichant les chauffeurs disponibles à proximité
class AvailableDriversScreen extends StatefulWidget {
  const AvailableDriversScreen({Key? key}) : super(key: key);

  @override
  State<AvailableDriversScreen> createState() => _AvailableDriversScreenState();
}

class _AvailableDriversScreenState extends State<AvailableDriversScreen> {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = false;
  Position? _currentPosition;
  String _statusMessage = 'Appuyez pour rechercher des chauffeurs';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _statusMessage = 'Permission de localisation refusée';
          });
          return;
        }
      }

      // Récupérer la position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _statusMessage = 'Position obtenue: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
      
      // Charger automatiquement les chauffeurs
      await _loadNearbyDrivers();
    } catch (e) {
      print('❌ Erreur localisation: $e');
      setState(() {
        _statusMessage = 'Erreur: Impossible d\'obtenir votre position';
      });
      
      // Utiliser une position par défaut (Casablanca, Maroc)
      _currentPosition = Position(
        latitude: 33.5731,
        longitude: -7.5898,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      
      setState(() {
        _statusMessage = 'Utilisation de Casablanca, Maroc comme position par défaut';
      });
      
      await _loadNearbyDrivers();
    }
  }

  Future<void> _loadNearbyDrivers() async {
    if (_currentPosition == null) {
      setState(() {
        _statusMessage = 'Position non disponible';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Recherche de chauffeurs disponibles...';
    });

    try {
      print('🔍 Recherche chauffeurs près de: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      
      final drivers = await DatabaseService.getNearbyDrivers(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusKm: 10.0,
      );

      setState(() {
        _drivers = drivers;
        _isLoading = false;
        _statusMessage = '${drivers.length} chauffeur(s) disponible(s) dans un rayon de 10 km';
      });
      
      print('✅ ${drivers.length} chauffeurs chargés');
    } catch (e) {
      print('❌ Erreur chargement chauffeurs: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Erreur: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        title: const Text(
          'Chauffeurs Disponibles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadNearbyDrivers,
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête avec statut
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isLoading ? Icons.search : Icons.location_on,
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des chauffeurs
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _drivers.isEmpty
                    ? _buildEmptyState()
                    : _buildDriversList(),
          ),

          // Bouton de recherche fixe en bas
          if (!_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loadNearbyDrivers,
                  icon: const Icon(Icons.search),
                  label: const Text(
                    'Actualiser la recherche',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF4CAF50),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recherche en cours...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun chauffeur disponible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez d\'actualiser ou élargir votre zone de recherche',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return _buildDriverCard(driver);
      },
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    // Extraire les informations du chauffeur
    final firstName = driver['first_name'] ?? 'Prénom';
    final lastName = driver['last_name'] ?? 'Nom';
    final fullName = '$firstName $lastName';
    final rating = (driver['rating'] ?? 0.0).toDouble();
    final isAvailable = driver['is_available'] ?? false;
    
    // Extraire les informations du véhicule (de la relation vehicles)
    final vehicles = driver['vehicles'];
    String vehicleInfo = 'Véhicule non spécifié';
    String vehicleType = 'standard';
    
    if (vehicles != null) {
      if (vehicles is List && vehicles.isNotEmpty) {
        final vehicle = vehicles.first;
        final make = vehicle['make'] ?? '';
        final model = vehicle['model'] ?? '';
        final year = vehicle['year'] ?? '';
        vehicleType = vehicle['vehicle_type'] ?? 'standard';
        vehicleInfo = '$make $model $year'.trim();
      } else if (vehicles is Map) {
        final make = vehicles['make'] ?? '';
        final model = vehicles['model'] ?? '';
        final year = vehicles['year'] ?? '';
        vehicleType = vehicles['vehicle_type'] ?? 'standard';
        vehicleInfo = '$make $model $year'.trim();
      }
    }

    // Calculer la distance (simulation pour l'instant)
    final distance = (2.5 + (driver['id'].hashCode % 50) / 10).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigation vers l'écran de réservation
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookRideScreen(driver: driver),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF4CAF50),
                    child: Text(
                      '${firstName[0]}${lastName[0]}'.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Infos chauffeur
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAvailable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Disponible',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.location_on, color: Colors.grey, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$distance km',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Informations du véhicule
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getVehicleIcon(vehicleType),
                      color: const Color(0xFF4CAF50),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vehicleInfo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _getVehicleTypeLabel(vehicleType),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'ambulance':
        return Icons.local_hospital;
      case 'van':
        return Icons.airport_shuttle;
      case 'wheelchair':
        return Icons.accessible;
      default:
        return Icons.directions_car;
    }
  }

  String _getVehicleTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'ambulance':
        return 'Ambulance';
      case 'van':
        return 'Van médical';
      case 'wheelchair':
        return 'PMR';
      case 'standard':
        return 'Standard';
      default:
        return type;
    }
  }
}
