import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

/// Service "Zéro Budget" utilisant OpenStreetMap (OSM), Nominatim et OSRM
class OSMService {
  // URLs des services OSM gratuits
  static const String _nominatimSearchUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _nominatimReverseUrl = 'https://nominatim.openstreetmap.org/reverse';
  static const String _osrmRouteUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  // ============================================
  // 1. OSRM ROUTING - Distance routière réelle
  // ============================================
  
  /// Calcule la route routière réelle entre 2 points via OSRM
  static Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      '$_osrmRouteUrl/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=polyline&steps=true'
    );

    try {
      print('🗺️ Appel OSRM Routing API...');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          final result = {
            'distance_meters': route['distance'],
            'distance_km': route['distance'] / 1000.0,
            'distance_text': '${(route['distance'] / 1000.0).toStringAsFixed(1)} km',
            'duration_seconds': route['duration'],
            'duration_minutes': (route['duration'] / 60.0).round(),
            'duration_text': '${(route['duration'] / 60.0).round()} min',
            'polyline': route['geometry'], // Polyline encodée
            'steps': route['legs'][0]['steps'],
          };
          
          print('✅ Route calculée: ${result['distance_km']} km, ${result['duration_minutes']} min');
          return result;
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur OSRM API: $e');
      return null;
    }
  }

  // ============================================
  // 2. NOMINATIM - Recherche et Autocomplete
  // ============================================
  
  /// Recherche d'adresses (Geocoding) via Nominatim
  static Future<List<Map<String, dynamic>>> getPlaceSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    final url = Uri.parse(
      '$_nominatimSearchUrl?q=${Uri.encodeComponent(input)}&format=json&limit=5&addressdetails=1&countrycodes=ma' // Limité au Maroc
    );

    try {
      print('🔍 Recherche OSM: "$input"');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'YallaTbibApp/1.0', // Obligatoire pour Nominatim
      });
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        
        return data.map((place) {
          return {
            'place_id': place['place_id'].toString(),
            'description': place['display_name'],
            'main_text': place['address']['road'] ?? place['address']['suburb'] ?? place['display_name'].split(',')[0],
            'secondary_text': place['display_name'].split(',').skip(1).join(',').trim(),
            'lat': double.parse(place['lat']),
            'lng': double.parse(place['lon']),
          };
        }).toList();
      }
    } catch (e) {
      print('❌ Erreur Nominatim: $e');
    }
    return [];
  }

  // ============================================
  // 3. REVERSE GEOCODING
  // ============================================
  
  static Future<String?> reverseGeocode(LatLng location) async {
    final url = Uri.parse(
      '$_nominatimReverseUrl?lat=${location.latitude}&lon=${location.longitude}&format=json'
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'YallaTbibApp/1.0',
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'];
      }
    } catch (e) {
      print('❌ Erreur Reverse Geocoding: $e');
    }
    return null;
  }

  // ============================================
  // 4. OVERPASS - Recherche de pharmacies proches
  // ============================================

  /// Récupère les pharmacies réelles autour d'une position (par défaut 5km)
  static Future<List<Map<String, dynamic>>> getNearbyPharmacies(LatLng location, {double radius = 5000}) async {
    final query = '''
      [out:json];
      node["amenity"="pharmacy"](around:$radius, ${location.latitude}, ${location.longitude});
      out body;
    ''';

    try {
      print('💊 Recherche de pharmacies réelles autour de: ${location.latitude}, ${location.longitude}');
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'];
        
        return elements.map((e) {
          final tags = e['tags'] ?? {};
          return {
            'id': e['id'].toString(),
            'lat': e['lat'],
            'lng': e['lon'],
            'name': tags['name'] ?? 'Pharmacie',
            'phone': tags['phone'] ?? tags['contact:phone'] ?? 'Non disponible',
            'opening_hours': tags['opening_hours'] ?? 'Consulter sur place',
          };
        }).toList();
      }
    } catch (e) {
      print('❌ Erreur Overpass API: $e');
    }
    return [];
  }
}
