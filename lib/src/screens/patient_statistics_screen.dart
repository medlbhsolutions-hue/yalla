import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

/// Écran de statistiques détaillées avec graphiques et analyses
class PatientStatisticsScreen extends StatefulWidget {
  final Map<String, dynamic>? patientProfile;

  const PatientStatisticsScreen({Key? key, this.patientProfile}) : super(key: key);

  @override
  State<PatientStatisticsScreen> createState() => _PatientStatisticsScreenState();
}

class _PatientStatisticsScreenState extends State<PatientStatisticsScreen> {
  bool _isLoading = true;
  
  // Statistiques globales
  int _totalRides = 0;
  int _completedRides = 0;
  int _cancelledRides = 0;
  double _totalSpent = 0.0;
  double _averagePrice = 0.0;
  double _averageDistance = 0.0;
  double _averageRating = 0.0;
  
  // Données pour graphiques
  Map<String, int> _ridesByMonth = {};
  Map<String, double> _spendingByMonth = {};
  
  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (widget.patientProfile == null) return;
    
    setState(() { _isLoading = true; });
    
    try {
      final rides = await DatabaseService.getPatientRides(
        patientId: widget.patientProfile!['id'],
        limit: 1000, // Charger toutes les courses (maximum 1000)
      );
      
      // Calculer statistiques
      int total = rides.length;
      int completed = 0;
      int cancelled = 0;
      double totalSpent = 0.0;
      double totalDistance = 0.0;
      double totalRating = 0.0;
      int ratedRides = 0;
      int ridesWithDistance = 0;
      
      Map<String, int> byMonth = {};
      Map<String, double> spendingByMonth = {};
      
      for (var ride in rides) {
        String status = ride['status'] ?? 'pending';
        
        if (status == 'completed') {
          completed++;
          
          // Total dépensé
          if (ride['total_price'] != null) {
            double price = (ride['total_price'] as num).toDouble();
            totalSpent += price;
            
            // Dépenses par mois
            if (ride['created_at'] != null) {
              try {
                DateTime date = DateTime.parse(ride['created_at']);
                String monthKey = DateFormat('MM/yyyy').format(date);
                spendingByMonth[monthKey] = (spendingByMonth[monthKey] ?? 0.0) + price;
              } catch (e) {}
            }
          }
          
          // Distance moyenne
          if (ride['distance_km'] != null) {
            totalDistance += (ride['distance_km'] as num).toDouble();
            ridesWithDistance++;
          }
          
          // Note moyenne
          if (ride['patient_rating'] != null) {
            totalRating += (ride['patient_rating'] as num).toDouble();
            ratedRides++;
          }
        } else if (status == 'cancelled') {
          cancelled++;
        }
        
        // Courses par mois
        if (ride['created_at'] != null) {
          try {
            DateTime date = DateTime.parse(ride['created_at']);
            String monthKey = DateFormat('MM/yyyy').format(date);
            byMonth[monthKey] = (byMonth[monthKey] ?? 0) + 1;
          } catch (e) {}
        }
      }
      
      double avgPrice = completed > 0 ? totalSpent / completed : 0.0;
      double avgDistance = ridesWithDistance > 0 ? totalDistance / ridesWithDistance : 0.0;
      double avgRating = ratedRides > 0 ? totalRating / ratedRides : 0.0;
      
      setState(() {
        _totalRides = total;
        _completedRides = completed;
        _cancelledRides = cancelled;
        _totalSpent = totalSpent;
        _averagePrice = avgPrice;
        _averageDistance = avgDistance;
        _averageRating = avgRating;
        _ridesByMonth = byMonth;
        _spendingByMonth = spendingByMonth;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement statistiques: $e');
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
      );
    }

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
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        color: const Color(0xFF4CAF50),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Statistiques principales
            _buildMainStatsGrid(),
            
            const SizedBox(height: 24),
            
            // Répartition par statut (Pie Chart)
            if (_totalRides > 0)
              _buildStatusPieChart(),
            
            const SizedBox(height: 24),
            
            // Évolution mensuelle (Bar Chart)
            if (_ridesByMonth.isNotEmpty)
              _buildMonthlyRidesChart(),
            
            const SizedBox(height: 24),
            
            // Dépenses mensuelles (Line Chart)
            if (_spendingByMonth.isNotEmpty)
              _buildMonthlySpendingChart(),
            
            const SizedBox(height: 24),
            
            // Autres statistiques
            _buildAdditionalStats(),
          ],
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
      childAspectRatio: 1.3,
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
          label: 'Total dépensé',
          value: '${_totalSpent.toStringAsFixed(0)} DH',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.show_chart,
          label: 'Prix moyen',
          value: '${_averagePrice.toStringAsFixed(0)} DH',
          color: Colors.purple,
        ),
        _buildStatCard(
          icon: Icons.route,
          label: 'Distance moy.',
          value: '${_averageDistance.toStringAsFixed(1)} km',
          color: Colors.teal,
        ),
        _buildStatCard(
          icon: Icons.star,
          label: 'Note moyenne',
          value: _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '-',
          color: Colors.amber,
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
        border: Border.all(color: color.withOpacity(0.2)),
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
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
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

  Widget _buildStatusPieChart() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition des courses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _buildPieChartSections(),
                centerSpaceRadius: 50,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildPieChartLegend(),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final sections = <PieChartSectionData>[];
    
    if (_completedRides > 0) {
      sections.add(PieChartSectionData(
        value: _completedRides.toDouble(),
        color: Colors.green,
        title: '${(_completedRides / _totalRides * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    if (_cancelledRides > 0) {
      sections.add(PieChartSectionData(
        value: _cancelledRides.toDouble(),
        color: Colors.red,
        title: '${(_cancelledRides / _totalRides * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    int others = _totalRides - _completedRides - _cancelledRides;
    if (others > 0) {
      sections.add(PieChartSectionData(
        value: others.toDouble(),
        color: Colors.orange,
        title: '${(others / _totalRides * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    return sections;
  }

  Widget _buildPieChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Terminées', Colors.green, _completedRides),
        _buildLegendItem('Annulées', Colors.red, _cancelledRides),
        _buildLegendItem('Autres', Colors.orange, _totalRides - _completedRides - _cancelledRides),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMonthlyRidesChart() {
    final sortedEntries = _ridesByMonth.entries.toList()
      ..sort((a, b) {
        try {
          DateTime dateA = DateFormat('MM/yyyy').parse(a.key);
          DateTime dateB = DateFormat('MM/yyyy').parse(b.key);
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });
    
    // Prendre les 6 derniers mois maximum
    final recentMonths = sortedEntries.length > 6
        ? sortedEntries.sublist(sortedEntries.length - 6)
        : sortedEntries;
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Courses par mois',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (recentMonths.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 5).toDouble(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < recentMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              recentMonths[index].key,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  recentMonths.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: recentMonths[index].value.toDouble(),
                        color: const Color(0xFF4CAF50),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySpendingChart() {
    final sortedEntries = _spendingByMonth.entries.toList()
      ..sort((a, b) {
        try {
          DateTime dateA = DateFormat('MM/yyyy').parse(a.key);
          DateTime dateB = DateFormat('MM/yyyy').parse(b.key);
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });
    
    // Prendre les 6 derniers mois maximum
    final recentMonths = sortedEntries.length > 6
        ? sortedEntries.sublist(sortedEntries.length - 6)
        : sortedEntries;
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dépenses mensuelles (DH)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < recentMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              recentMonths[index].key,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      recentMonths.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        recentMonths[index].value,
                      ),
                    ),
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalStats() {
    double completionRate = _totalRides > 0 ? (_completedRides / _totalRides * 100) : 0.0;
    double cancellationRate = _totalRides > 0 ? (_cancelledRides / _totalRides * 100) : 0.0;
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Autres statistiques',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          
          _buildProgressStat(
            label: 'Taux de complétion',
            value: completionRate,
            color: Colors.green,
            suffix: '%',
          ),
          const SizedBox(height: 16),
          
          _buildProgressStat(
            label: 'Taux d\'annulation',
            value: cancellationRate,
            color: Colors.red,
            suffix: '%',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat({
    required String label,
    required double value,
    required Color color,
    required String suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              '${value.toStringAsFixed(1)}$suffix',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.grey[200],
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
