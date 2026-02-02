import 'package:flutter/material.dart';
import 'auth/signin_screen.dart';
import '../utils/app_colors.dart';

/// 🎨 Onboarding YALLA L'TBIB - Design "Tech & Glow" (Inspiré du Mockup)
/// Version Corrigée : Logo géant, pas de chevauchement, navigation fluide.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: "YALLA L'TBIB",
      desc: "L'excellence du transport médical\nà portée de main.",
      isLogo: true,
    ),
    OnboardingData(
      title: "TRAJET LIVE",
      desc: "Suivez votre ambulance en temps réel\nsous vos yeux.",
      isLogo: false,
      icon: Icons.location_searching_rounded,
    ),
    OnboardingData(
      title: "SÉCURITÉ",
      desc: "Un service certifié pour votre\nsérénité totale.",
      isLogo: false,
      icon: Icons.verified_user_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌊 FOND GRADIENT "GLOW"
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF0D504E), // Vert brillant au centre
                  Color(0xFF041C1B), // Vert très sombre aux bords
                ],
              ),
            ),
          ),

          // 📄 CONTENU DES PAGES
          PageView.builder(
            controller: _pageController,
            onPageChanged: (v) => setState(() => _currentPage = v),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    const Spacer(flex: 2), // Plus d'espace en haut pour remonter le tout
                    
                    // 🎯 LOGO GÉANT (AGRANDI)
                    if (_pages[index].isLogo)
                      Container(
                        padding: const EdgeInsets.all(35),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4AC2B2).withOpacity(0.5),
                              blurRadius: 80,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo_yalla_tbib.png',
                          height: 220, // Encore plus grand (était 160)
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4AC2B2).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_pages[index].icon, size: 120, color: const Color(0xFF4AC2B2)),
                      ),
                    
                    const SizedBox(height: 60),
                    
                    // Titre
                    Text(
                      _pages[index].title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // Description
                    Text(
                      _pages[index].desc,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.6,
                        letterSpacing: 0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 100), // Espace réservé pour le bouton (plus sûr que Spacer)
                  ],
                ),
              );
            },
          ),

          // 🔘 BOUTON ACTION & INDICATEURS (Fixes en bas)
          Positioned(
            bottom: 50,
            left: 40,
            right: 40,
            child: Column(
              children: [
                // Bouton SUIVANT
                GestureDetector(
                  onTap: () {
                    if (_currentPage < 2) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SignInScreen()),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: Center(
                      child: Text(
                        _currentPage == 2 ? 'COMMENCER' : 'SUIVANT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Indicateurs (Clickables pour switcher aussi)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => GestureDetector(
                    onTap: () => _pageController.animateToPage(
                      index, 
                      duration: const Duration(milliseconds: 500), 
                      curve: Curves.easeInOut
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: index == _currentPage ? 24 : 8,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: index == _currentPage ? const Color(0xFF4AC2B2) : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String desc;
  final bool isLogo;
  final IconData? icon;

  OnboardingData({
    required this.title,
    required this.desc,
    required this.isLogo,
    this.icon,
  });
}
