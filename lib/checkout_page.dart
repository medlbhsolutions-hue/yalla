import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'stripe_web_view.dart';

final supabase = Supabase.instance.client;

class CheckoutPage extends StatefulWidget {
  final int amount; // en centimes (ex: 2500 = 25,00 €)

  const CheckoutPage({super.key, required this.amount});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final currentUri = Uri.base;
      final baseUrl =
          '${currentUri.scheme}://${currentUri.host}:${currentUri.port}';

      await supabase.functions.invoke(
        'create-checkout',
        body: {
          'amount': widget.amount,
          'success_url': '$baseUrl/#/success',
          'cancel_url': '$baseUrl/#/cancel',
        },
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => StripeWebView(
          amount: widget.amount,
          successUrl: '$baseUrl/#/success',
          cancelUrl: '$baseUrl/#/cancel',
        )),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement sécurisé')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Montant : ${(widget.amount / 100).toStringAsFixed(2)} €'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _pay,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Payer maintenant'),
            ),
          ],
        ),
      ),
    );
  }
}
