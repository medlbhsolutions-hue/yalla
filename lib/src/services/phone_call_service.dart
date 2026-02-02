import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 📞 Service pour gérer les appels téléphoniques
class PhoneCallService {
  /// Appeler un numéro de téléphone
  static Future<bool> call(String phoneNumber, {BuildContext? context}) async {
    // Nettoyer le numéro
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanNumber.isEmpty) {
      _showError(context, 'Numéro de téléphone invalide');
      return false;
    }
    
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        final result = await launchUrl(phoneUri);
        if (!result && context != null) {
          _showError(context, 'Impossible de lancer l\'appel');
        }
        return result;
      } else {
        _showError(context, 'Appel non supporté sur cet appareil');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur appel téléphonique: $e');
      _showError(context, 'Erreur lors de l\'appel: $e');
      return false;
    }
  }

  /// Envoyer un SMS
  static Future<bool> sendSms(String phoneNumber, {String? message, BuildContext? context}) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanNumber.isEmpty) {
      _showError(context, 'Numéro de téléphone invalide');
      return false;
    }
    
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: cleanNumber,
      queryParameters: message != null ? {'body': message} : null,
    );
    
    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri);
      } else {
        _showError(context, 'SMS non supporté sur cet appareil');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur envoi SMS: $e');
      _showError(context, 'Erreur lors de l\'envoi du SMS');
      return false;
    }
  }

  /// Ouvrir WhatsApp avec un numéro
  static Future<bool> openWhatsApp(String phoneNumber, {String? message, BuildContext? context}) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Ajouter +212 si le numéro commence par 0
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '+212${cleanNumber.substring(1)}';
    } else if (!cleanNumber.startsWith('+')) {
      cleanNumber = '+212$cleanNumber';
    }
    
    final String url = message != null
        ? 'https://wa.me/$cleanNumber?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/$cleanNumber';
    
    final Uri whatsappUri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(whatsappUri)) {
        return await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        _showError(context, 'WhatsApp n\'est pas installé');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur WhatsApp: $e');
      _showError(context, 'Erreur lors de l\'ouverture de WhatsApp');
      return false;
    }
  }

  /// Afficher un dialogue de confirmation avant l'appel
  static Future<void> showCallDialog({
    required BuildContext context,
    required String phoneNumber,
    required String contactName,
    String? role, // 'patient' ou 'chauffeur'
  }) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Appeler', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              contactName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (role != null)
              Text(
                role == 'patient' ? 'Patient' : 'Chauffeur',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                phoneNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bouton WhatsApp
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  openWhatsApp(phoneNumber, context: context);
                },
                icon: const Icon(Icons.message, color: Colors.green),
                tooltip: 'WhatsApp',
              ),
              // Bouton SMS
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  sendSms(phoneNumber, context: context);
                },
                icon: const Icon(Icons.sms, color: Colors.blue),
                tooltip: 'SMS',
              ),
              // Bouton Appel
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  call(phoneNumber, context: context);
                },
                icon: const Icon(Icons.phone, size: 18),
                label: const Text('Appeler'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Affiche une erreur
  static void _showError(BuildContext? context, String message) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
    debugPrint('⚠️ $message');
  }
}
