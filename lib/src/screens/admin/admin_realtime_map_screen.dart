import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/osm_map_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yalla_tbib_flutter/src/utils/app_colors.dart';

class AdminRealtimeMapScreen extends StatefulWidget {
  const AdminRealtimeMapScreen({Key? key}) : super(key: key);

  @override
  State<AdminRealtimeMapScreen> createState() => _AdminRealtimeMapScreenState();
}

class _AdminRealtimeMapScreenState extends State<AdminRealtimeMapScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  
  // Marqueurs
  final List<Marker> _markers = [];
  
  // Stats temps réel
  int _activeDrivers = 0;
  int _activeRides = 0;

  LatLng? _centerPosition = const LatLng(31.7917, -7.0926); // Centre Maroc

  StreamSubscription? _driverLocationsSubscription;
  StreamSubscription? _ridesSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToDriverLocations();
    _subscribeToActiveRides();
  }

  @override
  void dispose() {
    _driverLocationsSubscription?.cancel();
    _ridesSubscription?.cancel();
    super.dispose();
  }

  // 1. Écouter les positions des chauffeurs
  void _subscribeToDriverLocations() {
    _driverLocationsSubscription = _supabase
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .listen((List<Map<String, dynamic>> data) {
      if (!mounted) return;

      setState(() {
        _activeDrivers = data.length;
        _markers.clear();
        for (var loc in data) {
          final driverId = loc['driver_id'];
          if (loc['lat'] == null || loc['lng'] == null) continue;
          
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          
          final lastUpdate = DateTime.parse(loc['updated_at']);
          if (DateTime.now().difference(lastUpdate).inMinutes > 30) continue;

          _markers.add(Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            child: Icon(
                Icons.directions_car, 
                color: Colors.blue,
                size: 30
            ),
          ));
        }
      });
    });
  }

  // 2. Écouter les courses en cours
  void _subscribeToActiveRides() {
    _ridesSubscription = _supabase
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'in_progress')
        .listen((List<Map<String, dynamic>> data) {
       if (!mounted) return;
       
       setState(() {
         _activeRides = data.length;
         // On pourrait ajouter des marqueurs pour les destinations des courses
         // Pour l'instant on se concentre sur les chauffeurs
       });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
          // CARTE
          OSMMapWidget(
            initialCenter: _centerPosition!,
            initialZoom: 6,
            mapController: _mapController,
            markers: _markers,
          ),
          
          // SURCOUCHE INFOS
          Positioned(
            top: 16,
            left: 16,
            child: _buildStatsCard(),
          ),

          // LÉGENDE
          Positioned(
            bottom: 16,
            left: 16,
            child: _buildLegend(),
          ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            '📡 Supervision Temps Réel',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem(Icons.local_taxi, 'Chauffeurs', _activeDrivers, Colors.blue),
              const SizedBox(width: 16),
              _buildStatItem(Icons.sync_alt, 'Courses', _activeRides, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count.toString(), 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, 
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegendItem(Colors.blue, 'Chauffeur En ligne'),
          const SizedBox(height: 4),
          _buildLegendItem(Colors.red, 'Chauffeur Hors ligne (Récents)'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
