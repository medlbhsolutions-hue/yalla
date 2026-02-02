import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/app_colors.dart';

class OSMMapWidget extends StatelessWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final MapController? mapController;
  final Function(LatLng)? onTap;

  const OSMMapWidget({
    super.key,
    required this.initialCenter,
    this.initialZoom = 13.0,
    this.markers = const [],
    this.polylines = const [],
    this.mapController,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onTap: (tapPosition, point) => onTap?.call(point),
        // Permet de détecter quand l'utilisateur déplace la carte
        onPositionChanged: (position, hasGesture) {
          // Utile pour la fonction 'Pick on Map'
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.yallatbib.app',
        ),
        if (polylines.isNotEmpty)
          PolylineLayer(
            polylines: polylines,
          ),
        if (markers.isNotEmpty)
          MarkerLayer(
            markers: markers,
          ),
      ],
    );
  }
}
