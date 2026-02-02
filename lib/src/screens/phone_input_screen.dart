import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/phone_auth_service.dart';
import 'otp_verification_screen.dart';

/// Écran de saisie du numéro de téléphone
class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  const Icon(
                    Icons.local_hospital,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'YALLA L\'TBIB',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Transport Médical Sécurisé',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.sms, color: Colors.white, size: 32),
                        SizedBox(height: 12),
                        Text(
                          'Authentification par SMS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Entrez votre numéro de téléphone\nNous vous enverrons un code de vérification',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Champ Téléphone
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        hintText: '+33669337817 ou +212669337817',
                        prefixIcon: Icon(Icons.phone, color: Color(0xFF4CAF50)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        // Autoriser + et les chiffres uniquement
                        FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Note format
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '�� France: +33669337817\n🇲🇦 Maroc: +212669337817',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Bouton Envoyer SMS
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.sms_outlined),
                                SizedBox(width: 8),
                                Text(
                                  'Envoyer le code SMS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Info sécurité
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.security, color: Colors.white70, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vos données sont sécurisées et protégées',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendOTP() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      _showError('Veuillez entrer votre numéro de téléphone');
      return;
    }
    
    // Valider le format international
    if (!PhoneAuthService.isValidInternationalPhone(phone)) {
      _showError('Format invalide. Utilisez: +33669337817 ou +212669337817');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Formater le numéro au format international
      final formattedPhone = PhoneAuthService.formatPhoneNumber(phone);
      print('📱 Numéro formaté: $formattedPhone');
      
      // Envoyer le code SMS
      await PhoneAuthService.sendOTP(formattedPhone);
      
      if (mounted) {
        // Navigation vers l'écran de vérification
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              phoneNumber: formattedPhone,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Erreur: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
