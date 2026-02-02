import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/phone_auth_service.dart';
import 'onboarding_screens.dart';

/// Écran de vérification du code OTP reçu par SMS
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  
  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  bool _isLoading = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                  // Icône SMS
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.message,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Titre
                  const Text(
                    'Code de Vérification',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Instructions
                  Text(
                    'Nous avons envoyé un code SMS à\n${widget.phoneNumber}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Champs OTP (6 chiffres)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 5) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                              
                              // Auto-vérifier si tous les champs sont remplis
                              if (index == 5 && value.isNotEmpty) {
                                _verifyOTP();
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Bouton Vérifier
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
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
                          : const Text(
                              'Vérifier le code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Renvoyer le code
                  if (_countdown > 0)
                    Text(
                      'Renvoyer le code dans $_countdown secondes',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _resendOTP,
                      child: const Text(
                        'Renvoyer le code',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
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

  void _verifyOTP() async {
    // Récupérer le code complet
    final otpCode = _otpControllers.map((c) => c.text).join();
    
    if (otpCode.length != 6) {
      _showError('Veuillez entrer le code à 6 chiffres');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      print('🔐 Vérification du code: $otpCode');
      
      // Vérifier le code OTP
      final response = await PhoneAuthService.verifyOTP(
        phoneNumber: widget.phoneNumber,
        otpCode: otpCode,
      );
      
      if (response.session != null && mounted) {
        // Authentification réussie !
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Téléphone vérifié avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigation vers l'onboarding
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OnboardingScreen(),
            ),
          );
        }
      }
    } catch (e) {
      // MODE SIMULATION : Gestion spéciale de l'exception
      if (e.toString().contains('MODE_SIMULATION_SUCCESS')) {
        // Extraire le numéro de téléphone de l'exception
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🧪 Mode Simulation - Authentification réussie !'),
              backgroundColor: Colors.orange,
            ),
          );
          
          // Navigation vers l'onboarding
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen(),
              ),
            );
          }
        }
        return;
      }
      
      // MODE FIREBASE PRODUCTION : Gestion de l'exception Firebase
      if (e.toString().contains('MODE_FIREBASE_SUCCESS')) {
        // Extraire les infos: MODE_FIREBASE_SUCCESS:+212669337817:firebase_uid_123
        final parts = e.toString().split(':');
        if (parts.length >= 3 && mounted) {
          final phoneNumber = parts[1];
          final firebaseUid = parts[2];
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔥 Authentification Firebase réussie !'),
              backgroundColor: Colors.green,
            ),
          );
          
          print('🔥 Firebase UID: $firebaseUid');
          print('📱 Téléphone: $phoneNumber');
          
          // Navigation vers l'onboarding
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen(),
              ),
            );
          }
        }
        return;
      }
      
      // Erreur normale
      if (mounted) {
        _showError('Code invalide ou expiré. Veuillez réessayer.');
        // Effacer les champs
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resendOTP() async {
    try {
      await PhoneAuthService.sendOTP(widget.phoneNumber);
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 Code SMS renvoyé'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Erreur lors de l\'envoi du code');
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
