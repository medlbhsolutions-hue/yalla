import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;
  Position? get currentPosition => _currentPosition;

  /// Vérifier et demander les permissions de localisation
  Future<bool> requestLocationPermission() async {
    try {
      // Vérifier si les services de localisation sont activés (avec timeout)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('⏱️ Timeout vérification services GPS');
          return false;
        },
      );
      
      if (!serviceEnabled) {
        print('⚠️ Services de localisation désactivés');
        return false;
      }

      // Vérifier les permissions (avec timeout)
      LocationPermission permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('⏱️ Timeout vérification permissions GPS');
          return LocationPermission.denied;
        },
      );
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⏱️ Timeout demande permissions GPS');
            return LocationPermission.denied;
          },
        );
        
        if (permission == LocationPermission.denied) {
          print('⚠️ Permission GPS refusée par l\'utilisateur');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Les permissions sont définitivement refusées
        print('⚠️ Permission GPS définitivement refusée');
        return false;
      }

      // Demander la permission en arrière-plan pour le suivi (sans bloquer)
      try {
        await Permission.locationAlways.request().timeout(
          const Duration(seconds: 2),
          onTimeout: () => PermissionStatus.denied,
        );
      } catch (e) {
        print('⚠️ Erreur permission background: $e');
      }
      
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      print('❌ Erreur lors de la demande de permission: $e');
      return false;
    }
  }

  /// Obtenir la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('⚠️ Permission GPS refusée, utilisation position par défaut (Casablanca)');
        return _getDefaultPosition();
      }

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mise à jour tous les 10 mètres
      );

      // Timeout de 5 secondes pour éviter les blocages
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏱️ Timeout GPS (5s), utilisation position par défaut (Casablanca)');
          return _getDefaultPosition();
        },
      );

      return _currentPosition;
    } catch (e) {
      print('❌ Erreur lors de l\'obtention de la position: $e');
      print('📍 Utilisation position par défaut (Casablanca)');
      return _getDefaultPosition();
    }
  }

  /// Position par défaut (Casablanca, Maroc) pour les cas d'erreur
  Position _getDefaultPosition() {
    return Position(
      latitude: 33.5731,
      longitude: -7.5898,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  /// Démarrer le suivi de position en temps réel
  Future<bool> startLocationTracking() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('⚠️ Permission GPS refusée pour le tracking');
        return false;
      }

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Mise à jour tous les 5 mètres
        timeLimit: Duration(seconds: 10), // Timeout après 10 secondes
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _currentPosition = position;
          _positionController.add(position);
          _saveLastPosition(position);
        },
        onError: (error) {
          print('❌ Erreur de suivi de position: $error');
          // En cas d'erreur, utiliser la position par défaut
          final defaultPos = _getDefaultPosition();
          _currentPosition = defaultPos;
          _positionController.add(defaultPos);
        },
        cancelOnError: false, // Ne pas annuler le stream en cas d'erreur
      );

      return true;
    } catch (e) {
      print('❌ Erreur lors du démarrage du suivi: $e');
      return false;
    }
  }

  /// Arrêter le suivi de position
  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Calculer la distance entre deux points
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculer le temps de trajet estimé (en minutes)
  double calculateEstimatedTime(double distanceInMeters) {
    // Vitesse moyenne en ville : 25 km/h
    const double averageSpeedKmh = 25.0;
    const double averageSpeedMs = averageSpeedKmh * 1000 / 3600; // m/s
    
    double timeInSeconds = distanceInMeters / averageSpeedMs;
    return timeInSeconds / 60; // Convertir en minutes
  }

  /// Obtenir l'adresse à partir des coordonnées
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      print('Erreur lors de l\'obtention de l\'adresse: $e');
    }
    return 'Adresse inconnue';
  }

  /// Sauvegarder la dernière position connue
  Future<void> _saveLastPosition(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);
      await prefs.setInt('last_position_timestamp', position.timestamp.millisecondsSinceEpoch);
    } catch (e) {
      print('Erreur lors de la sauvegarde de position: $e');
    }
  }

  /// Récupérer la dernière position sauvegardée
  Future<Position?> getLastSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final latitude = prefs.getDouble('last_latitude');
      final longitude = prefs.getDouble('last_longitude');
      final timestamp = prefs.getInt('last_position_timestamp');

      if (latitude != null && longitude != null && timestamp != null) {
        return Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
    } catch (e) {
      print('Erreur lors de la récupération de la position sauvegardée: $e');
    }
    return null;
  }

  /// Vérifier si l'utilisateur est proche d'une destination
  bool isNearDestination(
    Position currentPosition,
    double destinationLat,
    double destinationLng,
    {double radiusInMeters = 100}
  ) {
    double distance = calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      destinationLat,
      destinationLng,
    );
    return distance <= radiusInMeters;
  }

  /// Cleanup des ressources
  void dispose() {
    stopLocationTracking();
    _positionController.close();
  }
}

// Modèles pour les données de géolocalisation
class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
  });
}

class RoutePoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed;
  final String? description;

  RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.description,
  });
}

class RideLocation {
  final LocationData pickup;
  final LocationData destination;
  final List<RoutePoint> route;
  final double estimatedDistance;
  final double estimatedTime;

  RideLocation({
    required this.pickup,
    required this.destination,
    required this.route,
    required this.estimatedDistance,
    required this.estimatedTime,
  });
}