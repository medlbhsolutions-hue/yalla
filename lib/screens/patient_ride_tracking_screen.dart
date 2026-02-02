import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../src/widgets/osm_map_widget.dart';
import '../src/services/database_service.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../src/screens/chat/chat_screen.dart';
import '../src/utils/logger.dart';
import '../src/screens/mock_payment_screen.dart'; // ✅ Mock Payment pour démo

/// Écran de tracking de la course pour le PATIENT
/// Affiche : position du chauffeur, statut, ETA, infos chauffeur
class PatientRideTrackingScreen extends StatefulWidget {
  final String rideId;

  const PatientRideTrackingScreen({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  @override
  State<PatientRideTrackingScreen> createState() => _PatientRideTrackingScreenState();
}

class _PatientRideTrackingScreenState extends State<PatientRideTrackingScreen> {
  final MapController _mapController = MapController();
  bool _canShowMap = false; 
  bool _isDisposed = false; 
  bool _hasNavigatedToPayment = false; // ✅ Anti-double navigation
  Map<String, dynamic>? _rideData;
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  // Position du chauffeur
  // Position du chauffeur
  LatLng? _driverPosition;
  final List<Marker> _markers = [];

  // Statut de la course
  String _rideStatus = 'pending';
  String _statusMessage = 'En attente d\'un chauffeur...';
  IconData _statusIcon = Icons.schedule;
  Color _statusColor = Colors.orange;


  @override
  void initState() {
    super.initState();
    _loadRideData();
    // Rafraîchir toutes les 5 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadRideData();
    });
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
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRideData() async {
    try {
      // Récupérer les données de la course
      final response = await DatabaseService.client
          .from('rides')
          .select('''
            *,
            drivers(
              id,
              first_name,
              last_name,
              phone_number,
              vehicles(
                make,
                model,
                plate_number,
                color
              )
            )
          ''')
          .eq('id', widget.rideId)
          .single();
      
      // Récupérer la position du chauffeur depuis driver_locations
      if (response['drivers'] != null) {
        try {
          final locationResponse = await DatabaseService.client
              .from('driver_locations')
              .select('lat, lng')
              .eq('driver_id', response['drivers']['id'])
              .maybeSingle();
          if (locationResponse != null) {
            response['drivers']['current_longitude'] = locationResponse['lng'];
          }
        } catch (e) {
          Logger.debug('Position chauffeur non disponible ($e)', 'GPS');
        }
      }

      if (!mounted) return;

      setState(() {
        _rideData = response;
        _rideStatus = response['status'] ?? 'pending';
        
        // Récupérer infos chauffeur si assigné
        if (response['drivers'] != null) {
          _driverData = response['drivers'];
          
          // Position du chauffeur
          final lat = _driverData!['current_latitude'];
          final lng = _driverData!['current_longitude'];
          if (lat != null && lng != null) {
            _driverPosition = LatLng(lat, lng);
            _updateMarkers();
          }
        }
        
        _updateStatusMessage();
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Erreur chargement données course', e, null, 'RIDE');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateStatusMessage() {
    switch (_rideStatus) {
      case 'pending':
        _statusMessage = 'Recherche d\'un chauffeur disponible...';
        _statusIcon = Icons.search;
        _statusColor = Colors.orange;
        break;
      case 'accepted':
        _statusMessage = 'Chauffeur trouvé ! Il se prépare...';
        _statusIcon = Icons.check_circle;
        _statusColor = Colors.green;
        break;
      case 'driver_en_route':
        _statusMessage = 'Le chauffeur est en route vers vous';
        _statusIcon = Icons.drive_eta;
        _statusColor = Colors.blue;
        break;
      case 'arrived':
        _statusMessage = 'Le chauffeur est arrivé !';
        _statusIcon = Icons.location_on;
        _statusColor = Colors.green;
        break;
      case 'in_progress':
        _statusMessage = 'Course en cours...';
        _statusIcon = Icons.local_taxi;
        _statusColor = Colors.blue;
        break;
      case 'completed':
        _statusMessage = 'Course terminée';
        _statusIcon = Icons.check_circle;
        _statusColor = Colors.green;
        
        // Navigation auto vers paiement simulé pour démo
        if (!_hasNavigatedToPayment && mounted) {
           _hasNavigatedToPayment = true;
           Logger.success('Navigation vers écran de paiement (Simulation)', 'RIDE');
           WidgetsBinding.instance.addPostFrameCallback((_) {
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(
                 builder: (_) => MockPaymentScreen(rideData: _rideData ?? {}),
               ),
             );
           });
        }
        break;
      case 'cancelled':
        _statusMessage = 'Course annulée';
        _statusIcon = Icons.cancel;
        _statusColor = Colors.red;
        break;
      default:
        _statusMessage = 'Statut inconnu';
        _statusIcon = Icons.help;
        _statusColor = Colors.grey;
    }
  }

  void _updateMarkers() {
    _markers.clear();
    
    // Marker position patient (départ)
    if (_rideData != null) {
      final pickupLat = _rideData!['pickup_latitude'];
      final pickupLng = _rideData!['pickup_longitude'];
      if (pickupLat != null && pickupLng != null) {
        _markers.add(
          Marker(
            point: LatLng(pickupLat, pickupLng),
            width: 50,
            height: 50,
            child: const Icon(Icons.person_pin_circle, color: Colors.green, size: 40),
          ),
        );
      }
      
      // Marker destination
      final destLat = _rideData!['destination_latitude'];
      final destLng = _rideData!['destination_longitude'];
      if (destLat != null && destLng != null) {
        _markers.add(
          Marker(
            point: LatLng(destLat, destLng),
            width: 50,
            height: 50,
            child: const Icon(Icons.flag, color: Colors.red, size: 40),
          ),
        );
      }
    }
    
    // Marker position chauffeur (avec Icône Custom ou Violet)
    if (_driverPosition != null) {
      _markers.add(
        Marker(
          point: _driverPosition!,
          width: 60,
          height: 60,
          child: const Icon(Icons.directions_car, color: Colors.purple, size: 45),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de ma course'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : Column(
              children: [
                // Carte statut
                _buildStatusCard(),
                
                // Infos chauffeur (si assigné)
                if (_driverData != null) _buildDriverInfoCard(),
                
                // Carte Google Maps
                Expanded(
                  child: _buildMap(),
                ),
                
                // Actions
                _buildActionsBar(),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: _statusColor.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(_statusIcon, color: _statusColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Course #${widget.rideId.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    final driverName = '${_driverData!['first_name'] ?? ''} ${_driverData!['last_name'] ?? ''}'.trim();
    final vehicles = _driverData!['vehicles'];
    String vehicleInfo = 'Véhicule non renseigné';
    
    // Gérer le cas où vehicles est un Map (objet unique) ou une List
    Map<String, dynamic>? vehicleData;
    if (vehicles != null) {
      if (vehicles is Map) {
        vehicleData = vehicles as Map<String, dynamic>;
      } else if (vehicles is List && vehicles.isNotEmpty) {
        vehicleData = vehicles[0] as Map<String, dynamic>;
      }
    }
    
    if (vehicleData != null) {
      final make = vehicleData['make'] ?? '';
      final model = vehicleData['model'] ?? '';
      final color = vehicleData['color'] ?? '';
      final plate = vehicleData['plate_number'] ?? '';
      vehicleInfo = '$make $model'.trim();
      if (color.isNotEmpty) vehicleInfo += ' - $color';
      if (plate.isNotEmpty) vehicleInfo += ' ($plate)';
      if (vehicleInfo.trim().isEmpty || vehicleInfo == ' - ') {
        vehicleInfo = 'Véhicule non renseigné';
      }
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
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
          // Avatar chauffeur
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
            child: const Icon(
              Icons.person,
              size: 32,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 16),
          
          // Infos
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
                    const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vehicleInfo,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Bouton Chat
          IconButton(
            onPressed: () {
                final currentUser = DatabaseService.client.auth.currentUser;
                if (currentUser != null) {
                    Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ChatScreen(
                                rideId: widget.rideId,
                                currentUserId: currentUser.id,
                                otherUserName: driverName,
                                otherUserPhone: _driverData?['phone_number'],
                                isDriver: false,
                            ),
                        ),
                    );
                }
            },
            icon: const Icon(Icons.chat_bubble, color: Colors.blue),
            iconSize: 28,
          ),
          const SizedBox(width: 8),
          
          // Bouton appeler
          IconButton(
            onPressed: () {
              // TODO: Implémenter appel téléphonique
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonction appel à implémenter')),
              );
            },
            icon: const Icon(Icons.phone, color: Color(0xFF4CAF50)),
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    // Position par défaut : Casablanca
    final LatLng initialPosition = _driverPosition ?? 
        (_rideData != null && _rideData!['pickup_latitude'] != null
            ? LatLng(_rideData!['pickup_latitude'], _rideData!['pickup_longitude'])
            : const LatLng(33.5731, -7.5898));
    
    if (!_canShowMap) return const Center(child: CircularProgressIndicator());

    return OSMMapWidget(
      initialCenter: initialPosition,
      initialZoom: 14,
      mapController: _mapController,
      markers: _markers,
    );
  }

  Widget _buildActionsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bouton annuler (si pending ou accepted)
          if (_rideStatus == 'pending' || _rideStatus == 'accepted')
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _showCancelConfirmation();
                },
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          
          // Bouton rafraîchir
          if (_rideStatus != 'pending' && _rideStatus != 'accepted')
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loadRideData,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Actualiser',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCancelConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la course ?'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette course ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cancelRide();
    }
  }

  Future<void> _cancelRide() async {
    try {
      await DatabaseService.client
          .from('rides')
          .update({
            'status': 'cancelled',
            'cancellation_reason': 'Annulée par le patient',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.rideId);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course annulée'),
          backgroundColor: Colors.red,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      print('❌ Erreur annulation course: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
