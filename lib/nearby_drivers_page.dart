import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'stripe_web_view.dart';

final supabase = Supabase.instance.client;

class NearbyDriversPage extends StatefulWidget {
  const NearbyDriversPage({super.key});

  @override
  State<NearbyDriversPage> createState() => _NearbyDriversPageState();
}

class _NearbyDriversPageState extends State<NearbyDriversPage> {
  List<dynamic> drivers = [];
  bool loading = false;

  // Position fictive (Paris place de la République) pour la démo
  final double lat = 48.867222;
  final double lon = 2.362778;

  Future<void> _loadNearest() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final res = await supabase.rpc(
        'get_nearest_driver',
        params: {'lat': lat, 'lon': lon},
      );
      if (!mounted) return;
      setState(() => drivers = res is List ? res : [res]);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chauffeurs à proximité')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.location_searching),
              label: const Text('Trouver le plus proche'),
              onPressed: loading ? null : _loadNearest,
            ),
            const SizedBox(height: 20),
            if (loading) const CircularProgressIndicator(),
            if (drivers.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: drivers.length,
                  itemBuilder: (_, i) {
                    final d = drivers[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.taxi_alert),
                        title: Text('${d['nom']} ${d['prenom']}'),
                        subtitle: Text(d['vehicule_type']),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle),
                          tooltip: 'Assigner',
                          onPressed: () => _assignDriver(d['id']),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!loading && drivers.isEmpty)
              const Text('Aucun chauffeur disponible.'),
          ],
        ),
      ),
    );
  }

  Future<void> _assignDriver(String driverId) async {
    if (!mounted) return;
    final currentUri = Uri.base;
    final baseUrl =
        '${currentUri.scheme}://${currentUri.host}:${currentUri.port}';

    try {
      await supabase.functions.invoke(
        'create-checkout',
        body: {
          'amount': 2500,
          'success_url': '$baseUrl/#/success',
          'cancel_url': '$baseUrl/#/cancel',
        },
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StripeWebView(
          amount: 2500,
          successUrl: '$baseUrl/#/success',
          cancelUrl: '$baseUrl/#/cancel',
        )),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
  }
}
