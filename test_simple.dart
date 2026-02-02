import 'lib/src/services/database_service.dart';

/// Test simple de connexion Supabase
void main() async {
  print('🚀 YALLA TBIB - TEST SIMPLE DE CONNEXION');
  print('=' * 50);
  
  try {
    // Test 1: Initialisation
    print('\n📋 Test 1: Initialisation Supabase');
    print('-' * 50);
    await DatabaseService.initialize();
    print('✅ Supabase initialisé avec succès\n');
    
    // Test 2: Vérifier l'utilisateur actuel
    print('📋 Test 2: Vérification utilisateur');
    print('-' * 50);
    final user = DatabaseService.currentUser;
    if (user != null) {
      print('✅ Utilisateur connecté: ${user.email}');
    } else {
      print('ℹ️  Aucun utilisateur connecté');
    }
    
    print('\n' + '=' * 50);
    print('🎉 TEST TERMINÉ AVEC SUCCÈS');
    print('=' * 50);
    
  } catch (e, stackTrace) {
    print('\n❌ ERREUR: $e');
    print('Stack trace: $stackTrace');
  }
}
