import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../onboarding_screens.dart'; // Pour le Reset de navigation

/// Sidebar de navigation pour l'administration
class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AdminSidebar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFF1A237E), // Deep Navy Blue
        child: Column(
          children: [
            // 🎭 HEADER PREMIUM ADMIN
            Container(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(50)),
              ),
              child: Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(3),
                     decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                     child: const CircleAvatar(
                       radius: 35,
                       backgroundColor: Colors.white,
                       child: Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFF1A237E)),
                     ),
                   ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YALLA L\'TBIB',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Espace Administration',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                children: [
                  _buildSidebarSection('SYSTÈME'),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    index: 0,
                    isSelected: selectedIndex == 0,
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.people_outline_rounded,
                    activeIcon: Icons.people_rounded,
                    title: 'Utilisateurs',
                    index: 1,
                    isSelected: selectedIndex == 1,
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.local_taxi_outlined,
                    activeIcon: Icons.local_taxi_rounded,
                    title: 'Courses',
                    index: 2,
                    isSelected: selectedIndex == 2,
                  ),
                  
                  const SizedBox(height: 25),
                  _buildSidebarSection('GESTION LIVE'),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map_rounded,
                    title: 'Carte Temps Réel',
                    index: 3,
                    isSelected: selectedIndex == 3,
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.analytics_outlined,
                    activeIcon: Icons.analytics_rounded,
                    title: 'Analytics Financiers',
                    index: 4,
                    isSelected: selectedIndex == 4,
                  ),

                  const SizedBox(height: 25),
                  _buildSidebarSection('CONFIGURATION'),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    title: 'Paramètres',
                    index: 5,
                    isSelected: selectedIndex == 5,
                  ),

                  const SizedBox(height: 25),
                  _buildSidebarSection('QUITTER'),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.exit_to_app_rounded,
                    activeIcon: Icons.exit_to_app_rounded,
                    title: 'Retour App Client',
                    index: 99,
                    isSelected: false,
                  ),
                ],
              ),
            ),

            // 🚪 BOUTON DÉCONNEXION
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('Déconnexion', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () => _showLogoutDialog(context),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, bottom: 10),
      child: Text(
        title,
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required int index,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: () {
          if (index == 99) {
            // 🔥 ACTION SPÉCIALE : QUITTER L'ADMIN
            Navigator.pop(context);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
              (route) => false,
            );
          } else {
            onItemSelected(index);
            Navigator.pop(context);
          }
        },
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? Colors.white : Colors.white60,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: isSelected 
          ? Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)))
          : const Icon(Icons.chevron_right, size: 18, color: Colors.white24),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Déconnexion Supabase
                await Supabase.instance.client.auth.signOut();
                
                if (context.mounted) {
                  // Fermer la dialog
                  Navigator.pop(context);
                  
                  // 🔥 RESET COMPLET ET RETOUR ACCUEIL
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                    (route) => false,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Déconnexion réussie'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur déconnexion: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
