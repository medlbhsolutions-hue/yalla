import 'package:flutter/material.dart';
import 'lib/src/services/database_service.dart';

/// Script de test pour vérifier la connexion Supabase en production
/// 
/// Pour exécuter ce test :
/// ```bash
/// flutter run test_production.dart
/// ```

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 YALLA TBIB - TEST DE PRODUCTION');
  print('=' * 50);
  
  await runTests();
}

Future<void> runTests() async {
  try {
    // Test 1: Initialisation Supabase
    print('\n📋 Test 1: Initialisation Supabase');
    print('-' * 50);
    await DatabaseService.initialize();
    print('✅ Supabase initialisé avec succès\n');
    
    // Test 2: Inscription d'un utilisateur
    print('📋 Test 2: Inscription utilisateur');
    print('-' * 50);
    final testEmail = 'test_${DateTime.now().millisecondsSinceEpoch}@yallatbib.com';
    final testPassword = 'TestPassword123!';
    
    try {
      final signUpResponse = await DatabaseService.signUp(testEmail, testPassword);
      if (signUpResponse.user != null) {
        print('✅ Inscription réussie');
        print('   Email: ${signUpResponse.user!.email}');
        print('   ID: ${signUpResponse.user!.id}\n');
      } else {
        print('⚠️  Inscription sans erreur mais pas d\'utilisateur retourné\n');
      }
    } catch (e) {
      print('❌ Erreur inscription: $e\n');
    }
    
    // Test 3: Connexion
    print('📋 Test 3: Connexion utilisateur');
    print('-' * 50);
    try {
      final signInResponse = await DatabaseService.signIn(testEmail, testPassword);
      if (signInResponse.user != null) {
        print('✅ Connexion réussie');
        print('   Email: ${signInResponse.user!.email}');
        print('   ID: ${signInResponse.user!.id}\n');
      } else {
        print('⚠️  Connexion sans erreur mais pas d\'utilisateur retourné\n');
      }
    } catch (e) {
      print('❌ Erreur connexion: $e\n');
    }
    
    // Test 4: Création profil patient
    print('📋 Test 4: Création profil patient');
    print('-' * 50);
    try {
      final patientProfile = await DatabaseService.createPatientProfile(
        firstName: 'Ahmed',
        lastName: 'Test',
        dateOfBirth: DateTime(1990, 1, 1),
        emergencyContactName: 'Fatima Test',
        emergencyContactPhone: '+212 6XX XXX XXX',
        medicalConditions: ['Diabète', 'Hypertension'],
      );
      print('✅ Profil patient créé');
      print('   ID: ${patientProfile['id']}');
      print('   Nom: ${patientProfile['first_name']} ${patientProfile['last_name']}\n');
    } catch (e) {
      print('❌ Erreur création profil patient: $e\n');
    }
    
    // Test 5: Récupération profil patient
    print('📋 Test 5: Récupération profil patient');
    print('-' * 50);
    try {
      final profile = await DatabaseService.getPatientProfile();
      if (profile != null) {
        print('✅ Profil patient récupéré');
        print('   ID: ${profile['id']}');
        print('   Nom: ${profile['first_name']} ${profile['last_name']}\n');
      } else {
        print('⚠️  Aucun profil patient trouvé\n');
      }
    } catch (e) {
      print('❌ Erreur récupération profil: $e\n');
    }
    
    // Test 6: Création d'une course
    print('📋 Test 6: Création d\'une course');
    print('-' * 50);
    try {
      // Récupérer l'utilisateur actuel
      final currentUserId = DatabaseService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final ride = await DatabaseService.createRide(
        patientId: currentUserId,
        pickupAddress: 'Quartier Hassan, Rabat',
        pickupLatitude: 34.0209,
        pickupLongitude: -6.8498,
        destinationAddress: 'Hôpital Ibn Sina, Rabat',
        destinationLatitude: 34.0181,
        destinationLongitude: -6.8447,
        distanceKm: 3.5,
        durationMinutes: 12,
        estimatedPrice: 45.0,
        priority: 'high',
        medicalNotes: 'Patient diabétique - Transport urgent',
      );
      print('✅ Course créée');
      print('   ID: ${ride['id']}');
      print('   Départ: ${ride['pickup_address']}');
      print('   Destination: ${ride['destination_address']}');
      print('   Prix estimé: ${ride['estimated_price']} MAD');
      print('   Statut: ${ride['status']}\n');
    } catch (e) {
      print('❌ Erreur création course: $e\n');
    }
    
    // Test 7: Récupération des courses en attente
    print('📋 Test 7: Récupération courses en attente');
    print('-' * 50);
    try {
      final pendingRides = await DatabaseService.getPendingRides();
      print('✅ Courses en attente récupérées');
      print('   Nombre: ${pendingRides.length}');
      if (pendingRides.isNotEmpty) {
        print('   Première course:');
        print('     - ID: ${pendingRides[0]['id']}');
        print('     - Départ: ${pendingRides[0]['pickup_address']}');
        print('     - Destination: ${pendingRides[0]['destination_address']}');
      }
      print('');
    } catch (e) {
      print('❌ Erreur récupération courses: $e\n');
    }
    
    // Test 8: Historique des courses patient
    print('📋 Test 8: Historique courses patient');
    print('-' * 50);
    try {
      final history = await DatabaseService.getPatientRideHistory();
      print('✅ Historique récupéré');
      print('   Nombre de courses: ${history.length}\n');
    } catch (e) {
      print('❌ Erreur historique: $e\n');
    }
    
    // Test 9: Déconnexion
    print('📋 Test 9: Déconnexion');
    print('-' * 50);
    try {
      await DatabaseService.signOut();
      print('✅ Déconnexion réussie\n');
    } catch (e) {
      print('❌ Erreur déconnexion: $e\n');
    }
    
    // Résumé
    print('=' * 50);
    print('🎉 TESTS TERMINÉS');
    print('=' * 50);
    print('\n✅ Si tous les tests sont passés, votre configuration est correcte !');
    print('❌ Si des tests ont échoué, vérifiez :');
    print('   1. Vos clés Supabase dans database_service.dart');
    print('   2. Que le schéma de base de données est bien exécuté');
    print('   3. Que RLS est correctement configuré');
    print('   4. Les logs dans la console Supabase\n');
    
  } catch (e, stackTrace) {
    print('\n❌ ERREUR CRITIQUE: $e');
    print('Stack trace: $stackTrace\n');
  }
}
