import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:provider/provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ApiService _apiService;
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    try {
      final stats = await _apiService.getDashboardStatistics();
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement des statistiques: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports et Statistiques'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _statistics == null
                  ? const Center(child: Text('Aucune statistique à afficher.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Répartition des Rôles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: PieChart(_buildUserRoleChart(_statistics!['userRoleDistribution'])),
                          ),
                          const SizedBox(height: 40),
                          const Text('Activité Mensuelle des Rendez-vous', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 300,
                            child: BarChart(_buildAppointmentsChart(_statistics!['monthlyAppointmentActivity'])),
                          ),
                        ],
                      ),
                    ),
    );
  }

  PieChartData _buildUserRoleChart(Map<String, dynamic> data) {
    final List<PieChartSectionData> sections = [];
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.brown];
    int colorIndex = 0;

    data.forEach((role, count) {
      sections.add(PieChartSectionData(
        value: (count as int).toDouble(),
        title: '$role\n($count)',
        color: colors[colorIndex % colors.length],
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      colorIndex++;
    });

    return PieChartData(
      sections: sections,
      sectionsSpace: 2,
      centerSpaceRadius: 40,
    );
  }

  BarChartData _buildAppointmentsChart(List<dynamic> data) {
    double maxY = 0;
    final List<BarChartGroupData> barGroups = data.map((item) {
      final count = (item['count'] as int).toDouble();
      if (count > maxY) maxY = count;
      return BarChartGroupData(
        x: item['month'] - 1, // month is 1-based
        barRods: [BarChartRodData(toY: count, color: Colors.lightBlueAccent, width: 16)],
      );
    }).toList();

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: (maxY * 1.2).ceilToDouble(), // Add some padding to the top
      barTouchData: const BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (double value, TitleMeta meta) {
              final month = value.toInt() + 1;
              final text = DateFormat.MMM('fr_FR').format(DateTime(0, month));
              return SideTitleWidget(
                meta: meta,
                space: 4.0,
                child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (double value, TitleMeta meta) {
              return SideTitleWidget(
                meta: meta,
                space: 4.0,
                child: Text(meta.formattedValue, style: const TextStyle(fontSize: 12)),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barGroups: barGroups,
    );
  }
}
