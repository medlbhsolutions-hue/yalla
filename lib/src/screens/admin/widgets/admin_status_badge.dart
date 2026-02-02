import 'package:flutter/material.dart';

/// Badge de statut coloré pour les listes admin
class AdminStatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const AdminStatusBadge({
    Key? key,
    required this.status,
    this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config['color'].withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'],
            size: 14,
            color: config['color'],
          ),
          const SizedBox(width: 6),
          Text(
            label ?? config['label'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: config['color'],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      // Statuts utilisateurs
      case 'active':
        return {
          'label': 'Actif',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'inactive':
        return {
          'label': 'Inactif',
          'color': Colors.grey,
          'icon': Icons.remove_circle,
        };
      
      // Statuts chauffeurs
      case 'verified':
        return {
          'label': 'Vérifié',
          'color': Colors.blue,
          'icon': Icons.verified,
        };
      case 'pending':
        return {
          'label': 'En attente',
          'color': Colors.orange,
          'icon': Icons.hourglass_empty,
        };
      case 'rejected':
        return {
          'label': 'Rejeté',
          'color': Colors.red,
          'icon': Icons.cancel,
        };
      
      // Statuts courses
      case 'accepted':
        return {
          'label': 'Acceptée',
          'color': Colors.blue,
          'icon': Icons.check,
        };
      case 'in_progress':
        return {
          'label': 'En cours',
          'color': Colors.purple,
          'icon': Icons.directions_car,
        };
      case 'completed':
        return {
          'label': 'Terminée',
          'color': Colors.green,
          'icon': Icons.done_all,
        };
      case 'cancelled':
        return {
          'label': 'Annulée',
          'color': Colors.red,
          'icon': Icons.close,
        };
      
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.info,
        };
    }
  }
}
