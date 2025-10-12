import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:oshapp/features/admin/user_management_screen.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/features/admin/role_management_screen.dart';
import 'package:oshapp/features/admin/company_profile_screen.dart';
import 'package:oshapp/features/admin/reports_screen.dart';
import 'package:oshapp/features/admin/settings_screen.dart';
import 'package:oshapp/features/admin/audit_log_screen.dart';
import 'package:oshapp/shared/models/user.dart';
import 'package:oshapp/shared/models/admin_dashboard_data.dart';
import 'package:oshapp/shared/widgets/progress_overlay.dart';
import 'package:oshapp/shared/widgets/theme_controls.dart';
import 'package:oshapp/features/profile/profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final User user;

  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final ApiService _apiService;
  late Future<AdminDashboardData> _dashboardData;

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _dashboardData = _apiService.getAdminDashboardData();
  }

  Future<void> _refreshDashboard() async {
    final future = _apiService.getAdminDashboardData();
    setState(() {
      _dashboardData = future;
    });
    await future;
  }

  Future<void> _navigateTo(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    await _refreshDashboard();
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FutureBuilder<AdminDashboardData>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Aucune donnée disponible.'));
          }

          final data = snapshot.data!;
          return _buildBody(context, data);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminDashboardData data) {
    final theme = Theme.of(context);
    final displayName = widget.user.username;

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            title: const Text('Tableau de Bord Admin'),
            backgroundColor: Colors.transparent,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,
            floating: true,
            snap: true,
            actions: [
              const ThemeControls(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refreshDashboard,
                tooltip: 'Actualiser',
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => {},
                tooltip: 'Notifications',
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app_rounded),
                onPressed: _logout,
                tooltip: 'Déconnexion',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue, $displayName',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildQuickStats(context, data),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Actions Rapides',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildActionGrid(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Activité Récente',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentActivityPlaceholder(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, AdminDashboardData data) {
    return Column(
      children: [
        _StatCard(
          title: 'Utilisateurs',
          value: data.totalUsers.toString(),
          icon: Icons.people_outline_rounded,
          color: Colors.blue.shade600, // Vibrant Blue
          onTap: () => _navigateTo(const UserManagementScreen()),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Rôles',
          value: data.totalRoles.toString(),
          icon: Icons.verified_user_outlined,
          color: Colors.orange.shade700, // Vibrant Orange
          onTap: () => _navigateTo(const RoleManagementScreen()),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Utilisateurs Actifs',
          value: data.activeUsers.toString(),
          icon: Icons.bar_chart_rounded,
          color: Colors.red.shade600, // Vibrant Red
          onTap: () => _navigateTo(
              const UserManagementScreen(initialStatusFilter: 'ACTIF')),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Utilisateurs Inactifs',
          value: data.inactiveUsers.toString(),
          icon: Icons.person_off_outlined,
          color: Colors.indigo.shade600, // Indigo
          onTap: () => _navigateTo(
              const UserManagementScreen(initialStatusFilter: 'INACTIF')),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'En attente de vérification',
          value: data.awaitingVerificationUsers.toString(),
          icon: Icons.hourglass_empty_rounded,
          color: Colors.purple.shade600, // Purple
          onTap: () => _navigateTo(const UserManagementScreen(
              initialVerificationFilter: 'NON_VERIFIE')),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Connexions récentes',
          value: data.recentLogins.toString(),
          icon: Icons.login_rounded,
          color: Colors.teal.shade600, // Vibrant Teal
          onTap: () => _navigateTo(const AuditLogScreen()),
        ),
      ],
    );
  }

  SliverPadding _buildActionGrid() {
    final List<Map<String, dynamic>> actions = [
      {
        'title': 'Gestion des Utilisateurs',
        'icon': Icons.people_alt_outlined,
        'color': Colors.blue.shade600,
        'action': () => _navigateTo(const UserManagementScreen())
      },
      {
        'title': 'Gestion des Rôles',
        'icon': Icons.verified_user_outlined,
        'color': Colors.orange.shade700,
        'action': () => _navigateTo(const RoleManagementScreen())
      },
      {
        'title': 'Profil Entreprise',
        'icon': Icons.business_rounded,
        'color': Colors.green.shade600,
        'action': () => _navigateTo(const CompanyProfileScreen())
      },
      {
        'title': 'Rapports et Stats',
        'icon': Icons.bar_chart_rounded,
        'color': Colors.red.shade600,
        'action': () => _navigateTo(const ReportsScreen())
      },
      {
        'title': 'Paramètres',
        'icon': Icons.settings_outlined,
        'color': Colors.purple.shade600,
        'action': () => _navigateTo(const SettingsScreen())
      },
      {
        'title': 'Historique',
        'icon': Icons.history_rounded,
        'color': Colors.brown.shade600,
        'action': () => _navigateTo(const AuditLogScreen())
      },
      {
        'title': 'Mon Profil',
        'icon': Icons.account_circle_outlined,
        'color': Colors.teal.shade600,
        'action': () => _navigateTo(ProfileScreen(user: widget.user))
      },
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final action = actions[index];
            return _buildActionCard(action['title'], action['icon'],
                action['color'], action['action']);
          },
          childCount: actions.length,
        ),
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0.5,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityPlaceholder() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.hourglass_empty_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Aucune activité récente à afficher.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withValues(alpha: 0.1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Row(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
