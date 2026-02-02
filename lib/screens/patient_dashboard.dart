import 'package:flutter/material.dart';
import '../screens/map_screen.dart';
import '../screens/ride_tracking_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({Key? key}) : super(key: key);

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  bool _hasActiveRide = false;
  
  // Données de course active (simulation)
  String _activeRideId = '';
  String _driverName = '';
  String _destination = '';
  double _destinationLat = 0.0;
  double _destinationLng = 0.0;

  // Historique récent
  List<Map<String, dynamic>> _recentRides = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  void _loadPatientData() {
    // Simulation de l'historique - en production, ces données viendraient d'une API
    setState(() {
      _recentRides = [
        {
          'id': 'R001',
          'date': '28 Sept 2025',
          'destination': 'Hôpital Ibn Sina',
          'driver': 'Mohamed Alami',
          'status': 'Terminée',
          'amount': '65 DH',
        },
        {
          'id': 'R002',
          'date': '25 Sept 2025',
          'destination': 'Clinique Atlas',
          'driver': 'Fatima Zahra',
          'status': 'Terminée',
          'amount': '45 DH',
        },
        {
          'id': 'R003',
          'date': '22 Sept 2025',
          'destination': 'Centre de Radiologie',
          'driver': 'Youssef Benali',
          'status': 'Terminée',
          'amount': '38 DH',
        },
      ];
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openMapView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapScreen(),
      ),
    );
  }

  void _requestMedicalTransport() {
    _showDestinationDialog();
  }

  void _showDestinationDialog() {
    final destinationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demande de Transport Médical'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Où souhaitez-vous aller ?'),
            const SizedBox(height: 16),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Ex: Hôpital Mohammed V, Rabat',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_hospital),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type de transport:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Urgence'),
                    value: 'urgence',
                    groupValue: 'normal',
                    onChanged: (value) {},
                    dense: true,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Normal'),
                    value: 'normal',
                    groupValue: 'normal',
                    onChanged: (value) {},
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _simulateRideBooking(destinationController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Réserver', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _simulateRideBooking(String destination) {
    if (destination.isEmpty) {
      _showSnackBar('Veuillez entrer une destination');
      return;
    }

    // Simulation de la réservation
    setState(() {
      _hasActiveRide = true;
      _activeRideId = 'R${DateTime.now().millisecondsSinceEpoch}';
      _driverName = 'Hassan Benjelloun';
      _destination = destination;
      _destinationLat = 34.0209;
      _destinationLng = -6.8416;
    });

    _showRideConfirmation();
  }

  void _showRideConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Course Confirmée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Numéro de course: $_activeRideId'),
            Text('Chauffeur: $_driverName'),
            Text('Destination: $_destination'),
            const SizedBox(height: 8),
            Text('Temps d\'attente estimé: 8 minutes'),
            Text('Prix estimé: 70 DH'),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le chauffeur arrive à votre position actuelle',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelRide();
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startRideTracking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Suivre', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startRideTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideTrackingScreen(
          rideId: _activeRideId,
          patientName: 'Vous',
          destination: _destination,
          destinationLat: _destinationLat,
          destinationLng: _destinationLng,
          isDriver: false,
        ),
      ),
    ).then((value) {
      // Retour du suivi de course
      setState(() {
        _hasActiveRide = false;
        // Ajouter à l'historique
        _recentRides.insert(0, {
          'id': _activeRideId,
          'date': _formatDate(DateTime.now()),
          'destination': _destination,
          'driver': _driverName,
          'status': 'Terminée',
          'amount': '70 DH',
        });
      });
    });
  }

  void _cancelRide() {
    setState(() {
      _hasActiveRide = false;
    });
    _showSnackBar('Course annulée');
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YALLA L\'TBIB - Patient'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message de bienvenue
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.medical_services, color: Colors.white, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transport Médical Fiable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Disponible 24h/24 pour vos besoins médicaux',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Actions principales
            const Text(
              'Services Disponibles',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildServiceCard(
                    'Transport\nMédical',
                    Icons.local_taxi,
                    const Color(0xFF2E7D32),
                    _requestMedicalTransport,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildServiceCard(
                    'Voir la\nCarte',
                    Icons.map,
                    const Color(0xFF2196F3),
                    _openMapView,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildServiceCard(
                    'Pharmacie\nLivraison',
                    Icons.local_pharmacy,
                    const Color(0xFFFF9800),
                    () => _showSnackBar('Service en développement'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildServiceCard(
                    'Urgences\n24h/24',
                    Icons.emergency,
                    const Color(0xFFF44336),
                    () => _showSnackBar('Service d\'urgence en développement'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Course active
            if (_hasActiveRide)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.directions_car, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Course en cours',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Numéro: $_activeRideId'),
                    Text('Chauffeur: $_driverName'),
                    Text('Destination: $_destination'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _startRideTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text(
                        'Suivre la Course',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            if (_hasActiveRide) const SizedBox(height: 24),

            // Historique des courses
            const Text(
              'Historique Récent',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_recentRides.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Aucune course récente',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...(_recentRides.take(3).map((ride) => _buildRideHistoryCard(ride))),

            if (_recentRides.length > 3)
              TextButton(
                onPressed: () => _showSnackBar('Historique complet en développement'),
                child: const Text('Voir tout l\'historique'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideHistoryCard(Map<String, dynamic> ride) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_taxi,
              color: Color(0xFF2E7D32),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride['destination'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${ride['date']} • ${ride['driver']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ride['amount'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ride['status'],
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}