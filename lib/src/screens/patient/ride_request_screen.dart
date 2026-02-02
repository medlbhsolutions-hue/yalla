import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';

/// Écran de demande de course
class RideRequestScreen extends StatefulWidget {
  final String? transportType;

  const RideRequestScreen({super.key, this.transportType});

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();
  final _priceController = TextEditingController();
  
  String _selectedVehicleType = 'taxi';
  String _selectedPriority = 'medium';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    // Définir la priorité selon le type de transport
    if (widget.transportType == 'urgent') {
      _selectedPriority = 'urgent';
    }
    
    // Prix estimé par défaut
    _priceController.text = '50';
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Créer la demande de course
      final response = await _supabase.from('rides').insert({
        'patient_id': userId,
        'pickup_address': _pickupController.text.trim(),
        'destination_address': _destinationController.text.trim(),
        'vehicle_type': _selectedVehicleType,
        'priority': _selectedPriority,
        'estimated_price': double.tryParse(_priceController.text) ?? 50.0,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      if (!mounted) return;

      _showSuccess('Demande de course créée avec succès !');
      
      // Attendre un peu
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      
      // Retourner au dashboard
      Navigator.pop(context, response);

    } catch (e) {
      print('❌ Erreur création course: $e');
      _showError('Erreur lors de la création de la course');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nouvelle course',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Adresse de départ
              const Text(
                'Adresse de départ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pickupController,
                decoration: InputDecoration(
                  hintText: 'Où êtes-vous ?',
                  prefixIcon: const Icon(Icons.my_location, color: Color(0xFF4CAF50)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer l\'adresse de départ';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Destination
              const Text(
                'Destination',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: 'Où allez-vous ?',
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF4CAF50)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer la destination';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Type de véhicule
              const Text(
                'Type de véhicule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  _buildVehicleChip('taxi', 'Taxi', Icons.local_taxi),
                  _buildVehicleChip('ambulance', 'Ambulance', Icons.local_hospital),
                  _buildVehicleChip('vsl', 'VSL', Icons.airport_shuttle),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Priorité
              const Text(
                'Priorité',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  _buildPriorityChip('low', 'Normale', Colors.blue),
                  _buildPriorityChip('medium', 'Moyenne', Colors.orange),
                  _buildPriorityChip('high', 'Haute', Colors.deepOrange),
                  _buildPriorityChip('urgent', 'Urgente', Colors.red),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Prix proposé
              const Text(
                'Prix proposé (MAD)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Votre prix',
                  prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF4CAF50)),
                  suffixText: 'MAD',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un prix';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Prix invalide';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Notes
              const Text(
                'Notes (optionnel)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Informations supplémentaires...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Bouton de soumission
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Rechercher un chauffeur',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleChip(String value, String label, IconData icon) {
    final isSelected = _selectedVehicleType == value;
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : const Color(0xFF4CAF50),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedVehicleType = value;
        });
      },
      selectedColor: const Color(0xFF4CAF50),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _selectedPriority = value;
        });
      },
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
