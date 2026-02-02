import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

// État d'authentification
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = AuthService();
  return authService.authStateChanges();
});

// Utilisateur courant
final currentUserProvider = Provider<User?>((ref) {
  final authService = AuthService();
  return authService.getCurrentUser();
});

// Profil utilisateur
final userProfileProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final authService = AuthService();
  return authService.getUserProfile(userId);
});

// Service d'authentification
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});