import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/osm_map_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../rating_screen.dart';
import '../chat/chat_screen.dart';
import '../ride/ride_completion_screen.dart';
import '../../services/phone_call_service.dart';

/// 🚗 Écran de suivi de course temps réel pour le Patient
/// Affiche la position du chauffeur sur la carte en temps réel
class PatientLiveTrackingScreen extends StatefulWidget {
  final String rideId;
  final String? pickupAddress;
  final String? destinationAddress;
  final String? estimatedPrice;

  const PatientLiveTrackingScreen({
    super.key, 
    required this.rideId,
    this.pickupAddress,
    this.destinationAddress,
    this.estimatedPrice,
  });

  @override
  State<PatientLiveTrackingScreen> createState() => _PatientLiveTrackingScreenState();
}

class _PatientLiveTrackingScreenState extends State<PatientLiveTrackingScreen> {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  bool _canShowMap = false; 
  bool _isDisposed = false; 
  
  // Données
  Map<String, dynamic>? _rideData;
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  
  // Positions
  LatLng? _driverPosition;
  LatLng? _pickupPosition;
  LatLng? _destinationPosition;
  
  // Markers et polylines
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  
  // Subscriptions
  RealtimeChannel? _rideChannel;
  RealtimeChannel? _driverChannel;
  Timer? _refreshTimer;
  
  // Status
  String _currentStatus = 'pending';
  String _statusText = 'Recherche d\'un chauffeur...';
  Color _statusColor = Colors.orange;
  IconData _statusIcon = Icons.search;
  
  // ETA
  String _estimatedArrival = '--';
  
  // Rating
  bool _hasShownRating = false;

  @override
  void initState() {
    super.initState();
    _loadRideData();
    _subscribeToRideUpdates();
    _startAutoRefresh();
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
    _rideChannel?.unsubscribe();
    _driverChannel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRideData() async {
    try {
      final response = await _supabase
          .from('rides')
          .select('''
            *,
            driver:drivers(
              id,
              user_id,
              first_name,
              last_name,
              phone_number,
              vehicle:vehicles(make, model, plate_number, color, vehicle_type)
            )
          ''')
          .eq('id', widget.rideId)
          .single();
      
      // Récupérer la position du chauffeur depuis driver_locations
      if (response['driver'] != null) {
        try {
          final locationResponse = await _supabase
              .from('driver_locations')
              .select('lat, lng')
              .eq('driver_id', response['driver']['id'])
              .maybeSingle();
          if (locationResponse != null) {
            response['driver']['current_latitude'] = locationResponse['lat'];
            response['driver']['current_longitude'] = locationResponse['lng'];
          }
        } catch (e) {
          print('⚠️ Position chauffeur non disponible: $e');
        }
      }

      if (mounted) {
        final newStatus = response['status'] ?? 'pending';
        print('🔄 _loadRideData: ancien status=$_currentStatus, nouveau status=$newStatus');
        
        setState(() {
          _rideData = response;
          _driverData = response['driver'];
          _currentStatus = newStatus;
          _isLoading = false;
          
          // Positions
          if (response['pickup_latitude'] != null && response['pickup_longitude'] != null) {
            _pickupPosition = LatLng(
              (response['pickup_latitude'] as num).toDouble(),
              (response['pickup_longitude'] as num).toDouble(),
            );
          }
          if (response['destination_latitude'] != null && response['destination_longitude'] != null) {
            _destinationPosition = LatLng(
              (response['destination_latitude'] as num).toDouble(),
              (response['destination_longitude'] as num).toDouble(),
            );
          }
          
          // Position chauffeur
          if (_driverData != null && 
              _driverData!['current_latitude'] != null && 
              _driverData!['current_longitude'] != null) {
            _driverPosition = LatLng(
              (_driverData!['current_latitude'] as num).toDouble(),
              (_driverData!['current_longitude'] as num).toDouble(),
            );
            
            // S'abonner aux mises à jour de position du chauffeur
            _subscribeToDriverPosition(_driverData!['id']);
          }
          
          _updateStatusDisplay(); // Vérifie aussi si completed → écran paiement
          _updateMarkers();
          _calculateETA();
        });
      }
      
      print('✅ Données course patient chargées: ${_rideData?['id']}, status: $_currentStatus');
    } catch (e) {
      print('❌ Erreur chargement course patient: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToRideUpdates() {
    print('🔔 Subscription Realtime pour course: ${widget.rideId}');
    _rideChannel = _supabase
        .channel('patient_ride_${widget.rideId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.rideId,
          ),
          callback: (payload) {
            print('🔄 Mise à jour course reçue (patient): ${payload.newRecord}');
            _loadRideData();
          },
        )
        .subscribe((status, error) {
          print('📡 Statut subscription rides: $status, error: $error');
        });
  }

  void _subscribeToDriverPosition(String driverId) {
    _driverChannel?.unsubscribe();
    
    _driverChannel = _supabase
        .channel('driver_position_$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['lat'] != null && newRecord['lng'] != null) {
              print('📍 Nouvelle position chauffeur: ${newRecord['lat']}, ${newRecord['lng']}');
              
              setState(() {
                _driverPosition = LatLng(
                  (newRecord['lat'] as num).toDouble(),
                  (newRecord['lng'] as num).toDouble(),
                );
                _updateMarkers();
                _calculateETA();
              });
              
              // Animer la caméra vers la nouvelle position
              if (_driverPosition != null) {
                _mapController.move(_driverPosition!, 14);
              }
            }
          },
        )
        .subscribe();
    
    print('📍 Écoute position chauffeur $driverId activée');
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadRideData();
      }
    });
  }

  void _updateStatusDisplay() {
    print('📊 _updateStatusDisplay: status=$_currentStatus, hasShownRating=$_hasShownRating');
    
    switch (_currentStatus) {
      case 'pending':
        _statusText = '🔍 Recherche d\'un chauffeur...';
        _statusColor = Colors.orange;
        _statusIcon = Icons.search;
        break;
      case 'accepted':
        _statusText = '🚗 Chauffeur en route vers vous';
        _statusColor = Colors.blue;
        _statusIcon = Icons.directions_car;
        break;
      case 'arrived':
        _statusText = '📍 Chauffeur arrivé - Il vous attend';
        _statusColor = Colors.green;
        _statusIcon = Icons.person_pin_circle;
        break;
      case 'in_progress':
        _statusText = '🏃 Course en cours';
        _statusColor = const Color(0xFF4CAF50);
        _statusIcon = Icons.local_hospital;
        break;
      case 'completed':
        _statusText = '✅ Course terminée';
        _statusColor = Colors.teal;
        _statusIcon = Icons.check_circle;
        // Déclencher l'écran de paiement si pas encore affiché
        if (!_hasShownRating && _rideData != null) {
          print('💳 Status completed détecté, déclenchement écran paiement...');
          _hasShownRating = true;
          _showRatingScreen();
        }
        break;
      case 'cancelled':
        _statusText = '❌ Course annulée';
        _statusColor = Colors.red;
        _statusIcon = Icons.cancel;
        break;
      default:
        _statusText = 'En cours...';
        _statusColor = Colors.grey;
        _statusIcon = Icons.hourglass_empty;
    }
  }

  /// 💳 Affiche l'écran de paiement puis de notation
  void _showRatingScreen() {
    print('💳 _showRatingScreen appelé - Ouverture écran paiement');
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _rideData != null) {
        print('💳 Navigation vers RideCompletionScreen...');
        try {
          // Ouvrir l'écran de complétion (paiement + notation)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RideCompletionScreen(
                rideId: widget.rideId,
                rideDetails: _rideData!,
                isDriver: false,
              ),
            ),
          );
          print('✅ Navigation réussie');
        } catch (e) {
          print('❌ Erreur navigation RideCompletionScreen: $e');
        }
      } else {
        print('❌ Impossible d\'ouvrir RideCompletionScreen: mounted=$mounted, rideData=${_rideData != null}');
      }
    });
  }

  void _updateMarkers() {
    _markers.clear();
    
    // Marker position du patient (pickup)
    // Marker position du patient (pickup)
    if (_pickupPosition != null) {
      _markers.add(Marker(
        point: _pickupPosition!,
        width: 50,
        height: 50,
        child: const Icon(Icons.person_pin_circle, color: Colors.green, size: 40),
      ));
    }
    
    // Marker destination
    if (_destinationPosition != null) {
      _markers.add(Marker(
        point: _destinationPosition!,
        width: 50,
        height: 50,
        child: const Icon(Icons.flag, color: Colors.red, size: 40),
      ));
    }
    
    // Marker chauffeur (position temps réel)
    if (_driverPosition != null && _driverData != null) {
      _markers.add(Marker(
        point: _driverPosition!,
        width: 60,
        height: 60,
        child: const Icon(Icons.directions_car, color: Colors.blue, size: 45),
      ));
    }
    
    _drawRoute();
  }

  void _drawRoute() {
    _polylines.clear();
    
    List<LatLng> points = [];
    
    // Tracer la route chauffeur → patient → destination
    if (_driverPosition != null) points.add(_driverPosition!);
    if (_pickupPosition != null) points.add(_pickupPosition!);
    if (_destinationPosition != null) points.add(_destinationPosition!);
    
    if (points.length >= 2) {
      _polylines.add(Polyline(
        points: points,
        color: _statusColor,
        strokeWidth: 4,
      ));
    }
  }

  void _calculateETA() {
    // Calcul simplifié de l'ETA basé sur la distance
    if (_driverPosition != null && _pickupPosition != null) {
      final distance = _calculateDistance(
        _driverPosition!.latitude, _driverPosition!.longitude,
        _pickupPosition!.latitude, _pickupPosition!.longitude,
      );
      
      // Estimation: 30 km/h en ville
      final etaMinutes = (distance / 30 * 60).round();
      
      if (etaMinutes <= 1) {
        _estimatedArrival = '< 1 min';
      } else if (etaMinutes < 60) {
        _estimatedArrival = '$etaMinutes min';
      } else {
        final hours = etaMinutes ~/ 60;
        final mins = etaMinutes % 60;
        _estimatedArrival = '${hours}h${mins > 0 ? ' ${mins}min' : ''}';
      }
    } else {
      _estimatedArrival = '--';
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Formule Haversine simplifiée
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  void _callDriver() async {
    final phone = _driverData?['phone_number'];
    final driverName = '${_driverData?['first_name'] ?? ''} ${_driverData?['last_name'] ?? ''}'.trim();
    final displayName = driverName.isNotEmpty ? driverName : 'Chauffeur';
    
    if (phone != null && phone.toString().isNotEmpty) {
      PhoneCallService.showCallDialog(
        context: context,
        phoneNumber: phone.toString(),
        contactName: displayName,
        role: 'chauffeur',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro de téléphone non disponible'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Ouvre le chat avec le chauffeur
  void _openChat() {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final driverName = _driverData != null
        ? '${_driverData!['users']?['full_name'] ?? 'Chauffeur'}'
        : 'Chauffeur';
    final driverPhone = _driverData?['users']?['phone'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          rideId: widget.rideId,
          currentUserId: currentUserId,
          otherUserName: driverName,
          otherUserPhone: driverPhone,
          isDriver: false,
        ),
      ),
    );
  }

  Future<void> _cancelRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la course'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette course ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('rides')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.rideId);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chargement...'),
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_rideData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course introuvable')),
        body: const Center(child: Text('Cette course n\'existe pas')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Carte Google Maps (affichée seulement après un délai)
          if (_canShowMap)
            OSMMapWidget(
              initialCenter: _pickupPosition ?? const LatLng(33.5731, -7.5898),
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
          
          // Bouton retour
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          // ETA badge (si chauffeur assigné)
          if (_driverPosition != null && _currentStatus == 'accepted')
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    Text(
                      _estimatedArrival,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Panel inférieur
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  void _fitBounds() {
    if (_pickupPosition != null) {
        _mapController.move(_pickupPosition!, 14);
    }
  }

  Widget _buildBottomPanel() {
    final vehicle = _driverData?['vehicle'];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Status bar avec bouton actualiser
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _statusColor, width: 2),
            ),
            child: Row(
              children: [
                Icon(_statusIcon, color: _statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _statusColor,
                    ),
                  ),
                ),
                // Bouton actualiser
                IconButton(
                  onPressed: () async {
                    print('🔄 Actualisation manuelle...');
                    await _loadRideData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Statut: $_currentStatus'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: _statusColor,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  color: _statusColor,
                  tooltip: 'Actualiser',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Infos chauffeur (si assigné)
          if (_driverData != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _driverData?['photo_url'] != null
                        ? NetworkImage(_driverData!['photo_url'])
                        : null,
                    child: _driverData?['photo_url'] == null
                        ? const Icon(Icons.person, size: 32, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _driverData != null
                              ? '${_driverData!['first_name'] ?? ''} ${_driverData!['last_name'] ?? ''}'.trim()
                              : 'Chauffeur',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (vehicle != null)
                          Text(
                            '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} • ${vehicle['plate_number'] ?? ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Bouton chat
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: IconButton(
                      icon: const Icon(Icons.chat, color: Colors.blue),
                      onPressed: _openChat,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bouton appeler
                  CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: _callDriver,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ] else ...[
            // Pas encore de chauffeur
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Nous recherchons un chauffeur disponible à proximité...',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
          
          // Adresses
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildAddressRow(
                  Icons.radio_button_checked,
                  Colors.green,
                  'Départ',
                  _rideData?['pickup_address'] ?? 'Votre position',
                ),
                Container(
                  margin: const EdgeInsets.only(left: 11),
                  height: 20,
                  width: 2,
                  color: Colors.grey.shade300,
                ),
                _buildAddressRow(
                  Icons.location_on,
                  Colors.red,
                  'Destination',
                  _rideData?['destination_address'] ?? 'Destination',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Prix estimé
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Prix estimé',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  '${_rideData?['estimated_price']?.toStringAsFixed(2) ?? '0.00'} MAD',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // DEBUG: Afficher le status actuel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Status actuel: $_currentStatus',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Bouton Payer & Évaluer (si course terminée)
          if (_currentStatus == 'completed')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_rideData != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RideCompletionScreen(
                            rideId: widget.rideId,
                            rideDetails: _rideData!,
                            isDriver: false,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: const Text(
                    'Payer & Évaluer',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          
          // Bouton annuler (si pas terminé)
          if (_currentStatus != 'completed' && _currentStatus != 'cancelled')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelRide,
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text(
                    'Annuler la course',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, Color color, String title, String address) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
