import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

/// Écran d'historique complet des courses chauffeur avec filtres et détails
class DriverRidesHistoryScreen extends StatefulWidget {
  final Map<String, dynamic>? driverProfile;

  const DriverRidesHistoryScreen({Key? key, this.driverProfile}) : super(key: key);

  @override
  State<DriverRidesHistoryScreen> createState() => _DriverRidesHistoryScreenState();
}

class _DriverRidesHistoryScreenState extends State<DriverRidesHistoryScreen> {
  List<Map<String, dynamic>> _allRides = [];
  List<Map<String, dynamic>> _filteredRides = [];
  
  bool _isLoading = true;
  
  // Filtres
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  
  final List<String> _statusFilters = [
    'all',
    'completed',
    'in_progress',
    'cancelled',
    'pending',
  ];
  
  final Map<String, String> _statusLabels = {
    'all': 'Toutes',
    'completed': 'Terminées',
    'in_progress': 'En cours',
    'cancelled': 'Annulées',
    'pending': 'En attente',
  };

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    if (widget.driverProfile == null) {
      print('❌ HISTORIQUE DRIVER: Profil driver NULL - impossible de charger les courses');
      return;
    }
    
    print('🔍 HISTORIQUE DRIVER: Chargement des courses pour driver_id: ${widget.driverProfile!['id']}');
    
    setState(() { _isLoading = true; });
    
    try {
      final rides = await DatabaseService.getDriverRides(
        driverId: widget.driverProfile!['id'],
        limit: 1000,
      );
      
      print('✅ HISTORIQUE DRIVER: ${rides.length} courses récupérées depuis Supabase');
      
      if (rides.isEmpty) {
        print('⚠️ HISTORIQUE DRIVER: Aucune course trouvée pour ce chauffeur');
        print('💡 SOLUTION: Insérer une course test avec driver_id = ${widget.driverProfile!['id']}');
      }
      
      setState(() {
        _allRides = rides;
        _applyFilters();
        _isLoading = false;
      });
      
      print('📊 HISTORIQUE DRIVER: ${_filteredRides.length} courses après filtres');
    } catch (e) {
      print('❌ Erreur chargement historique driver: $e');
      setState(() { _isLoading = false; });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allRides);
    
    // Filtre par statut
    if (_selectedStatus != 'all') {
      filtered = filtered.where((r) => r['status'] == _selectedStatus).toList();
    }
    
    // Filtre par date
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((r) {
        if (r['created_at'] == null) return false;
        
        try {
          DateTime rideDate = DateTime.parse(r['created_at']);
          
          if (_startDate != null && rideDate.isBefore(_startDate!)) {
            return false;
          }
          
          if (_endDate != null && rideDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
            return false;
          }
          
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    // Trier par date décroissante
    filtered.sort((a, b) {
      try {
        DateTime dateA = DateTime.parse(a['created_at'] ?? '');
        DateTime dateB = DateTime.parse(b['created_at'] ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });
    
    setState(() {
      _filteredRides = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Historique des courses',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF4CAF50)),
            onPressed: _showFiltersDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : Column(
              children: [
                // Barre de filtres actifs
                _buildActiveFiltersBar(),
                
                // Statistiques rapides
                _buildQuickStats(),
                
                // Liste des courses
                Expanded(
                  child: _filteredRides.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadRides,
                          color: const Color(0xFF4CAF50),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredRides.length,
                            itemBuilder: (context, index) =>
                                _buildRideCard(_filteredRides[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildActiveFiltersBar() {
    bool hasFilters = _selectedStatus != 'all' || _startDate != null || _endDate != null;
    
    if (!hasFilters) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 20, color: Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_selectedStatus != 'all')
                  _buildFilterChip(
                    label: _statusLabels[_selectedStatus]!,
                    onDeleted: () {
                      setState(() {
                        _selectedStatus = 'all';
                        _applyFilters();
                      });
                    },
                  ),
                if (_startDate != null)
                  _buildFilterChip(
                    label: 'Du ${DateFormat('dd/MM/yy').format(_startDate!)}',
                    onDeleted: () {
                      setState(() {
                        _startDate = null;
                        _applyFilters();
                      });
                    },
                  ),
                if (_endDate != null)
                  _buildFilterChip(
                    label: 'Au ${DateFormat('dd/MM/yy').format(_endDate!)}',
                    onDeleted: () {
                      setState(() {
                        _endDate = null;
                        _applyFilters();
                      });
                    },
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = 'all';
                _startDate = null;
                _endDate = null;
                _applyFilters();
              });
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onDeleted}) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onDeleted: onDeleted,
      deleteIconColor: Colors.red,
      backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
      labelStyle: const TextStyle(color: Color(0xFF4CAF50)),
    );
  }

  Widget _buildQuickStats() {
    int completed = _filteredRides.where((r) => r['status'] == 'completed').length;
    double totalEarnings = _filteredRides
        .where((r) => r['status'] == 'completed' && r['total_price'] != null)
        .fold(0.0, (sum, r) => sum + ((r['total_price'] as num).toDouble() * 0.9)); // 90% pour le driver
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStatItem(
            icon: Icons.directions_car,
            label: 'Total',
            value: _filteredRides.length.toString(),
            color: Colors.blue,
          ),
          _buildQuickStatItem(
            icon: Icons.check_circle,
            label: 'Terminées',
            value: completed.toString(),
            color: Colors.green,
          ),
          _buildQuickStatItem(
            icon: Icons.payments,
            label: 'Revenus',
            value: '${totalEarnings.toStringAsFixed(0)} DH',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucune course trouvée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier les filtres',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    String status = ride['status'] ?? 'pending';
    IconData statusIcon;
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Terminée';
        break;
      case 'in_progress':
        statusIcon = Icons.local_taxi;
        statusColor = Colors.blue;
        statusText = 'En cours';
        break;
      case 'cancelled':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        statusText = 'Annulée';
        break;
      default:
        statusIcon = Icons.schedule;
        statusColor = Colors.orange;
        statusText = 'En attente';
    }
    
    String dateStr = 'Date inconnue';
    if (ride['created_at'] != null) {
      try {
        DateTime date = DateTime.parse(ride['created_at']);
        dateStr = DateFormat('EEEE dd MMMM yyyy à HH:mm', 'fr_FR').format(date);
      } catch (e) {
        dateStr = ride['created_at'].toString();
      }
    }
    
    // Revenu net (90%)
    double netEarnings = 0.0;
    if (ride['total_price'] != null && status == 'completed') {
      netEarnings = (ride['total_price'] as num).toDouble() * 0.9;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showRideDetails(ride),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride['destination_address'] ?? 'Destination inconnue',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Patient: ${ride['patient_name'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        status == 'completed' 
                          ? '${netEarnings.toStringAsFixed(0)} DH'
                          : '${ride['total_price'] ?? 0} DH',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      if (status == 'completed')
                        Text(
                          'Net',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (ride['distance_km'] != null || ride['duration_minutes'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      if (ride['distance_km'] != null) ...[
                        Icon(Icons.route, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${(ride['distance_km'] as num).toStringAsFixed(1)} km',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                      if (ride['distance_km'] != null && ride['duration_minutes'] != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 1,
                          height: 16,
                          color: Colors.grey[300],
                        ),
                      if (ride['duration_minutes'] != null) ...[
                        Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${ride['duration_minutes']} min',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRideDetails(Map<String, dynamic> ride) {
    double totalPrice = ride['total_price'] != null ? (ride['total_price'] as num).toDouble() : 0.0;
    double commission = totalPrice * 0.1;
    double netEarnings = totalPrice * 0.9;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Détails de la course',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            
            _buildDetailSection(
              title: 'Informations générales',
              icon: Icons.info_outline,
              items: [
                _buildDetailItem('Patient', ride['patient_name'] ?? '-'),
                _buildDetailItem('Destination', ride['destination_address'] ?? '-'),
                _buildDetailItem('Départ', ride['pickup_address'] ?? '-'),
                _buildDetailItem('Statut', ride['status'] ?? '-'),
                _buildDetailItem('Date', _formatDateTime(ride['created_at'])),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildDetailSection(
              title: 'Détails du trajet',
              icon: Icons.route,
              items: [
                _buildDetailItem('Distance', '${ride['distance_km'] ?? 0} km'),
                _buildDetailItem('Durée', '${ride['duration_minutes'] ?? 0} minutes'),
                _buildDetailItem('Prix total', '${totalPrice.toStringAsFixed(0)} DH'),
                _buildDetailItem('Commission (10%)', '${commission.toStringAsFixed(0)} DH'),
                _buildDetailItem('Votre revenu', '${netEarnings.toStringAsFixed(0)} DH', isHighlight: true),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (ride['driver_rating'] != null)
              _buildDetailSection(
                title: 'Note du patient',
                icon: Icons.star,
                items: [
                  _buildDetailItem('Note reçue', '${ride['driver_rating']} ⭐'),
                ],
              ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Fermer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? const Color(0xFF4CAF50) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy à HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtres',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              
              const Text('Statut', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusFilters.map((status) {
                  bool isSelected = _selectedStatus == status;
                  return ChoiceChip(
                    label: Text(_statusLabels[status]!),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        _selectedStatus = status;
                      });
                    },
                    selectedColor: const Color(0xFF4CAF50),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setModalState(() { _startDate = date; });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_startDate == null
                        ? 'Date début'
                        : DateFormat('dd/MM/yy').format(_startDate!)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setModalState(() { _endDate = date; });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_endDate == null
                        ? 'Date fin'
                        : DateFormat('dd/MM/yy').format(_endDate!)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedStatus = 'all';
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() { _applyFilters(); });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
