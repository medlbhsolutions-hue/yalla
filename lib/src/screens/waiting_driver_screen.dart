import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Écran d'attente pendant qu'un chauffeur accepte la course
class WaitingDriverScreen extends StatefulWidget {
  final String rideId;
  
  const WaitingDriverScreen({
    Key? key,
    required this.rideId,
  }) : super(key: key);

  @override
  State<WaitingDriverScreen> createState() => _WaitingDriverScreenState();
}

class _WaitingDriverScreenState extends State<WaitingDriverScreen> {
  Timer? _pollingTimer;
  Map<String, dynamic>? _rideData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// Polling toutes les 5 secondes pour vérifier si un chauffeur a accepté
  void _startPolling() {
    _checkRideStatus(); // Premier check immédiat
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkRideStatus();
    });
  }

  Future<void> _checkRideStatus() async {
    try {
      final ride = await DatabaseService.client
          .from('rides')
          .select('*')
          .eq('id', widget.rideId)
          .single();

      if (!mounted) return;

      setState(() {
        _rideData = ride;
        _isLoading = false;
      });

      // Si un chauffeur a accepté la course
      if (ride['driver_id'] != null) {
        _pollingTimer?.cancel();
        
        // Récupérer les infos du chauffeur
        final driverData = await DatabaseService.client
            .from('drivers')
            .select('''
              *,
              vehicles(*)
            ''')
            .eq('id', ride['driver_id'])
            .single();
        
        // Navigation vers l'écran de suivi de la course
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            '/ride-tracking',
            arguments: {
              ...ride,
              'driver': driverData,
            },
          );
        }
      }
    } catch (e) {
      print('❌ Erreur vérification statut course: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRide() async {
    try {
      await DatabaseService.client
          .from('rides')
          .update({'status': 'cancelled'})
          .eq('id', widget.rideId);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course annulée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur annulation course: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche de chauffeur...'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animation de recherche
                  const SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Titre
                  const Text(
                    '🔍 Recherche d\'un chauffeur disponible',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Message
                  const Text(
                    'Veuillez patienter pendant que nous trouvons un chauffeur près de vous...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  
                  // Détails de la course
                  if (_rideData != null) ...[
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.location_on,
                              'Départ',
                              _rideData!['pickup_address'] ?? 'Position GPS',
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.flag,
                              'Destination',
                              _rideData!['destination_address'] ?? 'N/A',
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.attach_money,
                              'Prix estimé',
                              '${_rideData!['total_price'] ?? '0'} MAD',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  
                  // Bouton d'annulation
                  OutlinedButton.icon(
                    onPressed: _cancelRide,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Annuler la course'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
