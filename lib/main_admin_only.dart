import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'src/services/database_service.dart';
import 'src/screens/admin/admin_login_screen_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 0. Initialiser les locales pour les dates en français
  print('🌍 Initialisation des locales...');
  await initializeDateFormatting('fr_FR', null);
  Intl.defaultLocale = 'fr_FR';
  print('✅ Locales initialisées');
  
  // 1. Initialiser Firebase
  print('🔥 Initialisation de Firebase...');
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyActf0CrnvkQfYAnA4j8vdP4ve9zH1WfWM",
        authDomain: "yalla-tbib.firebaseapp.com",
        projectId: "yalla-tbib",
        storageBucket: "yalla-tbib.firebasestorage.app",
        messagingSenderId: "809036133077",
        appId: "1:809036133077:web:3edf4d0d65568cdc40285c",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  print('✅ Firebase initialisé');
  
  // 2. Initialiser Supabase
  print('🔄 Initialisation de Supabase...');
  await DatabaseService.initialize();
  print('✅ Supabase initialisé');
  
  runApp(const AdminOnlyApp());
}

class AdminOnlyApp extends StatelessWidget {
  const AdminOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YALLA TBIB - Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AdminLoginScreenTest(),
    );
  }
}
