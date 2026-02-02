import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/src/config/app_config.dart';

Future<void> main() async {
  print('👑 Création du compte ADMIN...');

  // Charger les variables
  await dotenv.load(fileName: "build/web/assets/.env"); 
  
  // Initialiser Supabase (avec la clé SERVICE ROLE si possible, sinon on triche)
  // Note: Pour créer un admin proprement, il faut idéalement la clé service_role ou le faire via l'interface Supabase.
  // Mais ici on va utiliser le client normal et hack le profil après.
  
  // ATTENTION: Ceci est un script utilitaire
  final supabaseUrl = AppConfig.supabaseUrl;
  final supabaseKey = AppConfig.supabaseAnonKey;
  
  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  final email = 'admin@yallatbib.com';
  final password = 'admin123456';

  try {
    // 1. Créer l'utilisateur (Signup)
    print('1. Tentative d\'inscription...');
    AuthResponse res;
    try {
      res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': 'Super',
          'last_name': 'Admin',
          'role': 'admin', // On tente de le passer ici
        }
      );
      print('✅ Compte créé avec succès ! ID: ${res.user?.id}');
    } catch (e) {
      print('ℹ️ Le compte existe peut-être déjà, on tente le login...');
       res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print('✅ Connecté au compte existant. ID: ${res.user?.id}');
    }

    final userId = res.user?.id;
    if (userId == null) throw Exception('Impossible de récupérer l\'ID utilisateur');

    // 2. Mettre à jour la table profiles pour forcer le rôle 'admin'
    // Note: Avec RLS activé, un utilisateur peut ne pas pouvoir changer son propre rôle.
    // C'est pourquoi on demande souvent de le faire via SQL Editor.
    // Mais on va tenter l'update au cas où les règles sont permissives sur "update own profile".
    
    print('2. Mise à jour du profil vers ADMIN...');
    await supabase.from('profiles').upsert({
      'id': userId,
      'email': email,
      'first_name': 'Super',
      'last_name': 'Admin',
      'role': 'admin', // LE PLUS IMPORTANT
      'created_at': DateTime.now().toIso8601String(),
    });

    print('✨ SUCCÈS ! Vous pouvez vous connecter avec :');
    print('📧 Email: $email');
    print('🔑 Pass : $password');

  } catch (e) {
    print('❌ Erreur: $e');
    print('⚠️ SI ÇA ECHOUE À CAUSE DES PERMISSIONS :');
    print('Allez dans Supabase > SQL Editor et exécutez :');
    print("UPDATE public.profiles SET role = 'admin' WHERE email = '$email';");
  }
}
