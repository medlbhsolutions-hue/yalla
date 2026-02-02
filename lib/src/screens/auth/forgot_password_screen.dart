import 'package:flutter/material.dart';
import '../../services/auth_service_complete.dart';
import '../../utils/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  int _step = 1; // 1: Email, 2: Code & New Password
  bool _isLoading = false;
  String? _userId;

  Future<void> _handleRequestCode() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      _showError('Veuillez entrer un email valide');
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthServiceComplete.forgotPassword(_emailController.text.trim());
    setState(() => _isLoading = false);

    if (result['success']) {
      _showSuccess(result['message']);
      setState(() {
        _userId = result['user_id'];
        _step = 2;
      });
    } else {
      _showError(result['error'] ?? 'Une erreur est survenue');
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final result = await AuthServiceComplete.resetPasswordWithCode(
      userId: _userId!,
      code: _codeController.text.trim(),
      newPassword: _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (result['success']) {
      _showSuccess('Mot de passe réinitialisé ! Vous pouvez vous connecter.');
      Navigator.pop(context);
    } else {
      _showError(result['error'] ?? 'Code invalide ou expiré');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Récupération'), elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _step == 1 ? 'Mot de passe oublié ?' : 'Nouveau mot de passe',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _step == 1 
                ? 'Entrez votre email pour recevoir un code de récupération.'
                : 'Entrez le code reçu par email et votre nouveau mot de passe.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_step == 1) ...[
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRequestCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Envoyer le code', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ] else ...[
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: 'Code de vérification',
                        prefixIcon: const Icon(Icons.lock_clock_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (val) => (val?.length ?? 0) < 6 ? 'Minimum 6 caractères' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Réinitialiser', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
