import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class PatientRideTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const PatientRideTrackingScreen({
    super.key,
    required this.bookingData,
  });

  @override
  State<PatientRideTrackingScreen> createState() => _PatientRideTrackingScreenState();
}

class _PatientRideTrackingScreenState extends State<PatientRideTrackingScreen> {
  Timer? _trackingTimer;
  String _currentStatus = 'driver_en_route';
  int _estimatedArrival = 15; // minutes

  double _progress = 0.0;
  
  final List<Map<String, dynamic>> _statusUpdates = [];

  final Map<String, Map<String, dynamic>> _statusConfig = {
    'driver_en_route': {
      'icon': '🚗',
      'title': 'Chauffeur en route',
      'description': 'Le chauffeur se dirige vers vous',
      'color': Colors.blue,
    },
    'driver_arrived': {
      'icon': '📍',
      'title': 'Chauffeur arrivé',
      'description': 'Le chauffeur est à votre position',
      'color': Colors.green,
    },
    'patient_picked_up': {
      'icon': '🚑',
      'title': 'Patient pris en charge',
      'description': 'Transport vers la destination',
      'color': Colors.orange,
    },
    'en_route_destination': {
      'icon': '🏥',
      'title': 'En route vers l\'hôpital',
      'description': 'Transport en cours',
      'color': Colors.purple,
    },
    'arrived_destination': {
      'icon': '✅',
      'title': 'Arrivé à destination',
      'description': 'Transport terminé avec succès',
      'color': Colors.green,
    },
  };

  @override
  void initState() {
    super.initState();
    _startTracking();
    _addStatusUpdate('Réservation confirmée', 'Chauffeur assigné: ${widget.bookingData['driver_name']}');
  }

  @override
  Widget build(BuildContext context) {
    final currentConfig = _statusConfig[_currentStatus]!;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: currentConfig['color'],
        elevation: 0,
        title: Text(
          '🚑 Suivi en temps réel',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: _callDriver,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // En-tête de statut
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [currentConfig['color'].withOpacity(0.1), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  // Icône de statut
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: currentConfig['color'],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        currentConfig['icon'],
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Titre du statut
                  Text(
                    currentConfig['title'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    currentConfig['description'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Temps d'arrivée estimé
                  if (_currentStatus != 'arrived_destination') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: currentConfig['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: currentConfig['color']),
                      ),
                      child: Text(
                        _currentStatus == 'driver_en_route'
                            ? '⏰ Arrivée dans $_estimatedArrival min'
                            : _currentStatus == 'patient_picked_up'
                                ? '🏥 Arrivée à l\'hôpital dans $_estimatedArrival min'
                                : 'En cours...',
                        style: TextStyle(
                          color: currentConfig['color'],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Barre de progression
            Container(
              margin: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 Progression du transport',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(currentConfig['color']),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).toInt()}% complété',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Informations du chauffeur
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '👨‍⚕️ Votre chauffeur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green.shade100,
                        child: Text(
                          widget.bookingData['driver_name']?.substring(0, 1) ?? 'A',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bookingData['driver_name'] ?? 'Ahmed Benali',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '🚑 ${widget.bookingData['vehicle_number'] ?? 'A-123-456'}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '⭐ 4.8/5 • 1,250 courses',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: _callDriver,
                            icon: const Icon(Icons.phone),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const Text(
                            'Appeler',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Historique des mises à jour
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 Historique du transport',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _statusUpdates.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          final update = _statusUpdates[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        update['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (update['description'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          update['description'],
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  update['time'],
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Boutons d'action
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_currentStatus == 'arrived_destination') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _completeRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '✅ CONFIRMER LA FIN DU TRANSPORT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _emergencyCall,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '🚨 Urgence',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _callDriver,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '📞 Appeler',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
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

  void _startTracking() {
    _trackingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        // Simuler la progression
        switch (_currentStatus) {
          case 'driver_en_route':
            _estimatedArrival = max(1, _estimatedArrival - 1);
            _progress = min(0.25, _progress + 0.02);
            if (_estimatedArrival <= 2) {
              _currentStatus = 'driver_arrived';
              _addStatusUpdate('Chauffeur arrivé', 'Le chauffeur est à votre position');
              _progress = 0.25;
            }
            break;
            
          case 'driver_arrived':
            _progress = min(0.5, _progress + 0.05);
            if (_progress >= 0.45) {
              _currentStatus = 'patient_picked_up';
              _addStatusUpdate('Patient pris en charge', 'Transport vers l\'hôpital commencé');
              _estimatedArrival = 20;
              _progress = 0.5;
            }
            break;
            
          case 'patient_picked_up':
            _estimatedArrival = max(1, _estimatedArrival - 1);
            _progress = min(0.75, _progress + 0.02);
            if (_estimatedArrival <= 5) {
              _currentStatus = 'en_route_destination';
              _addStatusUpdate('Bientôt arrivé', 'Arrivée à l\'hôpital dans quelques minutes');
              _progress = 0.75;
            }
            break;
            
          case 'en_route_destination':
            _progress = min(1.0, _progress + 0.05);
            if (_progress >= 1.0) {
              _currentStatus = 'arrived_destination';
              _addStatusUpdate('Arrivé à destination', 'Transport terminé avec succès');
              _progress = 1.0;
              timer.cancel();
            }
            break;
        }
      });
    });
  }

  void _addStatusUpdate(String title, [String? description]) {
    setState(() {
      _statusUpdates.add({
        'title': title,
        'description': description,
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      });
    });
  }

  void _callDriver() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📞 Appeler le chauffeur'),
        content: Text('Appel vers ${widget.bookingData['driver_phone'] ?? '+212 6 11 22 33 44'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Simuler l'appel
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📞 Appel en cours...'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Appeler'),
          ),
        ],
      ),
    );
  }

  void _emergencyCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Appel d\'urgence'),
        content: const Text('Souhaitez-vous appeler les services d\'urgence (141) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 Appel d\'urgence: 141'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Appeler 141', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _completeRide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Transport terminé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Évaluez votre expérience:'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.star,
                    color: index < 5 ? Colors.amber : Colors.grey,
                    size: 32,
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/patient_dashboard');
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }
}