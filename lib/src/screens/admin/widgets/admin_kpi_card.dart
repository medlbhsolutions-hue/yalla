import 'package:flutter/material.dart';

/// Carte KPI réutilisable pour le dashboard admin
class AdminKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const AdminKpiCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = const Color(0xFF4CAF50),
    this.subtitle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12), // Réduit de 20 à 12
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Important : taille minimale
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), // Réduit de 12 à 8
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24, // Réduit de 28 à 24
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14, // Réduit de 16 à 14
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
              const SizedBox(height: 8), // Réduit de 16 à 8
              Flexible( // Ajout de Flexible
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12, // Réduit de 14 à 12
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2, // Limite à 2 lignes
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4), // Réduit de 8 à 4
              Flexible( // Ajout de Flexible
                child: FittedBox( // Ajout de FittedBox pour adapter la taille
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24, // Réduit de 28 à 24
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2), // Réduit de 4 à 2
                Flexible( // Ajout de Flexible
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10, // Réduit de 12 à 10
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
