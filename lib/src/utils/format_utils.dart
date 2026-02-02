/// Utilitaires de formatage pour l'application YALLA L'TBIB
/// Date : 14 octobre 2025

/// Formate une durée en format lisible et professionnel
/// 
/// Gère automatiquement la détection entre millisecondes et minutes
/// et retourne un format adapté (min, h min, ou HH:MM:SS)
/// 
/// Paramètres:
/// - [duration] : La durée à formater (peut être int, double, ou String)
/// - [showSeconds] : Afficher les secondes (pour chronomètre en temps réel)
/// 
/// Exemples:
/// ```dart
/// formatDuration(15) → "15 min"
/// formatDuration(90) → "1h 30min"
/// formatDuration(15000) → "15 min" (détection automatique millisecondes)
/// formatDuration(3665, showSeconds: true) → "01:01:05"
/// ```
String formatDuration(dynamic duration, {bool showSeconds = false}) {
  if (duration == null) return '0 min';
  
  try {
    int durationValue;
    
    // Conversion en int
    if (duration is Duration) {
      durationValue = duration.inMinutes;
    } else if (duration is num) {
      durationValue = duration.toInt();
    } else {
      durationValue = int.parse(duration.toString());
    }
    
    // Détection automatique : millisecondes vs minutes
    // Si > 5000, c'est probablement en millisecondes (> 5 secondes)
    if (durationValue > 5000) {
      // Conversion millisecondes → minutes
      durationValue = (durationValue / 60000).round();
    }
    
    // Si showSeconds = true, retourner format HH:MM:SS
    if (showSeconds) {
      final hours = durationValue ~/ 60;
      final minutes = durationValue % 60;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
    }
    
    // Format standard : "X min" ou "Xh Ymin"
    if (durationValue >= 60) {
      final hours = durationValue ~/ 60;
      final mins = durationValue % 60;
      if (mins == 0) {
        return '${hours}h';
      }
      return '${hours}h ${mins}min';
    }
    
    return '$durationValue min';
  } catch (e) {
    print('❌ Erreur formatage durée: $e');
    return '0 min';
  }
}

/// Formate une durée de type Duration en format HH:MM:SS
/// Utilisé pour les chronomètres en temps réel
/// 
/// Exemple:
/// ```dart
/// formatDurationTimer(Duration(hours: 1, minutes: 23, seconds: 45)) → "01:23:45"
/// ```
String formatDurationTimer(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  
  final hours = twoDigits(duration.inHours);
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  
  // Si moins d'1 heure, afficher seulement MM:SS
  if (duration.inHours == 0) {
    return '$minutes:$seconds';
  }
  
  return '$hours:$minutes:$seconds';
}

/// Formate une distance en format lisible
/// 
/// Exemples:
/// ```dart
/// formatDistance(1.5) → "1,5 km"
/// formatDistance(0.8) → "800 m"
/// formatDistance(0.05) → "50 m"
/// ```
String formatDistance(dynamic distance) {
  if (distance == null) return '0 km';
  
  try {
    final distanceValue = (distance is num) ? distance.toDouble() : double.parse(distance.toString());
    
    if (distanceValue < 1.0) {
      // Afficher en mètres si < 1 km
      final meters = (distanceValue * 1000).round();
      return '$meters m';
    }
    
    // Afficher en km avec 1 décimale
    return '${distanceValue.toStringAsFixed(1)} km';
  } catch (e) {
    print('❌ Erreur formatage distance: $e');
    return '0 km';
  }
}

/// Formate un prix en dirhams marocains
/// 
/// Exemples:
/// ```dart
/// formatPrice(150) → "150 MAD"
/// formatPrice(1500) → "1 500 MAD"
/// formatPrice(150.5) → "150,50 MAD"
/// ```
String formatPrice(dynamic price) {
  if (price == null) return '0 MAD';
  
  try {
    final priceValue = (price is num) ? price.toDouble() : double.parse(price.toString());
    
    // Si nombre entier, pas de décimales
    if (priceValue == priceValue.roundToDouble()) {
      final formatted = priceValue.round().toString();
      // Ajouter des espaces tous les 3 chiffres
      final parts = <String>[];
      var remaining = formatted;
      while (remaining.length > 3) {
        parts.insert(0, remaining.substring(remaining.length - 3));
        remaining = remaining.substring(0, remaining.length - 3);
      }
      if (remaining.isNotEmpty) {
        parts.insert(0, remaining);
      }
      return '${parts.join(' ')} MAD';
    }
    
    // Avec décimales
    return '${priceValue.toStringAsFixed(2).replaceAll('.', ',')} MAD';
  } catch (e) {
    print('❌ Erreur formatage prix: $e');
    return '0 MAD';
  }
}

/// Formate un numéro de téléphone au format marocain
/// 
/// Exemples:
/// ```dart
/// formatPhoneNumber('+212669337846') → '0669 33 78 46'
/// formatPhoneNumber('0669337846') → '0669 33 78 46'
/// ```
String formatPhoneNumber(String? phone) {
  if (phone == null || phone.isEmpty) return '';
  
  // Enlever le +212 si présent
  var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (cleaned.startsWith('212')) {
    cleaned = '0${cleaned.substring(3)}';
  }
  
  // Format: 0XXX XX XX XX
  if (cleaned.length == 10) {
    return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 6)} ${cleaned.substring(6, 8)} ${cleaned.substring(8, 10)}';
  }
  
  return phone;
}

/// Formate une date en format lisible français
/// 
/// Exemples:
/// ```dart
/// formatDate(DateTime(2025, 10, 14)) → "14 octobre 2025"
/// formatDate(DateTime(2025, 10, 14, 15, 30)) → "14 octobre 2025 à 15h30"
/// ```
String formatDate(DateTime? date, {bool showTime = false}) {
  if (date == null) return '';
  
  const months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];
  
  final formatted = '${date.day} ${months[date.month - 1]} ${date.year}';
  
  if (showTime) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$formatted à ${hour}h$minute';
  }
  
  return formatted;
}
