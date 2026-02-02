import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

/// Service complet Google Maps : Directions API + Places Autocomplete + Geocoding
class GoogleMapsService {
  // ⚠️ REMPLACER PAR VOTRE CLÉ API GOOGLE MAPS
  // Obtenir sur: https://console.cloud.google.com/apis/credentials
  static const String _apiKey = 'AIzaSyActf0CrnvkQfYAnA4j8vdP4ve9zH1WfWM'; // ⚠️ À REMPLACER
  
  static const String _directionsUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _placesAutocompleteUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _placeDetailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
  static const String _geocodingUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  // ============================================
  // 1. DIRECTIONS API - Distance routière réelle
  // ============================================
  
  /// Calcule la route routière réelle entre 2 points
  static Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String language = 'fr',
  }) async {
    final url = Uri.parse(
      '$_directionsUrl?'
      'origin=${origin.latitude},${origin.longitude}&'
      'destination=${destination.latitude},${destination.longitude}&'
      'language=$language&'
      'key=$_apiKey',
    );

    try {
      print('🗺️ Appel Google Directions API...');
      print('📍 Départ: ${origin.latitude}, ${origin.longitude}');
      print('📍 Arrivée: ${destination.latitude}, ${destination.longitude}');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          final result = {
            'distance_meters': leg['distance']['value'], // Mètres
            'distance_km': leg['distance']['value'] / 1000.0, // Kilomètres
            'distance_text': leg['distance']['text'], // "12.5 km"
            'duration_seconds': leg['duration']['value'], // Secondes
            'duration_minutes': (leg['duration']['value'] / 60.0).round(), // Minutes
            'duration_text': leg['duration']['text'], // "25 min"
            'start_address': leg['start_address'], // Adresse textuelle départ
            'end_address': leg['end_address'], // Adresse textuelle arrivée
            'polyline': route['overview_polyline']['points'], // Polyline encodée
            'steps': leg['steps'], // Étapes navigation
          };
          
          print('✅ Route calculée: ${result['distance_km']} km, ${result['duration_minutes']} min');
          print('📍 Départ: ${result['start_address']}');
          print('📍 Arrivée: ${result['end_address']}');
          
          return result;
        } else {
          print('⚠️ Aucune route trouvée: ${data['status']}');
          return null;
        }
      } else {
        print('❌ Erreur HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur Directions API: $e');
      return null;
    }
  }

  // ============================================
  // 2. PLACES AUTOCOMPLETE - Suggestions adresses
  // ============================================
  
  /// Recherche d'adresses avec autocomplétion (suggestions dynamiques)
  static Future<List<Map<String, dynamic>>> getPlaceSuggestions({
    required String input,
    String? sessionToken,
    LatLng? location,
    int radius = 50000, // 50 km par défaut
    String language = 'fr',
    String components = 'country:ma', // Limiter au Maroc
  }) async {
    if (input.trim().isEmpty) return [];

    String url = '$_placesAutocompleteUrl?'
        'input=${Uri.encodeComponent(input)}&'
        'language=$language&'
        'components=$components&'
        'key=$_apiKey';

    // Ajouter localisation pour favoriser résultats proches
    if (location != null) {
      url += '&location=${location.latitude},${location.longitude}&radius=$radius';
    }

    // Ajouter session token pour regrouper requêtes (économie coûts)
    if (sessionToken != null) {
      url += '&sessiontoken=$sessionToken';
    }

    try {
      print('🔍 Recherche adresses: "$input"');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // ⚠️ Vérifier les erreurs d'authentification ou d'API
        if (data['status'] == 'REQUEST_DENIED' || data['status'] == 'INVALID_REQUEST') {
          final errorMsg = data['error_message'] ?? data['status'];
          print('❌ Google API refusée: $errorMsg');
          throw Exception('Google Places API: $errorMsg');
        }
        
        if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
          final predictions = data['predictions'] as List? ?? [];
          
          final results = predictions.map((prediction) {
            return {
              'place_id': prediction['place_id'],
              'description': prediction['description'], // Adresse complète
              'main_text': prediction['structured_formatting']['main_text'], // Nom principal
              'secondary_text': prediction['structured_formatting']['secondary_text'], // Détails
            };
          }).toList();
          
          print('✅ ${results.length} suggestions trouvées');
          return results;
        } else {
          print('⚠️ Aucune suggestion: ${data['status']}');
          return [];
        }
      } else {
        print('❌ Erreur HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur Autocomplete: $e');
      return [];
    }
  }

  // ============================================
  // 3. PLACE DETAILS - Obtenir coordonnées GPS d'un lieu
  // ============================================
  
  /// Obtient les détails d'un lieu (coordonnées GPS) à partir de son place_id
  static Future<Map<String, dynamic>?> getPlaceDetails({
    required String placeId,
    String? sessionToken,
    String language = 'fr',
  }) async {
    String url = '$_placeDetailsUrl?'
        'place_id=$placeId&'
        'fields=geometry,formatted_address,name&'
        'language=$language&'
        'key=$_apiKey';

    if (sessionToken != null) {
      url += '&sessiontoken=$sessionToken';
    }

    try {
      print('📍 Récupération détails lieu: $placeId');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          
          final details = {
            'lat': location['lat'],
            'lng': location['lng'],
            'formatted_address': result['formatted_address'],
            'name': result['name'],
          };
          
          print('✅ Lieu trouvé: ${details['formatted_address']}');
          print('📍 Coordonnées: ${details['lat']}, ${details['lng']}');
          
          return details;
        } else {
          print('⚠️ Lieu non trouvé: ${data['status']}');
          return null;
        }
      } else {
        print('❌ Erreur HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur Place Details: $e');
      return null;
    }
  }

  // ============================================
  // 4. GEOCODING - Convertir adresse → coordonnées
  // ============================================
  
  /// Convertit une adresse textuelle en coordonnées GPS
  static Future<Map<String, dynamic>?> geocodeAddress({
    required String address,
    String language = 'fr',
    String components = 'country:ma',
  }) async {
    final url = Uri.parse(
      '$_geocodingUrl?'
      'address=${Uri.encodeComponent(address)}&'
      'language=$language&'
      'components=$components&'
      'key=$_apiKey',
    );

    try {
      print('🌍 Geocoding adresse: "$address"');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          
          final geocoded = {
            'lat': location['lat'],
            'lng': location['lng'],
            'formatted_address': result['formatted_address'],
            'place_id': result['place_id'],
          };
          
          print('✅ Adresse géocodée: ${geocoded['formatted_address']}');
          print('📍 Coordonnées: ${geocoded['lat']}, ${geocoded['lng']}');
          
          return geocoded;
        } else {
          print('⚠️ Adresse non trouvée: ${data['status']}');
          return null;
        }
      } else {
        print('❌ Erreur HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur Geocoding: $e');
      return null;
    }
  }

  // ============================================
  // 5. REVERSE GEOCODING - Convertir coordonnées → adresse
  // ============================================
  
  /// Convertit des coordonnées GPS en adresse textuelle
  static Future<String?> reverseGeocode({
    required LatLng location,
    String language = 'fr',
  }) async {
    final url = Uri.parse(
      '$_geocodingUrl?'
      'latlng=${location.latitude},${location.longitude}&'
      'language=$language&'
      'key=$_apiKey',
    );

    try {
      print('🌍 Reverse geocoding: ${location.latitude}, ${location.longitude}');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final address = data['results'][0]['formatted_address'];
          print('✅ Adresse trouvée: $address');
          return address;
        } else {
          print('⚠️ Adresse non trouvée: ${data['status']}');
          return null;
        }
      } else {
        print('❌ Erreur HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur Reverse Geocoding: $e');
      return null;
    }
  }

  // ============================================
  // 6. WIDGET AUTOCOMPLETE - UI prêt à l'emploi
  // ============================================
  
  /// Widget TextField avec autocomplétion d'adresses
  static Widget buildAddressAutocompleteField({
    required BuildContext context,
    required TextEditingController controller,
    required Function(Map<String, dynamic> place) onPlaceSelected,
    String hintText = 'Entrez une adresse...',
    LatLng? currentLocation,
    String? sessionToken,
  }) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }

        final suggestions = await getPlaceSuggestions(
          input: textEditingValue.text,
          sessionToken: sessionToken,
          location: currentLocation,
        );

        return suggestions;
      },
      displayStringForOption: (option) => option['description'],
      onSelected: (option) async {
        print('✅ Adresse sélectionnée: ${option['description']}');
        
        // Récupérer coordonnées GPS
        final details = await getPlaceDetails(
          placeId: option['place_id'],
          sessionToken: sessionToken,
        );
        
        if (details != null) {
          final placeWithCoords = {
            ...option,
            'lat': details['lat'],
            'lng': details['lng'],
            'formatted_address': details['formatted_address'],
          };
          
          onPlaceSelected(placeWithCoords);
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.location_on, color: Color(0xFF4CAF50)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
          ),
          onEditingComplete: onEditingComplete,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFF4CAF50)),
                    title: Text(
                      option['main_text'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      option['secondary_text'],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
