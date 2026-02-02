import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yalla_tbib_flutter/src/services/stripe_payment_service.dart';

/// Ouvre Stripe Checkout dans un nouvel onglet et revient automatiquement
class StripeWebView extends StatefulWidget {
  final int amount;
  final String? successUrl;
  final String? cancelUrl;

  const StripeWebView({
    required this.amount,
    this.successUrl,
    this.cancelUrl,
    super.key,
  });

  @override
  State<StripeWebView> createState() => _StripeWebViewState();
}

class _StripeWebViewState extends State<StripeWebView> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createAndLaunchCheckout();
  }

  String _getRedirectUrl(String path) {
    // En mode développement, utilisez le schéma yallatbib://
    // En production, utilisez https://yallatbib.com/
    const isProduction = bool.fromEnvironment('dart.vm.product');
    return isProduction ? 'https://yallatbib.com$path' : 'yallatbib://$path';
  }

  Future<void> _createAndLaunchCheckout() async {
    if (!mounted) return;

    try {
      final service = StripePaymentService(Supabase.instance.client);
      final checkoutUrl = await service.createCheckoutSession(
        amount: widget.amount,
        successUrl: widget.successUrl ?? _getRedirectUrl('/payment/success'),
        cancelUrl: widget.cancelUrl ?? _getRedirectUrl('/payment/cancel'),
      );

      if (!mounted) return;

      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (!mounted) return;
          setState(() {
            _error = "Impossible d'ouvrir le lien de paiement";
            _isLoading = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error = "URL de paiement invalide";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Erreur de paiement détaillée: $e');

      String errorMessage =
          'Une erreur est survenue lors de la création du paiement.';
      if (e.toString().contains(
        'La clé secrète Stripe n\'est pas configurée',
      )) {
        errorMessage = 'Erreur de configuration Stripe. Contactez le support.';
      } else if (e.toString().contains('connection to Stripe')) {
        errorMessage =
            'Impossible de se connecter à Stripe. Vérifiez votre connexion internet.';
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paiement sécurisé")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _createAndLaunchCheckout(),
                    child: const Text("Réessayer"),
                  ),
                ],
              )
            : const Text(
                "Tu vas être redirigé vers Stripe.\n"
                "Reviens ici après le paiement.",
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
