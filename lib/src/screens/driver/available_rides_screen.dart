import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/database_service.dart';
import '../../services/pricing_service.dart';
import 'active_ride_screen.dart';
import 'dart:async';

/// Écran affichant les courses disponibles pour un chauffeur
class AvailableRidesScreen extends StatefulWidget {
  final Map<String, dynamic>? driverProfile;
  final LatLng? driverLocation;
  
  const AvailableRidesScreen({
    Key? key,
    this.driverProfile,
    this.driverLocation,
  }) : super(key: key);

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  List<Map<String, dynamic>> _availableRides = [];
  bool _isLoading = true;
  StreamSubscription? _ridesSubscription;
  
  String _sortBy = 'distance'; // distance, price, time

  @override
  void initState() {
    super.initState();
    _loadAvailableRides();
    _subscribeToRides();
  }
  
  @override
  void dispose() {
    _ridesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAvailableRides() async {
    setState(() { _isLoading = true; });
    
    try {
      // Récupérer toutes les courses en statut 'pending'
      final response = await DatabaseService.client
          .from('rides')
          .select('''
            *,
            patients:patient_id (
              id,
              first_name,
              last_name,
              emergency_contact_phone
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      
      List<Map<String, dynamic>> rides = List<Map<String, dynamic>>.from(response);
      
      // Calculer la distance depuis la position du chauffeur
      if (widget.driverLocation != null) {
        for (var ride in rides) {
          final pickupLat = ride['pickup_latitude'];
          final pickupLng = ride['pickup_longitude'];
          
          if (pickupLat != null && pickupLng != null) {
            final distance = PricingService.calculateDistance(
              widget.driverLocation!,
              LatLng(pickupLat, pickupLng),
            );
            ride['distance_to_pickup'] = distance;
          } else {
            ride['distance_to_pickup'] = 999.0; // Distance inconnue
          }
        }
      }
      
      setState(() {
        _availableRides = rides;
        _isLoading = false;
      });
      
      _sortRides();
      
    } catch (e) {
      print('❌ Erreur chargement courses: $e');
      setState(() { _isLoading = false; });
    }
  }

  void _subscribeToRides() {
    // Écouter les nouvelles courses en temps réel
    _ridesSubscription = DatabaseService.client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .listen((data) {
          print('🔄 Mise à jour temps réel: ${data.length} courses');
          _loadAvailableRides();
        });
  }

  void _sortRides() {
    setState(() {
      switch (_sortBy) {
        case 'distance':
          _availableRides.sort((a, b) {
            final distA = a['distance_to_pickup'] ?? 999.0;
            final distB = b['distance_to_pickup'] ?? 999.0;
            return distA.compareTo(distB);
          });
          break;
        case 'price':
          _availableRides.sort((a, b) {
            final priceA = a['estimated_price'] ?? 0.0;
            final priceB = b['estimated_price'] ?? 0.0;
            return priceB.compareTo(priceA); // Décroissant
          });
          break;
        case 'time':
          _availableRides.sort((a, b) {
            final timeA = DateTime.parse(a['created_at']);
            final timeB = DateTime.parse(b['created_at']);
            return timeB.compareTo(timeA); // Plus récent en premier
          });
          break;
      }
    });
  }

  Future<void> _acceptRide(Map<String, dynamic> ride) async {
    if (widget.driverProfile == null) {
      _showError('Profil chauffeur introuvable');
      return;
    }
    
    // Confirmer avant d'accepter
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accepter cette course ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${ride['patients']?['first_name'] ?? 'Inconnu'} ${ride['patients']?['last_name'] ?? ''}'),
            const SizedBox(height: 8),
            Text('Prix estimé: ${PricingService.formatPrice(ride['estimated_price'] ?? 0.0)}'),
            const SizedBox(height: 8),
            Text('Distance: ${PricingService.formatDistance(ride['estimated_distance_km'] ?? 0.0)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      // Mettre à jour la course
      await DatabaseService.client
          .from('rides')
          .update({
            'driver_id': widget.driverProfile!['id'],
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ride['id']);
      
      print('✅ Course acceptée: ${ride['id']}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Course acceptée !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Naviguer vers l'écran de suivi actif
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveRideScreen(
              rideId: ride['id'],
              rideData: ride,
            ),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Erreur acceptation course: $e');
      _showError('Erreur lors de l\'acceptation de la course');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses Disponibles', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF4CAF50)),
        actions: [
          // Bouton de tri
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _sortRides();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'distance',
                child: Row(
                  children: [
                    Icon(Icons.near_me, size: 20),
                    SizedBox(width: 8),
                    Text('Trier par distance'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'price',
                child: Row(
                  children: [
                    Icon(Icons.attach_money, size: 20),
                    SizedBox(width: 8),
                    Text('Trier par prix'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'time',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 20),
                    SizedBox(width: 8),
                    Text('Trier par date'),
                  ],
                ),
              ),
            ],
          ),
          
          // Bouton rafraîchir
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableRides,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text('Chargement des courses...'),
                ],
              ),
            )
          : _availableRides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune course disponible',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Les nouvelles courses apparaîtront ici',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAvailableRides,
                  color: const Color(0xFF4CAF50),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableRides.length,
                    itemBuilder: (context, index) {
                      final ride = _availableRides[index];
                      return _buildRideCard(ride);
                    },
                  ),
                ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final patient = ride['patients'];
    final patientName = patient != null
        ? '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim()
        : 'Patient inconnu';
    
    final distanceToPickup = ride['distance_to_pickup'] as double?;
    final estimatedPrice = ride['estimated_price'] as double? ?? 0.0;
    final estimatedDistance = ride['estimated_distance_km'] as double? ?? 0.0;
    final estimatedDuration = ride['estimated_duration_minutes'] as int? ?? 0;
    final rideType = ride['ride_type'] as String? ?? 'standard';
    final isUrgent = rideType == 'urgent' || ride['priority_level'] == 'urgent';
    
    final createdAt = DateTime.parse(ride['created_at']);
    final minutesAgo = DateTime.now().difference(createdAt).inMinutes;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUrgent
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                // Avatar patient
                CircleAvatar(
                  backgroundColor: const Color(0xFF4CAF50),
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Nom et temps
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Il y a $minutesAgo min',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                // Badge urgent
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'URGENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const Divider(height: 24),
            
            // Détails de la course
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.near_me,
                    'Distance pickup',
                    distanceToPickup != null
                        ? PricingService.formatDistance(distanceToPickup)
                        : 'N/A',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.route,
                    'Distance totale',
                    PricingService.formatDistance(estimatedDistance),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.timer,
                    'Durée estimée',
                    PricingService.formatDuration(estimatedDuration),
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.attach_money,
                    'Prix estimé',
                    PricingService.formatPrice(estimatedPrice),
                    valueColor: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            
            // Notes si présentes
            if (ride['notes'] != null && ride['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride['notes'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Bouton Accepter
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _acceptRide(ride),
                icon: const Icon(Icons.check_circle),
                label: const Text('Accepter cette course'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}
