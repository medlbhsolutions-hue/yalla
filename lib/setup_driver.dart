import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// URL et clés PROD (copiées de database_service.dart)
const String supabaseUrl = 'https://aijchsvkuocbtzamyojy.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpamNoc3ZrdW9jYnR6YW15b2p5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxNzcyOTMsImV4cCI6MjA3NTc1MzI5M30.XKkMKK11Xd8PqWftANI4B4p6BO_O0zO9Ed4uKTDWonk';


void main() async {
  print('🔄 Initialisation Supabase Client...');
  // Utilisation directe du client pour éviter les dépendances natives (SharedPreferences)
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

    // 1. Créer/Login User
    const email = 'driver.test.simulation@yallatbib.ma';
    const password = 'Password123!';
    String userId;

    print('👤 Tentative inscription utilisateur: $email');
    try {
      final authResponse = await client.auth.signUp(
        email: email,
        password: password,
      );
      if (authResponse.user != null) {
        userId = authResponse.user!.id;
        print('✅ Utilisateur CRÉÉ: $userId');
      } else {
        // Probablement déjà existant, on tente login
        print('🔒 Déjà existant, tentative connexion...');
        final loginResponse = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        userId = loginResponse.user!.id;
        print('✅ Utilisateur CONNECTÉ: $userId');
      }
    } catch (e) {
      // Si erreur signUp car déjà inscrit mais pas connecté
      print('🔒 Erreur inscription ($e), tentative connexion...');
      final loginResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      userId = loginResponse.user!.id;
      print('✅ Utilisateur CONNECTÉ via catch: $userId');
    }

    // 2. Créer Profil Chauffeur
    print('🚗 Création/Récupération profil Chauffeur...');
    String driverId;
    
    // Vérifier si existe déjà
    final existingDriver = await client
        .from('drivers')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existingDriver != null) {
        driverId = existingDriver['id'];
        print('✅ Profil Chauffeur EXISTANT: $driverId');
        
        // Mettre à jour pour être sûr qu'il est dispo
        await client.from('drivers').update({
            'is_available': true,
            'status': 'active', // Ou 'approved' selon votre enum
        }).eq('id', driverId);
    } else {
        final newDriver = await client.from('drivers').insert({
            'user_id': userId,
            'first_name': 'Simulation',
            'last_name': 'Driver',
            'national_id': 'SIMUL-001',
            'city': 'Casablanca',
            'is_available': true,
            'status': 'active',
            'rating': 5.0,
            'created_at': DateTime.now().toIso8601String(),
        }).select().single();
        
        driverId = newDriver['id'];
        print('✅ NOUVEAU Profil Chauffeur créé: $driverId');
    }
    
    // 3. Créer Véhicule
    print('🚙 Création/Vérification Véhicule...');
    try {
        await client.from('vehicles').upsert({
            'driver_id': driverId,
            'make': 'Simulation',
            'model': 'Car',
            'plate_number': 'SIM-999',
            'vehicle_type': 'ambulance',
            'is_active': true
        }, onConflict: 'plate_number'); // Assurez-vous d'avoir une contrainte unique si besoin, sinon insert simple
        print('✅ Véhicule assigné');
    } catch (e) {
        print('⚠️ Note sur véhicule: $e (peut être ignoré si déjà présent)');
    }

    print('\n🎉 RÉSUMÉ POUR LE SCRIPT DE SIMULATION 🎉');
    print('-------------------------------------------');
    print('-------------------------------------------');
}
