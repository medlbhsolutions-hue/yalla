import 'package:flutter/material.dart';

/// 🎨 Charte graphique Yalla Tbib
/// Couleurs officielles de l'application
class AppColors {
  // Couleur principale Yalla Tbib
  static const Color primary = Color(0xFF467DB0); // Bleu principal #467db0
  
  // Variantes du bleu principal
  static const Color primaryLight = Color(0xFF6B9FCF);
  static const Color primaryDark = Color(0xFF2E5A8A);
  
  // Couleurs complémentaires (du logo)
  static const Color green = Color(0xFF7EC845); // Vert du logo
  static const Color greenDark = Color(0xFF4A9B2E);
  
  // Couleurs système
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Couleurs de fond
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFAFAFA);
  
  // Couleurs de texte
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // Couleurs spécifiques
  static const Color patientColor = primary; // Bleu pour patient
  static const Color driverColor = Color(0xFF2E5A8A); // Bleu foncé pour chauffeur
  static const Color urgentColor = Color(0xFFE53935); // Rouge pour urgent
  static const Color nonUrgentColor = primary; // Bleu pour non-urgent
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green, greenDark],
  );

  // --- NOUVELLES COULEURS PREMIUM (TECH & GLOW) ---
  static const Color darkBg = Color(0xFF041C1B); // Fond sombre (vert très foncé)
  static const Color accentGlow = Color(0xFF4AC2B2); // Cyan brillant
  static const Color glassWhite = Color(0x1AFFFFFF); // Blanc givré pour glassmorphism
  
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D504E), Color(0xFF041C1B)],
  );
  
  static const LinearGradient glowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4AC2B2), Color(0xFF0D504E)],
  );
}
