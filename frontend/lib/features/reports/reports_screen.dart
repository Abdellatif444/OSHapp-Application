import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportTypes = [
      _ReportType(
        icon: Icons.personal_injury_outlined,
        title: 'Accidents de Travail',
        subtitle: 'Générer des rapports sur les accidents de travail.',
        onTap: () {
          // TODO: Navigate to the work accident report generation screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fonctionnalité à venir.')),
          );
        },
      ),
      _ReportType(
        icon: Icons.medical_services_outlined,
        title: 'Visites Médicales',
        subtitle: 'Consulter les rapports des visites médicales.',
        onTap: () {
          // TODO: Navigate to the medical visits report screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fonctionnalité à venir.')),
          );
        },
      ),
      _ReportType(
        icon: Icons.bar_chart_outlined,
        title: 'Statistiques RH',
        subtitle: 'Analyser les statistiques sur les employés.',
        onTap: () {
          // TODO: Navigate to the HR statistics screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fonctionnalité à venir.')),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Génération de Rapports'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: reportTypes.length,
        itemBuilder: (context, index) {
          final report = reportTypes[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(report.icon, color: Theme.of(context).colorScheme.primary),
              title: Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(report.subtitle),
              onTap: report.onTap,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      ),
    );
  }
}

class _ReportType {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _ReportType({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
