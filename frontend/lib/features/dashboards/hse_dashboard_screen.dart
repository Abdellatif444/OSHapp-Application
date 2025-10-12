import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../../shared/services/api_service.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/hse_dashboard_data.dart';
import '../../shared/models/alert.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/stats.dart';
import '../../shared/models/user.dart'; // Import the User model
import '../../shared/widgets/stats_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/alert_card.dart';
import '../../shared/widgets/activity_list_item.dart';
import '../../shared/widgets/progress_overlay.dart';


class HseDashboardScreen extends StatefulWidget {
  final User user;

  const HseDashboardScreen({super.key, required this.user});

  @override
  HseDashboardScreenState createState() => HseDashboardScreenState();
}

class HseDashboardScreenState extends State<HseDashboardScreen> {
  void _logout() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final lang = Localizations.localeOf(context).languageCode;
    final isFr = lang.toLowerCase().startsWith('fr');

    final title = isFr ? 'Déconnexion en cours' : 'Logging out';
    final successTitle = isFr ? 'Déconnecté' : 'Logged out';
    final serverMsg = isFr ? 'Déconnexion du serveur...' : 'Signing out from server...';
    final googleMsg = isFr ? 'Nettoyage de la session Google...' : 'Cleaning Google session...';
    final localMsg = isFr ? 'Nettoyage des données locales...' : 'Clearing local data...';
    final finalMsg = isFr ? 'Finalisation...' : 'Finalizing...';

    showThemedProgressDialog(
      context: context,
      title: title,
      successTitle: successTitle,
      initialMessage: serverMsg,
      task: (onProgress) async {
        String _msgFor(double p) {
          if (p < 0.2) return serverMsg;
          if (p < 0.6) return googleMsg;
          if (p < 0.9) return localMsg;
          return finalMsg;
        }

        await authService.logout(
          navigate: true,
          onProgress: (p, _m) => onProgress(p, _msgFor(p)),
        );
      },
    );
  }




  late Future<HseDashboardData> _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dashboardDataFuture = Provider.of<ApiService>(context, listen: false).getHseDashboardData();
  }

  void _reloadData() {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.username;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, $displayName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),

        ],
      ),
      body: FutureBuilder<HseDashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Erreur: ${snapshot.error}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _reloadData,
                    child: const Text('Réessayer'),
                  )
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Aucune donnée disponible.'));
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _reloadData(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsGrid(data.stats),
                  const SizedBox(height: 24),
                  _buildAlertsSection(data.alerts),
                  const SizedBox(height: 24),
                  _buildActivitiesSection(data.activities),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(Stats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        StatsCard(
          icon: Icons.warning,
          label: 'Incidents Déclarés',
          value: stats.totalIncidents.toString(),
          color: Colors.orange,
        ),
        StatsCard(
          icon: Icons.personal_injury,
          label: 'Accidents de Travail',
          value: stats.totalAccidents.toString(),
          color: Colors.red,
        ),
        StatsCard(
          icon: Icons.analytics,
          label: 'Analyses de Risques',
          value: stats.riskAnalyses.toString(),
          color: Colors.blue,
        ),
        StatsCard(
          icon: Icons.task_alt,
          label: 'Tâches Complétées',
          value: stats.completedTasks.toString(),
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildAlertsSection(List<Alert> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Alertes Récentes'),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          const Text('Aucune alerte récente.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return AlertCard(
                title: alert.title,
                date: alert.date,
                icon: Icons.warning_amber_rounded,
                color: Colors.orange.shade50,
                iconColor: Colors.orange,
                onConfirm: () { /* TODO: Navigate to alert details */ },
                confirmLabel: 'Voir',
              );
            },
          ),
      ],
    );
  }

  Widget _buildActivitiesSection(List<Activity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Activité Récente'),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          const Text('Aucune activité récente.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ActivityListItem(
                icon: _getActivityIcon(activity.type),
                title: activity.description,
                date: DateTime.parse(activity.timestamp),
              );
            },
          ),
      ],
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type.toUpperCase()) {
      case 'INCIDENT':
        return Icons.warning;
      case 'ACCIDENT':
        return Icons.personal_injury;
      case 'TASK_COMPLETED':
        return Icons.task_alt;
      default:
        return Icons.info;
    }
  }
}