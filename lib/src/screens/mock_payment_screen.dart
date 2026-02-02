import 'package:flutter/material.dart';
import '../services/database_service.dart';

class MockPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;

  const MockPaymentScreen({Key? key, required this.rideData}) : super(key: key);

  @override
  State<MockPaymentScreen> createState() => _MockPaymentScreenState();
}

class _MockPaymentScreenState extends State<MockPaymentScreen> {
  bool _isProcessing = false;
  bool _isSuccess = false;

  Future<void> _processPayment(String method) async {
    setState(() => _isProcessing = true);

    // Simulation délai réseau
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Enregistrer le paiement en base (optionnel pour la démo, mais mieux)
      // On utilise une table 'payments' si elle existe, sinon on ignore
      /*
      await DatabaseService.client.from('payments').insert({
        'ride_id': widget.rideData['id'],
        'amount': widget.rideData['estimated_price'],
        'status': 'completed',
        'method': method,
        'created_at': DateTime.now().toIso8601String(),
      });
      */
    } catch (e) {
      debugPrint('Erreur mockup payment: $e');
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      // Retour accueil après 3 secondes
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Scaffold(
        backgroundColor: Colors.green,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 100),
              const SizedBox(height: 24),
              const Text(
                'Paiement Validé !',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Merci pour votre course.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    final price = widget.rideData['estimated_price'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.verified_user, size: 60, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Récapitulatif de la course',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            _buildRow('Prix de la course', '${price.toStringAsFixed(2)} MAD'),
            _buildRow('Frais de service', '5.00 MAD'),
            const Divider(height: 32),
            _buildRow('TOTAL', '${(price + 5).toStringAsFixed(2)} MAD', isBold: true),
            const Spacer(),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.credit_card),
                label: const Text('Payer par Carte (Simulé)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _processPayment('card'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.money),
                label: const Text('Payer en Espèces'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _processPayment('cash'),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
