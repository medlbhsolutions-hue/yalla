import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/address_autocomplete_field.dart';

/// Écran de test ULTRA SIMPLE pour l'autocomplétion
class TestAutocompleteScreen extends StatefulWidget {
  const TestAutocompleteScreen({Key? key}) : super(key: key);

  @override
  State<TestAutocompleteScreen> createState() => _TestAutocompleteScreenState();
}

class _TestAutocompleteScreenState extends State<TestAutocompleteScreen> {
  final TextEditingController _testController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('═══════════════════════════════════════════════');
    print('🧪 TEST AUTOCOMPLETE SCREEN INITIALISÉ');
    print('═══════════════════════════════════════════════');
  }

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 TestAutocompleteScreen build()');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Test Autocomplétion'),
        backgroundColor: const Color(0xFF467DB0),
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.science, size: 48, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Test Widget Autocomplétion',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tapez "casa" ci-dessous',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Widget à tester
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📍 Champ de Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // WIDGET À TESTER
                    AddressAutocompleteField(
                      controller: _testController,
                      label: 'Tapez une adresse',
                      hint: 'Ex: casa, ibn sina, aéroport...',
                      icon: Icons.search,
                      sessionToken: 'test-session-123',
                      currentLocation: const LatLng(33.5731, -7.5898), // Casablanca
                      onPlaceSelected: (place) {
                        print('═══════════════════════════════════════════════');
                        print('✅ LIEU SÉLECTIONNÉ:');
                        print('   Nom: ${place['name']}');
                        print('   Adresse: ${place['formatted_address']}');
                        print('   GPS: ${place['lat']}, ${place['lng']}');
                        print('═══════════════════════════════════════════════');
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ ${place['name']} sélectionné!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '📋 Instructions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('1. Ouvrez DevTools (F12)'),
                    Text('2. Allez sur l\'onglet Console'),
                    Text('3. Tapez "casa" dans le champ ci-dessus'),
                    Text('4. Observez les logs dans la console'),
                    Text('5. Vérifiez si une liste verte apparaît'),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Bouton de test manuel
              ElevatedButton.icon(
                onPressed: () {
                  print('═══════════════════════════════════════════════');
                  print('🧪 TEST MANUEL DÉCLENCHÉ');
                  print('   Texte actuel: "${_testController.text}"');
                  print('   Longueur: ${_testController.text.length}');
                  print('═══════════════════════════════════════════════');
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Afficher Info Debug'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
