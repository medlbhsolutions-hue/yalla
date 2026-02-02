import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/professional/professional_main_screen.dart';
import '../screens/patient/patient_dashboard.dart';
import '../screens/driver/driver_dashboard.dart';
import '../screens/auth/auth_screen.dart';
import '../providers/auth_provider.dart';

class AuthRedirect extends ConsumerWidget {
  const AuthRedirect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        if (state.event == AuthChangeEvent.signedIn) {
          return FutureBuilder(
            future: ref.read(authServiceProvider).getUserProfile(state.session!.user.id),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final userData = snapshot.data as Map<String, dynamic>;
                final userType = userData['user_type'] as String;

                switch (userType) {
                  case 'admin':
                    return const AdminDashboard();
                  case 'professional':
                    return const ProfessionalMainScreen();
                  case 'patient':
                    return const PatientDashboard();
                  case 'driver':
                    return const DriverDashboard();
                  default:
                    return const AuthenticationScreen();
                }
              }
              
              // Pendant le chargement des données utilisateur
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          );
        }
        
        // Non connecté
        return const AuthenticationScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const AuthenticationScreen(),
    );
  }
}