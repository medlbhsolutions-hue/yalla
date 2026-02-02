import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/locale_helper.dart';
import '../../services/admin_service.dart';
import 'widgets/admin_status_badge.dart';

/// Écran de monitoring et gestion des courses
class AdminRidesScreen extends StatefulWidget {
  const AdminRidesScreen({Key? key}) : super(key: key);

  @override
  State<AdminRidesScreen> createState() => _AdminRidesScreenState();
}

class _AdminRidesScreenState extends State<AdminRidesScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool _isLoading = true;

  // Filtres
  String? _statusFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);

    try {
      final rides = await AdminService.getRides(
        statusFilter: _statusFilter,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _rides = rides;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement courses: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRide(String rideId) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Raison de l\'annulation:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Ex: Problème technique, demande client...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminService.cancelRide(
        rideId,
        reasonController.text.isNotEmpty ? reasonController.text : 'Annulation admin',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Course annulée'),
            backgroundColor: Colors.red,
          ),
        );
        _loadRides();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de filtres
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Première ligne : Statut
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _statusFilter,
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        prefixIcon: const Icon(Icons.filter_list, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tous')),
                        DropdownMenuItem(value: 'pending', child: Text('En attente')),
                        DropdownMenuItem(value: 'accepted', child: Text('Acceptées')),
                        DropdownMenuItem(value: 'in_progress', child: Text('En cours')),
                        DropdownMenuItem(value: 'completed', child: Text('Terminées')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Annulées')),
                      ],
                      onChanged: (value) {
                        setState(() => _statusFilter = value);
                        _loadRides();
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Deuxième ligne : Dates et actions
              Row(
                children: [
                  // Date début
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                          _loadRides();
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _startDate != null
                            ? LocaleHelper.formatDateSafe(_startDate!, pattern: 'dd/MM/yy')
                            : 'Début',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Date fin
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                          _loadRides();
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _endDate != null
                            ? LocaleHelper.formatDateSafe(_endDate!, pattern: 'dd/MM/yy')
                            : 'Fin',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),

                  // Bouton effacer
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _statusFilter = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadRides();
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Effacer',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Bouton actualiser
                  ElevatedButton(
                    onPressed: _loadRides,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Statistiques rapides
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.blue.shade100, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('Total', _rides.length, Colors.blue),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade300,
              ),
              _buildQuickStat(
                'Actives',
                _rides.where((r) => ['pending', 'accepted', 'in_progress'].contains(r['status'])).length,
                Colors.orange,
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade300,
              ),
              _buildQuickStat(
                'Terminées',
                _rides.where((r) => r['status'] == 'completed').length,
                Colors.green,
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.shade300,
              ),
              _buildQuickStat(
                'Annulées',
                _rides.where((r) => r['status'] == 'cancelled').length,
                Colors.red,
              ),
            ],
          ),
        ),

        // Liste des courses
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4CAF50),
                  ),
                )
              : _rides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_taxi,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune course trouvée',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rides.length,
                      itemBuilder: (context, index) {
                        final ride = _rides[index];
                        return _buildRideCard(ride);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final createdAt = ride['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ride['created_at']))
        : '-';

    // Infos patient
    final patient = ride['patient'];
    final patientUser = patient?['users'];
    final patientName = patientUser != null
        ? '${patientUser['first_name']} ${patientUser['last_name']}'
        : 'Patient inconnu';

    // Infos driver
    final driver = ride['driver'];
    final driverUser = driver?['users'];
    final driverName = driverUser != null
        ? '${driverUser['first_name']} ${driverUser['last_name']}'
        : 'Aucun chauffeur';

    final status = ride['status'] ?? 'unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Course #${ride['id'].toString().substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AdminStatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ride['final_price'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      '${ride['final_price']} DH',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Détails trajet
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.circle,
                        'Départ',
                        ride['pickup_address'] ?? '-',
                        Colors.blue,
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        Icons.location_on,
                        'Destination',
                        ride['destination_address'] ?? '-',
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Infos utilisateurs
            Row(
              children: [
                Expanded(
                  child: _buildUserChip(
                    Icons.person,
                    'Patient',
                    patientName,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUserChip(
                    Icons.drive_eta,
                    'Chauffeur',
                    driverName,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            // Infos complémentaires
            if (ride['ride_type'] != null || ride['distance_km'] != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (ride['ride_type'] != null)
                    _buildInfoChip(
                      Icons.medical_services,
                      ride['ride_type'].toString().toUpperCase(),
                    ),
                  if (ride['distance_km'] != null)
                    _buildInfoChip(
                      Icons.route,
                      '${ride['distance_km']} km',
                    ),
                  if (ride['duration_minutes'] != null)
                    _buildInfoChip(
                      Icons.timer,
                      '${ride['duration_minutes']} min',
                    ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status != 'cancelled' && status != 'completed')
                  OutlinedButton.icon(
                    onPressed: () => _cancelRide(ride['id']),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showRideDetails(ride),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Détails'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserChip(IconData icon, String label, String name, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _showRideDetails(Map<String, dynamic> ride) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails Course #${ride['id'].toString().substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Statut', ride['status'] ?? '-'),
              _buildDetailRow('Type', ride['ride_type'] ?? '-'),
              _buildDetailRow('Prix estimé', '${ride['estimated_price'] ?? 0} DH'),
              _buildDetailRow('Prix final', '${ride['final_price'] ?? 0} DH'),
              _buildDetailRow('Distance', '${ride['distance_km'] ?? 0} km'),
              _buildDetailRow('Durée', '${ride['duration_minutes'] ?? 0} min'),
              _buildDetailRow('Départ', ride['pickup_address'] ?? '-'),
              _buildDetailRow('Destination', ride['destination_address'] ?? '-'),
              if (ride['cancellation_reason'] != null)
                _buildDetailRow('Raison annulation', ride['cancellation_reason']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
