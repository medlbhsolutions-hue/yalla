import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'database_service.dart';

/// Service de géolocalisation temps réel pour les chauffeurs
/// ✅ OPTIMISÉ: Mode adaptatif GPS + Upload intelligent
class LocationTrackingService {
  static StreamSubscription<Position>? _positionStream;
  static Timer? _uploadTimer;
  static Position? _lastPosition;
  static Position? _lastUploadedPosition;
  static bool _isTracking = false;
  static String? _currentDriverId;
  
  // Seuils de mouvement (éviter upload si immobile)
  static const double _movementThresholdMeters = 5.0; // Upload si mouvement > 5m
  static const int _uploadIntervalSeconds = 5; // Upload toutes les 5s si mouvement
  static const int _maxUploadIntervalSeconds = 30; // Upload max tous les 30s même si immobile

  /// Démarre le tracking GPS pour un chauffeur
  static Future<void> startTracking({required String driverId}) async {
    if (_isTracking && _currentDriverId == driverId) {
      print('⚠️ Tracking déjà actif pour ce chauffeur');
      return;
    }
    
    // Arrêter ancien tracking si différent chauffeur
    if (_isTracking && _currentDriverId != driverId) {
      await stopTracking();
    }

    print('📍 Démarrage du tracking GPS pour chauffeur: $driverId');
    _currentDriverId = driverId;

    // 1. Vérifier les permissions
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      print('❌ Permissions GPS refusées');
      return;
    }

    // 2. Paramètres de localisation ADAPTATIFS
    // ✅ Haute précision mais économie batterie via distanceFilter
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, // Précision maximale
      distanceFilter: 10, // Update uniquement si mouvement > 10m
      timeLimit: Duration(seconds: 10), // Timeout 10s
    );

    // 3. Écouter les changements de position
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastPosition = position;
        print('📍 Position mise à jour: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} (${position.speed.toStringAsFixed(1)} m/s)');
        
        // Upload immédiat si mouvement significatif
        if (_shouldUpload(position)) {
          _uploadPosition(driverId, position);
        }
      },
      onError: (error) {
        print('❌ Erreur tracking GPS: $error');
      },
    );

    // 4. Upload périodique de sécurité (même si immobile)
    // Utile pour confirmer que le chauffeur est toujours en ligne
    _uploadTimer = Timer.periodic(Duration(seconds: _maxUploadIntervalSeconds), (timer) {
      if (_lastPosition != null) {
        print('⏰ Upload périodique de sécurité (${_maxUploadIntervalSeconds}s)');
        _uploadPosition(driverId, _lastPosition!);
      }
    });

    _isTracking = true;
    print('✅ Tracking GPS démarré avec succès');
    print('   Mode adaptatif: Upload si mouvement > $_movementThresholdMeters m');
    print('   Upload max tous les $_maxUploadIntervalSeconds s');
  }

  /// Arrête le tracking GPS
  static Future<void> stopTracking() async {
    if (!_isTracking) {
      print('⚠️ Tracking déjà arrêté');
      return;
    }
    
    print('🛑 Arrêt du tracking GPS pour chauffeur: $_currentDriverId');

    await _positionStream?.cancel();
    _uploadTimer?.cancel();

    _positionStream = null;
    _uploadTimer = null;
    _lastPosition = null;
    _lastUploadedPosition = null;
    _isTracking = false;
    _currentDriverId = null;

    print('✅ Tracking GPS arrêté');
  }
  
  /// Détermine si on doit uploader la position (économie batterie/bande passante)
  static bool _shouldUpload(Position newPosition) {
    if (_lastUploadedPosition == null) {
      return true; // Première position
    }
    
    // Calculer distance depuis dernier upload
    final distanceMeters = Geolocator.distanceBetween(
      _lastUploadedPosition!.latitude,
      _lastUploadedPosition!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );
    
    // Upload uniquement si mouvement significatif
    if (distanceMeters > _movementThresholdMeters) {
      print('🚗 Mouvement détecté: ${distanceMeters.toStringAsFixed(1)} m → Upload');
      return true;
    }
    
    return false; // Pas de mouvement significatif, skip upload
  }

  /// Upload la position actuelle vers Supabase
  static Future<void> _uploadPosition(String driverId, Position position) async {
    try {
      await DatabaseService.client.from('driver_locations').upsert({
        'driver_id': driverId,
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed * 3.6, // m/s vers km/h
        'accuracy': position.accuracy,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _lastUploadedPosition = position; // Mémoriser dernière position uploadée
      print('✅ Position uploadée: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} (${(position.speed * 3.6).toStringAsFixed(1)} km/h)');
    } catch (e) {
      print('❌ Erreur upload position: $e');
    }
  }

  /// Vérifie et demande les permissions GPS
  static Future<bool> _checkPermissions() async {
    // Vérifier si le service est activé
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Service de localisation désactivé');
      return false;
    }

    // Vérifier les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Permission de localisation refusée');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Permission de localisation refusée définitivement');
      return false;
    }

    return true;
  }

  /// Récupère la position actuelle du chauffeur
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('❌ Erreur récupération position: $e');
      return null;
    }
  }

  /// Récupère les chauffeurs disponibles à proximité
  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double pickupLat,
    required double pickupLng,
    int radiusKm = 10,
  }) async {
    try {
      final response = await DatabaseService.client.rpc(
        'find_nearby_drivers',
        params: {
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'radius_km': radiusKm,
        },
      );

      final drivers = (response as List)
          .map((driver) => Map<String, dynamic>.from(driver))
          .toList();

      print('✅ ${drivers.length} chauffeurs trouvés dans un rayon de ${radiusKm}km');
      return drivers;
    } catch (e) {
      print('❌ Erreur recherche chauffeurs: $e');
      return [];
    }
  }

  /// Stream temps réel de la position d'un chauffeur
  static Stream<Map<String, dynamic>?> watchDriverLocation(String driverId) {
    return DatabaseService.client
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  /// Calcule la distance entre 2 points (km)
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // en km
  }

  /// Statut du tracking
  static bool get isTracking => _isTracking;
}
