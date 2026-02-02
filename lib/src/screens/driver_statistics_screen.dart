import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';

/// Écran des statistiques et graphiques pour le chauffeur
class DriverStatisticsScreen extends StatefulWidget {
  final Map<String, dynamic>? driverProfile;

  const DriverStatisticsScreen({Key? key, this.driverProfile}) : super(key: key);

  @override
  State<DriverStatisticsScreen> createState() => _DriverStatisticsScreenState();
}

class _DriverStatisticsScreenState extends State<DriverStatisticsScreen> {
  List<Map<String, dynamic>> _allRides = [];
  bool _isLoading = true;
  
  // Statistiques globales
  int _totalRides = 0;
  int _completedRides = 0;
  double _totalEarnings = 0.0; // Net (90%)
  double _averageEarnings = 0.0;
  double _averageRating = 0.0;
  double _completionRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (widget.driverProfile == null) return;
    
    setState(() { _isLoading = true; });
    
    try {
      final rides = await DatabaseService.getDriverRides(
        driverId: widget.driverProfile!['id'],
        limit: 1000,
      );
      
      setState(() {
        _allRides = rides;
        _calculateStatistics();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement statistiques driver: $e');
      setState(() { _isLoading = false; });
    }
  }

  void _calculateStatistics() {
    _totalRides = _allRides.length;
    _completedRides = _allRides.where((r) => r['status'] == 'completed').length;
    
    if (_totalRides > 0) {
      _completionRate = (_completedRides / _totalRides) * 100;
    }
    
    List<Map<String, dynamic>> completedWithPrice = _allRides
        .where((r) => r['status'] == 'completed' && r['total_price'] != null)
        .toList();
    
    if (completedWithPrice.isNotEmpty) {
      _totalEarnings = completedWithPrice.fold(
        0.0,
        (sum, r) => sum + ((r['total_price'] as num).toDouble() * 0.9), // 90% pour le driver
      );
      _averageEarnings = _totalEarnings / completedWithPrice.length;
    }
    
    List<Map<String, dynamic>> ratedRides = _allRides
        .where((r) => r['driver_rating'] != null)
        .toList();
    
    if (ratedRides.isNotEmpty) {
      _averageRating = ratedRides.fold(
        0.0,
        (sum, r) => sum + ((r['driver_rating'] as num).toDouble()),
      ) / ratedRides.length;
    }
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
          'Statistiques',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              color: const Color(0xFF4CAF50),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistiques principales
                    _buildMainStatsGrid(),
                    
                    const SizedBox(height: 24),
                    
                    // Graphique Pie: Répartition par statut
                    _buildSectionTitle('Répartition des courses', Icons.pie_chart),
                    const SizedBox(height: 12),
                    _buildRidesDistributionChart(),
                    
                    const SizedBox(height: 24),
                    
                    // Graphique Bar: Courses par mois
                    _buildSectionTitle('Courses par mois', Icons.bar_chart),
                    const SizedBox(height: 12),
                    _buildRidesPerMonthChart(),
                    
                    const SizedBox(height: 24),
                    
                    // Graphique Line: Revenus par mois
                    _buildSectionTitle('Revenus par mois', Icons.show_chart),
                    const SizedBox(height: 12),
                    _buildEarningsPerMonthChart(),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMainStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          icon: Icons.directions_car,
          label: 'Total courses',
          value: _totalRides.toString(),
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.check_circle,
          label: 'Terminées',
          value: _completedRides.toString(),
          color: Colors.green,
        ),
        _buildStatCard(
          icon: Icons.payments,
          label: 'Revenus totaux',
          value: '${_totalEarnings.toStringAsFixed(0)} DH',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.trending_up,
          label: 'Revenu moyen',
          value: '${_averageEarnings.toStringAsFixed(0)} DH',
          color: Colors.purple,
        ),
        _buildStatCard(
          icon: Icons.star,
          label: 'Note moyenne',
          value: _averageRating.toStringAsFixed(1),
          color: Colors.amber,
        ),
        _buildStatCard(
          icon: Icons.percent,
          label: 'Taux complétion',
          value: '${_completionRate.toStringAsFixed(1)}%',
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRidesDistributionChart() {
    Map<String, int> statusCounts = {
      'completed': _allRides.where((r) => r['status'] == 'completed').length,
      'in_progress': _allRides.where((r) => r['status'] == 'in_progress').length,
      'cancelled': _allRides.where((r) => r['status'] == 'cancelled').length,
      'pending': _allRides.where((r) => r['status'] == 'pending').length,
    };
    
    int total = statusCounts.values.reduce((a, b) => a + b);
    
    if (total == 0) {
      return _buildEmptyChartMessage();
    }
    
    return Container(
      height: 250,
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
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sections: [
                  if (statusCounts['completed']! > 0)
                    PieChartSectionData(
                      value: statusCounts['completed']!.toDouble(),
                      title: '${((statusCounts['completed']! / total) * 100).toStringAsFixed(0)}%',
                      color: Colors.green,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (statusCounts['in_progress']! > 0)
                    PieChartSectionData(
                      value: statusCounts['in_progress']!.toDouble(),
                      title: '${((statusCounts['in_progress']! / total) * 100).toStringAsFixed(0)}%',
                      color: Colors.blue,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (statusCounts['cancelled']! > 0)
                    PieChartSectionData(
                      value: statusCounts['cancelled']!.toDouble(),
                      title: '${((statusCounts['cancelled']! / total) * 100).toStringAsFixed(0)}%',
                      color: Colors.red,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (statusCounts['pending']! > 0)
                    PieChartSectionData(
                      value: statusCounts['pending']!.toDouble(),
                      title: '${((statusCounts['pending']! / total) * 100).toStringAsFixed(0)}%',
                      color: Colors.orange,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 0,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem('Terminées', Colors.green, statusCounts['completed']!),
                _buildLegendItem('En cours', Colors.blue, statusCounts['in_progress']!),
                _buildLegendItem('Annulées', Colors.red, statusCounts['cancelled']!),
                _buildLegendItem('En attente', Colors.orange, statusCounts['pending']!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label ($count)',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Convertit une date en format "Jan 25" sans DateFormat (évite problèmes de locale)
  String _formatMonthYear(DateTime date) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 
                    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${months[date.month - 1]} ${date.year.toString().substring(2)}';
  }

  Widget _buildRidesPerMonthChart() {
    Map<String, int> ridesPerMonth = {};
    
    DateTime now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      String key = _formatMonthYear(month);
      ridesPerMonth[key] = 0;
    }
    
    for (var ride in _allRides) {
      if (ride['created_at'] != null) {
        try {
          DateTime date = DateTime.parse(ride['created_at']);
          String key = _formatMonthYear(date);
          if (ridesPerMonth.containsKey(key)) {
            ridesPerMonth[key] = ridesPerMonth[key]! + 1;
          }
        } catch (e) {
          // Ignore invalid dates
        }
      }
    }
    
    double maxY = ridesPerMonth.values.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxY == 0) maxY = 10;
    
    return Container(
      height: 250,
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
      child: BarChart(
        BarChartData(
          maxY: maxY + 5,
          barGroups: ridesPerMonth.entries.map((entry) {
            int index = ridesPerMonth.keys.toList().indexOf(entry.key);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  color: const Color(0xFF4CAF50),
                  width: 24,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < ridesPerMonth.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        ridesPerMonth.keys.toList()[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsPerMonthChart() {
    Map<String, double> earningsPerMonth = {};
    
    DateTime now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      String key = _formatMonthYear(month);
      earningsPerMonth[key] = 0.0;
    }
    
    for (var ride in _allRides) {
      if (ride['created_at'] != null && 
          ride['status'] == 'completed' && 
          ride['total_price'] != null) {
        try {
          DateTime date = DateTime.parse(ride['created_at']);
          String key = _formatMonthYear(date);
          if (earningsPerMonth.containsKey(key)) {
            double netEarning = (ride['total_price'] as num).toDouble() * 0.9;
            earningsPerMonth[key] = earningsPerMonth[key]! + netEarning;
          }
        } catch (e) {
          // Ignore invalid data
        }
      }
    }
    
    double maxY = earningsPerMonth.values.isEmpty 
        ? 1000 
        : earningsPerMonth.values.reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 1000;
    
    return Container(
      height: 250,
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
      child: LineChart(
        LineChartData(
          maxY: maxY + 500,
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: earningsPerMonth.entries.map((entry) {
                int index = earningsPerMonth.keys.toList().indexOf(entry.key);
                return FlSpot(index.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.orange,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withOpacity(0.2),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value / 1000).toStringAsFixed(0)}K',
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < earningsPerMonth.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        earningsPerMonth.keys.toList()[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChartMessage() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Aucune donnée disponible',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
