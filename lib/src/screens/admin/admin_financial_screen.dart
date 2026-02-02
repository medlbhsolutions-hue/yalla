import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminFinancialScreen extends StatefulWidget {
  const AdminFinancialScreen({Key? key}) : super(key: key);

  @override
  State<AdminFinancialScreen> createState() => _AdminFinancialScreenState();
}

class _AdminFinancialScreenState extends State<AdminFinancialScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _driverDebts = [];
  double _totalPlatformRevenue = 0.0;
  
  static const double COMMISSION_RATE = 0.15; // 15%

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
          // 1. Récupérer toutes les courses terminées avec infos chauffeur
          // Note: On utilise 'drivers' car c'est le nom de la table, pas 'driver_profiles'
          final response = await supabase
          .from('rides')
          .select('final_price, estimated_price, driver_id, drivers(first_name, last_name, phone_number)') 
          .eq('status', 'completed')
          .not('driver_id', 'is', null);

      final List<dynamic> rides = response as List<dynamic>;
      
      // 2. Agréger par chauffeur
      final Map<String, Map<String, dynamic>> driverStats = {};
      double totalRev = 0.0;

      for (var ride in rides) {
        final driverId = ride['driver_id'];
        final price = (ride['final_price'] ?? ride['estimated_price'] ?? 0.0).toDouble();
        final commission = price * COMMISSION_RATE;
        
        if (!driverStats.containsKey(driverId)) {
          final profile = ride['drivers'] ?? {}; // Clé mise à jour
          driverStats[driverId] = {
            'driver_id': driverId,
            'name': '${profile['first_name'] ?? 'Inconnu'} ${profile['last_name'] ?? ''}',
            'phone': profile['phone_number'] ?? 'N/A',
            'total_rides': 0,
            'total_volume': 0.0,
            'total_commission_due': 0.0,
          };
        }
        
        driverStats[driverId]!['total_rides'] += 1;
        driverStats[driverId]!['total_volume'] += price;
        driverStats[driverId]!['total_commission_due'] += commission;
        
        totalRev += commission;
      }

      setState(() {
        _driverDebts = driverStats.values.toList();
        // Trier par dette décroissante (ceux qui doivent le plus en premier)
        _driverDebts.sort((a, b) => b['total_commission_due'].compareTo(a['total_commission_due']));
        _totalPlatformRevenue = totalRev;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Erreur loading finances: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Column(
      children: [
              // HEADER REVENUS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: const Color(0xFF1A237E),
                child: Column(
                  children: [
                    const Text(
                      'REVENUS TOTAUX ESTIMÉS (15%)',
                      style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_totalPlatformRevenue.toStringAsFixed(2)} DH',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // TABLEAU EN-TÊTE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.grey[200],
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Chauffeur', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Courses', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Vol. Affaires', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('À Payer', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                  ],
                ),
              ),

              // LISTE CHAUFFEURS
              Expanded(
                child: ListView.separated(
                  itemCount: _driverDebts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = _driverDebts[index];
                    return ListTile(
                      title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(data['phone']),
                      trailing: SizedBox(
                        width: 200,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 50,
                              child: Text('${data['total_rides']}', textAlign: TextAlign.center),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('${data['total_volume'].toStringAsFixed(0)}', textAlign: TextAlign.right),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${data['total_commission_due'].toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('TODO: Afficher détail ou Marquer payé pour ${data['name']}')),
                         );
                      },
                    );
                  },
                ),
              ),
            ],
          );
  }
}
