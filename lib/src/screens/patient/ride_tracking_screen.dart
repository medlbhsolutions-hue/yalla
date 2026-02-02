import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Écran de suivi de course en temps réel
class RideTrackingScreen extends StatefulWidget {
  final String rideId;

  const RideTrackingScreen({super.key, required this.rideId});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final _supabase = Supabase.instance.client;
  
  Map<String, dynamic>? _rideData;
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  
  RealtimeChannel? _rideChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadRideData();
    _subscribeToRideUpdates();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _rideChannel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRideData() async {
    setState(() => _isLoading = true);

    try {
      // Charger les données de la course
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
              vehicle:vehicles(make, model, plate_number, color)
            )
          ''')
          .eq('id', widget.rideId)
          .single();

      if (mounted) {
        setState(() {
          _rideData = response;
          _driverData = response['driver'];
        });
      }
    } catch (e) {
      print('❌ Erreur chargement course: $e');
      _showError('Erreur lors du chargement de la course');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToRideUpdates() {
    _rideChannel = _supabase
        .channel('ride_${widget.rideId}')
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
            print('🔄 Mise à jour course: ${payload.newRecord}');
            _loadRideData();
          },
        )
        .subscribe();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadRideData();
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
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
            child: const Text('Oui', style: TextStyle(color: Colors.red)),
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
      _showError('Erreur lors de l\'annulation');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4CAF50),
          ),
        ),
      );
    }

    if (_rideData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Course introuvable'),
        ),
        body: const Center(
          child: Text('Cette course n\'existe pas'),
        ),
      );
    }

    final status = _rideData!['status'];
    final driverInfo = _driverData;
    final vehicle = _driverData?['vehicle'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        title: const Text('Suivi de course'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Statut de la course
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStatusIcon(status),
                const SizedBox(height: 12),
                Text(
                  _getStatusText(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStatusDescription(status),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informations du chauffeur
                  if (driverInfo != null) ...[
                    const Text(
                      'Votre chauffeur',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFF4CAF50),
                            child: Text(
                              (driverInfo['first_name'] ?? 'C')[0],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
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
                                  '${driverInfo['first_name'] ?? ''} ${driverInfo['last_name'] ?? ''}'.trim(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (vehicle != null)
                                  Text(
                                    '${vehicle['make']} ${vehicle['model']} • ${vehicle['plate_number']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              // Appeler le chauffeur
                            },
                            icon: const Icon(
                              Icons.phone,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Détails de la course
                  const Text(
                    'Détails de la course',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.my_location,
                    'Départ',
                    _rideData!['pickup_address'] ?? 'Non spécifié',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.location_on,
                    'Destination',
                    _rideData!['destination_address'] ?? 'Non spécifié',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.local_taxi,
                    'Type de véhicule',
                    _rideData!['vehicle_type'] ?? 'Taxi',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.attach_money,
                    'Prix',
                    '${_rideData!['estimated_price']} MAD',
                  ),
                  
                  if (_rideData!['notes'] != null && _rideData!['notes'].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.note,
                      'Notes',
                      _rideData!['notes'],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Timeline
                  const Text(
                    'Progression',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTimeline(status),
                ],
              ),
            ),
          ),

          // Boutons d'action
          if (status == 'pending' || status == 'accepted')
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _cancelRide,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Annuler la course',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    
    switch (status) {
      case 'pending':
        icon = Icons.hourglass_empty;
        break;
      case 'accepted':
        icon = Icons.check_circle;
        break;
      case 'in_progress':
        icon = Icons.local_taxi;
        break;
      case 'completed':
        icon = Icons.done_all;
        break;
      case 'cancelled':
        icon = Icons.cancel;
        break;
      default:
        icon = Icons.help;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: Colors.white),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Recherche en cours';
      case 'accepted':
        return 'Chauffeur trouvé !';
      case 'in_progress':
        return 'En route';
      case 'completed':
        return 'Course terminée';
      case 'cancelled':
        return 'Course annulée';
      default:
        return status;
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'Nous recherchons un chauffeur disponible...';
      case 'accepted':
        return 'Le chauffeur arrive à votre position';
      case 'in_progress':
        return 'Vous êtes en route vers votre destination';
      case 'completed':
        return 'Merci d\'avoir utilisé YALLA L\'TBIB';
      case 'cancelled':
        return 'Cette course a été annulée';
      default:
        return '';
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4CAF50)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(String currentStatus) {
    final steps = [
      {'status': 'pending', 'label': 'Demande créée'},
      {'status': 'accepted', 'label': 'Chauffeur accepté'},
      {'status': 'in_progress', 'label': 'En route'},
      {'status': 'completed', 'label': 'Terminée'},
    ];

    final currentIndex = steps.indexWhere((s) => s['status'] == currentStatus);

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isCompleted = index <= currentIndex;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF4CAF50) : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? const Color(0xFF4CAF50) : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  step['label']!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                    color: isCompleted ? Colors.black87 : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
