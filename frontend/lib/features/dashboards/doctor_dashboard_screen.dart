import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/activity.dart';
import '../../shared/models/alert.dart';
import '../../shared/models/doctor_dashboard_data.dart';
import '../../shared/models/employee.dart';
import '../../shared/models/user.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/activity_card.dart';
import '../../shared/widgets/error_display.dart';
import '../../shared/widgets/progress_overlay.dart';
import '../doctor/create_appointment_screen.dart';
import '../profile/profile_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  final User user;

  const DoctorDashboardScreen({super.key, required this.user});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late Future<DoctorDashboardData> _dashboardDataFuture;
  late ApiService _apiService;
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _dashboardDataFuture = _loadData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.orange.shade700,
      end: Colors.orange.shade900,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<DoctorDashboardData> _loadData() async {
    try {
      return await _apiService.getDoctorDashboardData();
    } catch (e) {
      debugPrint('Error loading doctor dashboard data: $e');
      rethrow;
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _dashboardDataFuture = _loadData();
    });
  }

  void _logout() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final lang = Localizations.localeOf(context).languageCode;
    final isFr = lang.toLowerCase().startsWith('fr');

    final title = isFr ? 'Déconnexion en cours' : 'Logging out';
    final successTitle = isFr ? 'Déconnecté' : 'Logged out';
    final serverMsg =
        isFr ? 'Déconnexion du serveur...' : 'Signing out from server...';
    final googleMsg = isFr
        ? 'Nettoyage de la session Google...'
        : 'Cleaning Google session...';
    final localMsg =
        isFr ? 'Nettoyage des données locales...' : 'Clearing local data...';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: FutureBuilder<DoctorDashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorDisplay(
              message: 'Une erreur est survenue: ${snapshot.error}',
              onRetry: _refreshData,
            );
          }
          if (!snapshot.hasData || widget.user.employee == null) {
            return ErrorDisplay(
              message: 'Profil employé non trouvé ou aucune donnée disponible.',
              onRetry: _refreshData,
            );
          }
          final dashboardData = snapshot.data!;
          final employee = widget.user.employee!;
          return RefreshIndicator(
            onRefresh: _refreshData,
            child: _buildDashboardBody(employee, dashboardData),
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildDashboardBody(
      Employee employee, DoctorDashboardData dashboardData) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: _buildHeader(employee, dashboardData.unreadNotifications)),
        SliverToBoxAdapter(child: _buildDashboardMenu()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickStats(dashboardData.stats),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        _buildAlertsSection(dashboardData.alerts),
        _buildRecentActivities(dashboardData.activities),
        const SliverToBoxAdapter(
            child: SizedBox(height: 80)), // Padding for FAB
      ],
    );
  }

  Widget _buildHeader(Employee employee, int unreadNotifications) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final displayName = authService.user?.username ?? employee.firstName;

    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          padding:
              const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(color: _colorAnimation.value),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 30),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProfileScreen(user: widget.user),
                  ));
                },
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 30),
                    onPressed: () => {},
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Text('$unreadNotifications',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 30),
                onPressed: _logout,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Bonjour, Dr. $displayName',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Bienvenue sur votre tableau de bord.',
              style:
                  theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildQuickStats(DoctorStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aperçu Rapide',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: [
            _buildStatCard('En Attente', stats.pendingCount,
                Icons.hourglass_empty, Colors.red),
            _buildStatCard('Confirmés', stats.confirmedCount,
                Icons.check_circle_outline, Colors.green.shade600),
            _buildStatCard('Terminés', stats.completedCount, Icons.task_alt,
                Colors.blue.shade600),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withAlpha((255 * 0.3).round()),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(value.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  Widget _buildDashboardMenu() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildActionCard(
                'Visite Médical',
                Icons.calendar_today_outlined,
                Colors.orange.shade700,
                () => _showComingSoon('Visite Médical'),
              ),
              _buildActionCard(
                'Agenda',
                Icons.calendar_today,
                Colors.blue.shade700,
                () => _showComingSoon('Agenda'),
              ),
              _buildActionCard(
                'Dossiers Patients',
                Icons.folder_shared_outlined,
                Colors.purple.shade700,
                () => _showComingSoon('Dossiers Patients'),
              ),
              _buildActionCard(
                'Rapports & Stats',
                Icons.bar_chart_outlined,
                Colors.red.shade700,
                () => _showComingSoon('Rapports & Stats'),
              ),
              _buildActionCard(
                'Paramètres',
                Icons.settings_outlined,
                Colors.green.shade700,
                () => _showComingSoon('Paramètres'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shadowColor: color.withAlpha((255 * 0.4).round()),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 12),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAlertsSection(List<Alert> alerts) {
    if (alerts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverList.separated(
      itemCount: alerts.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSectionHeader('Alertes importantes');
        }
        final alert = alerts[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: InkWell(
            onTap: () =>
                _showComingSoon('Navigation pour l\'alerte à implémenter'),
            child: ActivityCard(
              icon: Icons.info_outline,
              title: alert.title,
              subtitle: alert.date,
              color: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withAlpha((255 * 0.3).round()),
              iconColor: Theme.of(context).colorScheme.error,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivities(List<Activity> activities) {
    if (activities.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverList.separated(
      itemCount: activities.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSectionHeader('Activité Récente');
        }
        final activity = activities[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ActivityCard(
            icon: Icons.history,
            title: activity.title,
            subtitle: activity.description,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (context) => const CreateAppointmentScreen()),
        );
      },
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      tooltip: 'Nouveau RDV',
      child: const Icon(Icons.add),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          AnimatedBuilder(
            animation: _colorAnimation,
            builder: (context, child) {
              return DrawerHeader(
                decoration: BoxDecoration(color: _colorAnimation.value),
                child: const Text('Menu Docteur',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              );
            },
          ),
          _buildDrawerItem(Icons.home, 'Accueil', () => Navigator.pop(context)),
          _buildDrawerItem(Icons.calendar_today_outlined, 'Mes RDV', () {
            _showComingSoon('Visite Médical');
          }),
          _buildDrawerItem(
              Icons.calendar_today, 'Agenda', () => _showComingSoon('Agenda')),
          _buildDrawerItem(Icons.folder_shared, 'Dossiers Patients',
              () => _showComingSoon('Dossiers Patients')),
          _buildDrawerItem(Icons.bar_chart, 'Rapports & Stats',
              () => _showComingSoon('Rapports & Stats')),
          const Divider(),
          _buildDrawerItem(Icons.settings, 'Paramètres',
              () => _showComingSoon('Paramètres')),
          _buildDrawerItem(Icons.logout, 'Déconnexion', _logout),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }

  void _showComingSoon(String message) {
    Navigator.pop(context); // Close drawer if open
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message - Bientôt disponible'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}
