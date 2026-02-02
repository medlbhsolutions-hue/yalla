import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/osm_service.dart';

/// Widget d'autocomplete pour les adresses (Version DIRECTE - Sans double fenêtre)
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? sessionToken;
  final Function(Map<String, dynamic>) onPlaceSelected;
  final LatLng? currentLocation;
  
  const AddressAutocompleteField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onPlaceSelected,
    this.sessionToken,
    this.currentLocation,
  }) : super(key: key);

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  List<Map<String, dynamic>> _predictions = [];
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => _predictions = []);
      return;
    }
    
    if (query.length >= 2) {
      _searchPlaces(query);
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    
    try {
      final predictions = await OSMService.getPlaceSuggestions(query);
      if (mounted) {
        setState(() {
          _predictions = predictions;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Champ de recherche stylisé (comme sur l'image)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: TextField(
            controller: widget.controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 22),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => widget.controller.clear(),
                        )
                      : null,
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF467DB0), width: 1.5),
              ),
            ),
          ),
        ),

        // Liste des résultats
        Expanded(
          child: _predictions.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _predictions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
                  itemBuilder: (context, index) {
                    final p = _predictions[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0F8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Color(0xFF467DB0), size: 20),
                      ),
                      title: Text(
                        p['main_text'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: Text(
                        p['secondary_text'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => widget.onPlaceSelected(p),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (widget.controller.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 100, color: Colors.grey[200]),
            const SizedBox(height: 20),
            Text('Tapez pour rechercher une adresse', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          ],
        ),
      );
    }
    return Center(
      child: Text('Aucun résultat trouvé', style: TextStyle(color: Colors.grey[500])),
    );
  }
}
