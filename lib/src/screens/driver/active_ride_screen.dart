import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/osm_map_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import '../../services/ride_status_service.dart';
import '../../services/phone_call_service.dart';
import '../chat/chat_screen.dart';
import '../rating_screen.dart';

/// 🚗 Écran de suivi de course active pour le chauffeur
/// Style professionnel type Uber/Bolt avec navigation temps réel
class ActiveRideScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic>? rideData;

  const ActiveRideScreen({
    Key? key,
    required this.rideId,
    this.rideData,
  }) : super(key: key);

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  bool _canShowMap = false; 
  bool _isDisposed = false; 
  
  // Données course
  Map<String, dynamic>? _rideData;
  Map<String, dynamic>? _patientData;
  bool _isLoading = true;
  
  // Positions
  LatLng? _driverPosition;
  LatLng? _pickupPosition;
  LatLng? _destinationPosition;
  
  // Markers et polylines
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  
  // Subscriptions
  StreamSubscription<Position>? _positionSubscription;
  RealtimeChannel? _rideChannel;
  Timer? _refreshTimer;
  
  // Timer pour le compteur de temps
  Timer? _elapsedTimer;
  DateTime? _rideStartTime;
  Duration _elapsedTime = Duration.zero;
  
  // États de la course
  String _currentStatus = 'accepted';
  String _statusText = 'En route vers le patient';
  Color _statusColor = Colors.blue;
  IconData _statusIcon = Icons.directions_car;

  @override
  void initState() {
    super.initState();
    _rideStartTime = DateTime.now();
    _startElapsedTimer();
    _loadRideData();
    _startLocationTracking();
    _subscribeToRideUpdates();
    // Retarder l'affichage de la carte pour éviter l'erreur dispose sur Web
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _canShowMap = true);
      }
    });
  }

  /// Démarre le timer pour afficher le temps écoulé
  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _rideStartTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_rideStartTime!);
        });
      }
    });
  }

  /// Formate la durée en HH:MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _canShowMap = false; 
    _positionSubscription?.cancel();
    _rideChannel?.unsubscribe();
    _refreshTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRideData() async {
    try {
      final response = await _supabase
          .from('rides')
          .select('''
            *,
            patient:patients(
              id,
              user_id,
              first_name,
              last_name,
              phone_number,
              emergency_contact_phone
            )
          ''')
          .eq('id', widget.rideId)
          .single();

      setState(() {
        _rideData = response;
        _patientData = response['patient'];
        _currentStatus = response['status'] ?? 'accepted';
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
        
        _updateStatusDisplay();
        _updateMarkers();
      });
      
      print('✅ Données course chargées: ${_rideData?['id']}');
    } catch (e) {
      print('❌ Erreur chargement course: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      // Position initiale
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        // Fallback Casablanca
        return Position(
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

      setState(() {
        _driverPosition = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });

      // Écouter les mises à jour de position
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Mise à jour tous les 5 mètres pour suivi temps réel
        ),
      ).listen((Position position) {
        setState(() {
          _driverPosition = LatLng(position.latitude, position.longitude);
          _updateMarkers();
        });
        
        // Animer la caméra pour suivre le chauffeur
        _mapController.move(_driverPosition!, 15);
        
        // Mettre à jour la position dans la base de données
        _updateDriverPosition(position);
      });
      
      print('📍 Tracking GPS chauffeur démarré');
    } catch (e) {
      print('❌ Erreur tracking GPS: $e');
    }
  }

  void _subscribeToRideUpdates() {
    _rideChannel = _supabase
        .channel('active_ride_${widget.rideId}')
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
            print('🔄 Mise à jour course reçue: ${payload.newRecord}');
            _loadRideData();
          },
        )
        .subscribe();
  }

  Future<void> _updateDriverPosition(Position position) async {
    try {
      final driverProfile = await DatabaseService.getDriverProfile();
      if (driverProfile != null) {
        // Upsert dans driver_locations
        await _supabase.from('driver_locations').upsert({
          'driver_id': driverProfile['id'],
          'lat': position.latitude,
          'lng': position.longitude,
          'speed': position.speed * 3.6, // m/s to km/h
          'heading': position.heading,
          'accuracy': position.accuracy,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'driver_id');
      }
    } catch (e) {
      print('❌ Erreur mise à jour position: $e');
    }
  }

  void _updateStatusDisplay() {
    switch (_currentStatus) {
      case 'accepted':
        _statusText = '🚗 En route vers le patient';
        _statusColor = Colors.blue;
        _statusIcon = Icons.directions_car;
        break;
      case 'arrived':
        _statusText = '📍 Arrivé - En attente du patient';
        _statusColor = Colors.orange;
        _statusIcon = Icons.person_pin_circle;
        break;
      case 'in_progress':
        _statusText = '🏃 Course en cours';
        _statusColor = Colors.green;
        _statusIcon = Icons.local_hospital;
        break;
      case 'completed':
        _statusText = '✅ Course terminée';
        _statusColor = Colors.teal;
        _statusIcon = Icons.check_circle;
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

  void _updateMarkers() {
    _markers.clear();
    
    // Marker chauffeur
    if (_driverPosition != null) {
      _markers.add(Marker(
        point: _driverPosition!,
        width: 60,
        height: 60,
        child: const Icon(Icons.directions_car, color: Colors.blue, size: 45),
      ));
    }
    
    // Marker point de prise en charge
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
    
    // Tracer la route
    _drawRoute();
  }

  void _drawRoute() {
    _polylines.clear();
    
    List<LatLng> points = [];
    
    if (_driverPosition != null) points.add(_driverPosition!);
    
    // Si pas encore arrivé au patient, tracer vers pickup
    if (_currentStatus == 'accepted' && _pickupPosition != null) {
      points.add(_pickupPosition!);
    }
    
    // Si en cours, tracer vers destination
    if (_currentStatus == 'in_progress' && _destinationPosition != null) {
      if (_pickupPosition != null) points.add(_pickupPosition!);
      points.add(_destinationPosition!);
    }
    
    if (points.length >= 2) {
      _polylines.add(Polyline(
        points: points,
        color: _statusColor,
        strokeWidth: 5,
      ));
    }
  }

  Future<void> _updateRideStatus(String newStatus) async {
    try {
      // Utiliser RideStatusService pour envoyer les notifications au patient
      final success = await RideStatusService.updateRideStatus(
        rideId: widget.rideId,
        newStatus: newStatus,
      );
      
      if (!success) {
        throw Exception('Transition de statut non autorisée');
      }
      
      setState(() {
        _currentStatus = newStatus;
        _updateStatusDisplay();
      });
      
      print('✅ Statut mis à jour: $newStatus');
      
      // Si terminé, retourner au dashboard
      if (newStatus == 'completed') {
        _showCompletionDialog();
      }
    } catch (e) {
      print('❌ Erreur mise à jour statut: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Course terminée !'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_rideData?['estimated_price'] ?? _rideData?['total_price'] ?? '0.00'} MAD',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Merci pour votre service !'),
            const SizedBox(height: 8),
            const Text('Évaluez votre patient pour améliorer le service.', 
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer dialog
              Navigator.of(context).pop(); // Retour au dashboard
            },
            child: const Text('Ignorer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer dialog
              // Ouvrir écran de notation et retourner au dashboard après
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => RatingScreen(
                    rideId: widget.rideId,
                    raterRole: 'driver',
                    targetName: _patientData != null
                        ? '${_patientData!['first_name'] ?? ''} ${_patientData!['last_name'] ?? ''}'.trim()
                        : null,
                    rideData: _rideData,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Évaluer le patient', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _callPatient() async {
    // Essayer d'abord le numéro du patient, sinon le contact d'urgence
    final patientPhone = _patientData?['phone_number'];
    final emergencyPhone = _patientData?['emergency_contact_phone'];
    final phone = patientPhone ?? emergencyPhone;
    final patientName = '${_patientData?['first_name'] ?? ''} ${_patientData?['last_name'] ?? ''}'.trim();
    final displayName = patientName.isNotEmpty ? patientName : 'Patient';
    
    if (phone != null && phone.toString().isNotEmpty) {
      PhoneCallService.showCallDialog(
        context: context,
        phoneNumber: phone.toString(),
        contactName: displayName,
        role: 'patient',
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

  /// Ouvre le chat avec le patient
  void _openChat() {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final patientName = _patientData?['users']?['full_name'] ?? 'Patient';
    final patientPhone = _patientData?['users']?['phone'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          rideId: widget.rideId,
          currentUserId: currentUserId,
          otherUserName: patientName,
          otherUserPhone: patientPhone,
          isDriver: true,
        ),
      ),
    );
  }

  void _openNavigation() async {
    LatLng? target;
    
    if (_currentStatus == 'accepted' || _currentStatus == 'arrived') {
      target = _pickupPosition;
    } else if (_currentStatus == 'in_progress') {
      target = _destinationPosition;
    }
    
    if (target != null) {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=driving'
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Carte Google Maps (affichée seulement après un délai)
          if (_canShowMap)
            OSMMapWidget(
              initialCenter: _driverPosition ?? _pickupPosition ?? const LatLng(33.5731, -7.5898),
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
          
          // Bouton navigation GPS
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.blue,
              child: IconButton(
                icon: const Icon(Icons.navigation, color: Colors.white),
                onPressed: _openNavigation,
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
    if (_driverPosition != null) {
        _mapController.move(_driverPosition!, 14);
    }
  }

  Widget _buildBottomPanel() {
    // Récupérer les infos patient directement depuis la table patients
    final patientName = _patientData != null
        ? '${_patientData!['first_name'] ?? ''} ${_patientData!['last_name'] ?? ''}'.trim()
        : 'Patient';
    final patientPhone = _patientData?['emergency_contact_phone'] ?? '';

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
          
          // Status bar avec timer
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
                // Timer affiché
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_elapsedTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Infos patient
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.person, size: 32, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName.isEmpty ? 'Patient' : patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        patientPhone,
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
                    onPressed: _callPatient,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Adresses
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildAddressRow(
                  Icons.radio_button_checked,
                  Colors.green,
                  'Prise en charge',
                  _rideData?['pickup_address'] ?? 'Adresse de départ',
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
                  _rideData?['destination_address'] ?? 'Adresse d\'arrivée',
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
                Text(
                  'Prix estimé',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${_rideData?['estimated_price'] ?? _rideData?['total_price'] ?? '0.00'} MAD',
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
          
          // Boutons d'action selon le statut
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildActionButtons(),
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

  Widget _buildActionButtons() {
    switch (_currentStatus) {
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateRideStatus('arrived'),
            icon: const Icon(Icons.flag, color: Colors.white),
            label: const Text(
              'JE SUIS ARRIVÉ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
        
      case 'arrived':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateRideStatus('in_progress'),
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text(
              'DÉMARRER LA COURSE',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
        
      case 'in_progress':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updateRideStatus('completed'),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text(
              'TERMINER LA COURSE',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
        
      case 'completed':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text(
                'Course terminée',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        );
        
      default:
        return const SizedBox.shrink();
    }
  }
}
