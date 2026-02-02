import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

// Constantes copiées de database_service.dart
const String supabaseUrl = 'https://aijchsvkuocbtzamyojy.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpamNoc3ZrdW9jYnR6YW15b2p5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxNzcyOTMsImV4cCI6MjA3NTc1MzI5M30.XKkMKK11Xd8PqWftANI4B4p6BO_O0zO9Ed4uKTDWonk';


/// Script de simulation de mouvement GPS pour tester le tracking
Future<void> main() async {
  print('🚗 Démarrage de la simulation GPS...');
  
  // 1. Init Client (Direct)
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  // 2. Trouver un chauffeur
  String driverId;
  try {
      print('🔍 Recherche d\'un chauffeur existant...');
      final response = await client.from('drivers').select('id, first_name, last_name').limit(1);
      
      if (response.isEmpty) {
          print('❌ Aucun chauffeur trouvé. Veuillez en créer un via l\'app ou le script SQL.');
          return;
      }
      
      final driver = response.first;
      driverId = driver['id'];
      print('✅ Chauffeur trouvé: ${driver['first_name']} ${driver['last_name']} ($driverId)');
      
  } catch (e) {
      print('❌ Erreur connexion DB: $e');
      return;
  }
  
  // Point de départ (Rabat centre)
  double lat = 34.020882;
  double lng = -6.841650;
  
  print('📍 Simulation pour chauffeur: $driverId');
  print('🏁 Point de départ: $lat, $lng');

  // Simulation d'un trajet vers le sud-est
  int step = 0;
  // Timer plus rapide pour voir le mouvement (1s)
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    step++;
    
    // Déplacer (Vitesse ~50km/h => ~14m/s => ~0.00013 deg)
    lat += 0.00015 + (Random().nextDouble() * 0.00005); 
    lng += 0.00015 + (Random().nextDouble() * 0.00005);
    
    try {
        await client.from('driver_locations').upsert({
        'driver_id': driverId,
        'lat': lat,
        'lng': lng,
        'heading': 135.0, // Sud-est
        'speed': 30.0 + Random().nextInt(20),
        'accuracy': 5.0,
        'updated_at': DateTime.now().toIso8601String(),
        });
        
        print('✅ [$step] Maj Position : ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}');
    } catch (e) {
        print('❌ Erreur update: $e');
    }
    
    if (step >= 600) { // 10 minutes
        print('🛑 Fin de la simulation');
        timer.cancel();
    }
  });
  
  // Garder le process en vie
  await Future.delayed(const Duration(minutes: 10));
}
