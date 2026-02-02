import 'package:flutter/material.dart';
import 'src/services/database_service.dart';
import 'src/screens/onboarding_screens.dart'; // 🎨 NOUVEAU : Onboarding
import 'src/screens/available_drivers_screen.dart';
import 'src/screens/patient/new_ride_screen.dart'; // 🚀 VERSION MODERNE avec sélecteur véhicules

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({Key? key}) : super(key: key);

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  Map<String, dynamic>? _patientProfile;
  bool _isLoadingProfile = true;
  String _userName = 'Patient';
  String _userPhone = '';
  List<Map<String, dynamic>> _recentRides = [];
  bool _isLoadingRides = false;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() { _isLoadingProfile = true; });
    try {
      final profile = await DatabaseService.getPatientProfile();
      if (profile != null) {
        setState(() {
          _patientProfile = profile;
          _userName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
          if (_userName.isEmpty) _userName = 'Patient';
          _userPhone = profile['emergency_contact_phone'] ?? '+212 6XX XXX XXX';
          _isLoadingProfile = false;
        });
        await _loadRecentRides();
      } else {
        setState(() {
          _userName = 'Patient YALLA L\'TBIB';
          _userPhone = '+212 6XX XXX XXX';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        _userName = 'Patient';
        _userPhone = '+212 6XX XXX XXX';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadRecentRides() async {
    if (_patientProfile == null) return;
    setState(() { _isLoadingRides = true; });
    try {
      final rides = await DatabaseService.getPatientRides(
        patientId: _patientProfile!['id'],
        limit: 5,
      );
      setState(() {
        _recentRides = rides;
        _isLoadingRides = false;
      });
    } catch (e) {
      setState(() { _isLoadingRides = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Color(0xFF4CAF50)),
              SizedBox(height: 16),
              Text('Chargement...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF4CAF50)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text('Bonjour $_userName !', style: const TextStyle(color: Colors.black)),
      ),
      drawer: _buildSidebar(context),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Message de bienvenue
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Besoin d\'un transport médical ?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trouvez un chauffeur disponible près de vous',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 🚀 PHASE 2.5: Bouton principal - Nouvelle Course
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewRideScreen(patientProfile: _patientProfile),
                  ),
                );
                
                // Rafraîchir l'historique si une course a été créée
                if (result == true) {
                  _loadRecentRides();
                }
              },
              icon: const Icon(Icons.add_circle_outline, size: 28),
              label: const Text(
                'Nouvelle Course',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Bouton secondaire - Voir les chauffeurs
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AvailableDriversScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.local_taxi, size: 24),
              label: const Text(
                'Voir les chauffeurs disponibles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Statistiques rapides
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.person,
                    label: 'Chauffeurs actifs',
                    value: '25+',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.star,
                    label: 'Note moyenne',
                    value: '4.8',
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section historique
            const Text(
              'Courses récentes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Expanded(
              child: _recentRides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune course récente',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _recentRides.length,
                      itemBuilder: (context, index) {
                        final ride = _recentRides[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF4CAF50),
                              child: Icon(Icons.local_taxi, color: Colors.white),
                            ),
                            title: Text(ride['destination_address'] ?? 'Destination'),
                            subtitle: Text(ride['created_at'] ?? 'Date'),
                            trailing: Text(
                              '${ride['total_price'] ?? 0} DH',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF4CAF50)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Color(0xFF4CAF50)),
                ),
                const SizedBox(height: 12),
                Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(_userPhone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Color(0xFF4CAF50)),
            title: const Text('Accueil'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
