import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// Page affichée après un paiement réussi
/// Exemple d'url : http://localhost:XXXX/#/success
class SuccessPage extends StatefulWidget {
  const SuccessPage({super.key});

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _markAsPaid();
  }

  /// Marque la dernière course du patient comme "payée"
  Future<void> _markAsPaid() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Non connecté';

      // On prend la dernière course en statut "en_attente"
      final res = await supabase
          .from('courses')
          .select('id')
          .eq('patient_id', user.id)
          .eq('statut', 'en_attente')
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      await supabase
          .from('courses')
          .update({'statut': 'payee'})
          .eq('id', res['id']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement réussi')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Merci ! Votre paiement a été accepté.',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    ),
                    child: const Text('Retour à l’accueil'),
                  ),
                ],
              ),
      ),
    );
  }
}
