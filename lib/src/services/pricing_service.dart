import 'package:latlong2/latlong.dart';
import 'dart:math' show cos, sqrt, asin;
import 'osm_service.dart'; // ✅ Switch vers OSM (Gratuit)

/// Service de calcul des prix et distances pour les courses
/// ✅ Utilise Google Directions API pour distance routière RÉELLE
class PricingService {
  // Tarification (en MAD - Dirham Marocain)
  static const double _prixBase = 10.0; // Prix de départ
  static const double _tarifParKm = 5.0; // 5 MAD par km
  static const double _tarifParMinute = 0.5; // 0.5 MAD par minute
  static const double _tarifNuit = 1.5; // Majoration nocturne (x1.5)
  static const double _tarifUrgent = 2.0; // Majoration urgente (x2.0)
  
  // Heures de nuit (22h - 6h)
  static const int _heureDebutNuit = 22;
  static const int _heureFinNuit = 6;
  
  /// Calcule la distance en km entre deux coordonnées GPS (formule Haversine)
  static double calculateDistance(LatLng from, LatLng to) {
    const double earthRadiusKm = 6371.0;
    
    final double dLat = _degreesToRadians(to.latitude - from.latitude);
    final double dLon = _degreesToRadians(to.longitude - from.longitude);
    
    final double lat1 = _degreesToRadians(from.latitude);
    final double lat2 = _degreesToRadians(to.latitude);
    
    final double a = (dLat / 2).abs() * (dLat / 2).abs() +
                     (dLon / 2).abs() * (dLon / 2).abs() * cos(lat1) * cos(lat2);
    
    final double c = 2 * asin(sqrt(a));
    
    return earthRadiusKm * c;
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * 3.141592653589793 / 180.0;
  }
  
  /// Estime la durée du trajet en minutes (basé sur vitesse moyenne 40 km/h)
  static int estimateDuration(double distanceKm) {
    const double vitesseMoyenneKmh = 40.0;
    return (distanceKm / vitesseMoyenneKmh * 60).round();
  }
  
  /// Calcule le prix total d'une course
  static double calculatePrice({
    required double distanceKm,
    required int durationMinutes,
    bool isUrgent = false,
    DateTime? scheduledTime,
  }) {
    // Prix de base + distance + durée
    double prix = _prixBase + (distanceKm * _tarifParKm) + (durationMinutes * _tarifParMinute);
    
    // Majoration nocturne (22h - 6h)
    final time = scheduledTime ?? DateTime.now();
    final hour = time.hour;
    if (hour >= _heureDebutNuit || hour < _heureFinNuit) {
      prix *= _tarifNuit;
    }
    
    // Majoration urgente (cas critiques)
    if (isUrgent) {
      prix *= _tarifUrgent;
    }
    
    // Arrondir à 2 décimales
    return (prix * 100).round() / 100;
  }
  
  /// ⚠️ ANCIENNE MÉTHODE - Distance ligne droite (Haversine)
  /// Utilisée comme FALLBACK si Google Directions API échoue
  static Map<String, dynamic> calculatePriceEstimate({
    required LatLng pickup,
    required LatLng destination,
    bool isUrgent = false,
    DateTime? scheduledTime,
  }) {
    final double distanceKm = calculateDistance(pickup, destination);
    final int durationMin = estimateDuration(distanceKm);
    final double price = calculatePrice(
      distanceKm: distanceKm,
      durationMinutes: durationMin,
      isUrgent: isUrgent,
      scheduledTime: scheduledTime,
    );
    
    return {
      'distance_km': (distanceKm * 100).round() / 100,
      'duration_minutes': durationMin,
      'price_mad': price,
      'is_night_rate': _isNightTime(scheduledTime ?? DateTime.now()),
      'is_urgent': isUrgent,
      'method': 'haversine', // ⚠️ Distance ligne droite
      'breakdown': {
        'base_price': _prixBase,
        'distance_cost': (distanceKm * _tarifParKm * 100).round() / 100,
        'time_cost': (durationMin * _tarifParMinute * 100).round() / 100,
      },
    };
  }
  
  /// ✅ NOUVELLE MÉTHODE - Distance routière RÉELLE via Google Directions API
  /// Utilise la distance et durée réelles des routes
  static Future<Map<String, dynamic>> calculatePriceEstimateWithDirections({
    required LatLng pickup,
    required LatLng destination,
    bool isUrgent = false,
    DateTime? scheduledTime,
  }) async {
    try {
      // 1. Obtenir route réelle via OSRM (OSM)
      final directions = await OSMService.getDirections(
        origin: pickup,
        destination: destination,
      );
      
      if (directions != null) {
        // 2. Utiliser distance et durée RÉELLES
        final double distanceKm = directions['distance_km'];
        final int durationMin = directions['duration_minutes'];
        
        // 3. Calculer prix avec données réelles
        final double price = calculatePrice(
          distanceKm: distanceKm,
          durationMinutes: durationMin,
          isUrgent: isUrgent,
          scheduledTime: scheduledTime,
        );
        
        print('✅ Prix calculé avec route réelle: ${price.toStringAsFixed(2)} MAD');
        print('📍 Distance réelle: ${distanceKm.toStringAsFixed(1)} km (route)');
        print('⏱️ Durée réelle: $durationMin min (trafic inclus)');
        
        return {
          'distance_km': (distanceKm * 100).round() / 100,
          'distance_text': directions['distance_text'], // "12.5 km"
          'duration_minutes': durationMin,
          'duration_text': directions['duration_text'], // "25 min"
          'price_mad': price,
          'is_night_rate': _isNightTime(scheduledTime ?? DateTime.now()),
          'is_urgent': isUrgent,
          'method': 'osm_osrm', // ✅ Distance routière réelle gratuite
          'start_address': directions['start_address'],
          'end_address': directions['end_address'],
          'polyline': directions['polyline'], // Pour afficher trajet sur carte
          'breakdown': {
            'base_price': _prixBase,
            'distance_cost': (distanceKm * _tarifParKm * 100).round() / 100,
            'time_cost': (durationMin * _tarifParMinute * 100).round() / 100,
          },
        };
      } else {
        // Fallback sur Haversine si Directions API échoue
        print('⚠️ Google Directions API échouée, fallback Haversine');
        return calculatePriceEstimate(
          pickup: pickup,
          destination: destination,
          isUrgent: isUrgent,
          scheduledTime: scheduledTime,
        );
      }
    } catch (e) {
      print('❌ Erreur calcul avec Directions API: $e');
      // Fallback sur Haversine en cas d'erreur
      return calculatePriceEstimate(
        pickup: pickup,
        destination: destination,
        isUrgent: isUrgent,
        scheduledTime: scheduledTime,
      );
    }
  }
  
  static bool _isNightTime(DateTime time) {
    final hour = time.hour;
    return hour >= _heureDebutNuit || hour < _heureFinNuit;
  }
  
  /// Formatte le prix en MAD (ex: "125.50 MAD")
  static String formatPrice(double price) {
    return '${price.toStringAsFixed(2)} MAD';
  }
  
  /// Formatte la distance (ex: "12.5 km")
  static String formatDistance(double distanceKm) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }
  
  /// Formatte la durée (ex: "25 min")
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}min';
    }
  }
}
