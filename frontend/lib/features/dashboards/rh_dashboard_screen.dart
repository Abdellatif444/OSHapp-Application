import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'dart:async';

import 'package:oshapp/shared/models/activity.dart';
import 'package:oshapp/shared/models/alert.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/models/user.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:oshapp/shared/widgets/error_display.dart';
import 'package:oshapp/shared/widgets/progress_overlay.dart';
import 'package:oshapp/shared/models/notification.dart' show AppNotification;

import 'package:oshapp/shared/widgets/activity_card.dart';
import 'package:oshapp/shared/widgets/theme_controls.dart';
import 'package:oshapp/features/hr/medical_certificates_screen.dart';
import 'package:oshapp/features/hr/work_accidents_screen.dart';
// import 'package:oshapp/features/hr/request_mandatory_visits_screen.dart'; // deprecated: unified into MedicalVisitsRhScreen
import 'package:oshapp/features/hr/medical_visits_rh_screen.dart';
import 'package:oshapp/features/admin/user_management_screen.dart';

import 'package:oshapp/features/settings/settings_screen.dart';
import 'package:oshapp/features/medical_records/medical_records_screen.dart';
import 'package:oshapp/features/profile/profile_screen.dart';

// Helper class to hold all dashboard data
class RhDashboardData {
  final Employee employee;
  final Map<String, dynamic> stats;
  final List<Alert> alerts;
  final List<Activity> activities;

  RhDashboardData({
    required this.employee,
    required this.stats,
    required this.alerts,
    required this.activities,
  });
}

class RHDashboardScreen extends StatefulWidget {
  final User user;

  const RHDashboardScreen({super.key, required this.user});
  @override
  State<RHDashboardScreen> createState() => _RHDashboardScreenState();
}

class _RHDashboardScreenState extends State<RHDashboardScreen> {
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

  // ================= Notifications Panel =================
  void _openNotificationsPanel() {
    if (_notifOverlay != null) {
      _closeNotificationsPanel();
      return;
    }
    final ctx = _notifIconKey.currentContext;
    if (ctx == null) return;
    final overlayState = Overlay.of(context);
    if (overlayState == null) return;
    final RenderBox overlay = overlayState.context.findRenderObject() as RenderBox;
    final RenderBox button = ctx.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);

    final screenW = overlay.size.width;
    final double panelW = MediaQuery.of(context).size.width > 380
        ? 360
        : (MediaQuery.of(context).size.width - 20);

    double left = topLeft.dx + button.size.width - panelW; // right-align to bell
    const double margin = 8;
    if (left < margin) left = margin;
    if (left + panelW > screenW - margin) left = screenW - margin - panelW;
    final double top = topLeft.dy + button.size.height + 8; // appear below bell

    _notifOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Tap outside to close
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeNotificationsPanel,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: panelW,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 8),
                    child: child,
                  ),
                ),
                child: _buildNotificationsPanel(context),
              ),
            ),
          ],
        );
      },
    );
    overlayState.insert(_notifOverlay!);
  }

  void _closeNotificationsPanel() {
    _notifOverlay?.remove();
    _notifOverlay = null;
  }

  Widget _buildNotificationsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final screenW = MediaQuery.of(context).size.width;
    final double panelW = screenW > 380 ? 360 : (screenW - 20);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: panelW,
        maxWidth: panelW,
        // Height accounts for header + list + footer
        maxHeight: 380,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (red background with white title and arrow)
            InkWell(
              onTap: _closeNotificationsPanel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onPrimary),
                  ],
                ),
              ),
            ),

            // Body: list of notifications
            Flexible(
              child: ValueListenableBuilder<List<Alert>>(
                valueListenable: _notificationItems,
                builder: (context, items, _) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Aucune notification',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Scrollbar(
                    thumbVisibility: true,
                    thickness: 4,
                    radius: const Radius.circular(8),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final n = items[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title.isNotEmpty ? n.title : 'Notification',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      softWrap: true,
                                    ),
                                    if (n.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _sanitizeMotifNotes(n.description),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                        softWrap: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Supprimer',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: theme.colorScheme.error,
                                  size: 20,
                                ),
                                onPressed: () => _deleteNotificationAt(index),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (context, _) => Divider(
                        height: 0,
                        color: theme.colorScheme.outline.withOpacity(0.4),
                      ),
                      itemCount: items.length,
                    ),
                  );
                },
              ),
            ),

            // Footer: clear all
            const Divider(height: 0),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              child: ValueListenableBuilder<List<Alert>>(
                valueListenable: _notificationItems,
                builder: (context, items, _) {
                  final isEmpty = items.isEmpty;
                  return SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: isEmpty ? null : _clearAllNotifications,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        disabledForegroundColor:
                            Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Tout supprimer'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNotificationAt(int index) async {
    final list = List<Alert>.from(_notificationItems.value);
    if (index < 0 || index >= list.length) return;
    
    final notification = list[index];
    try {
      // Convertir l'ID string en int pour l'API
      final notificationId = int.tryParse(notification.id);
      if (notificationId == null) {
        throw Exception('ID de notification invalide: ${notification.id}');
      }
      
      // Supprimer de la base de données via l'API
      await _apiService.deleteNotification(notificationId);
      
      // Supprimer localement seulement si l'API a réussi
      list.removeAt(index);
      _notificationItems.value = list;
      setState(() {
        _notifications = list;
      });
    } catch (e) {
      // Afficher un message d'erreur si la suppression échoue
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la suppression de la notification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearAllNotifications() async {
    try {
      // Récupérer tous les IDs des notifications et les convertir en int
      final notificationIds = <int>[];
      for (final notification in _notifications) {
        final id = int.tryParse(notification.id);
        if (id != null) {
          notificationIds.add(id);
        }
      }
      
      if (notificationIds.isNotEmpty) {
        // Supprimer toutes les notifications via l'API
        await _apiService.deleteNotificationsBulk(notificationIds);
      }
      
      // Vider localement seulement si l'API a réussi
      _notificationItems.value = [];
      setState(() {
        _notifications.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications ont été supprimées'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Afficher un message d'erreur si la suppression échoue
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la suppression des notifications'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }




  // Remove sensitive details (motif, notes) from strings for RH display
  String _sanitizeMotifNotes(String text) {
    var out = text;
    // Remove segments like " – Motif : ..." and " – Notes : ..." (case-insensitive)
    out = out.replaceAll(
      RegExp(r'\s*–\s*Motif\s*:\s*[^–\n]*', caseSensitive: false),
      '',
    );
    out = out.replaceAll(
      RegExp(r'\s*–\s*Notes?\s*:\s*[^–\n]*', caseSensitive: false),
      '',
    );
    // Collapse extra spaces
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return out;
  }

  // Map global AppNotification items to Alert model for the RH notifications panel
  List<Alert> _mapAppNotificationsToAlerts(List<AppNotification> list) {
    return list
        .map((n) => Alert(
              id: n.id.toString(),
              title: n.title,
              description: n.message,
              date: n.createdAt.toIso8601String(),
              severity: n.type,
              link: (n.relatedEntityType == 'APPOINTMENT' && n.relatedEntityId != null)
                  ? '/appointments/${n.relatedEntityId}'
                  : '',
            ))
        .toList();
  }

  Future<RhDashboardData?>? _dashboardDataFuture;
  late final ApiService _apiService;
  // Notifications state (hydrated from alerts)
  List<Alert> _notifications = [];
  final GlobalKey _notifIconKey = GlobalKey();
  final ValueNotifier<List<Alert>> _notificationItems =
      ValueNotifier<List<Alert>>([]);
  OverlayEntry? _notifOverlay;

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _dashboardDataFuture = _loadData();
  }

  Future<RhDashboardData?> _loadData() async {
    final employee = widget.user.employee;

    if (employee == null) {
      return null; // Don't throw, allows UI to build essential parts
    }

    try {
      final stats = await _apiService.getRhDashboardStatistics();
      final alerts = await _apiService.getRhDashboardAlerts();
      final activities = await _apiService.getRhDashboardActivities();

      // Build notification items for the bell panel using global notifications when available
      List<Alert> overlayAlerts = [];
      try {
        final appNotifs = await _apiService.getNotifications();
        overlayAlerts = _mapAppNotificationsToAlerts(appNotifs);
      } catch (_) {
        overlayAlerts = [];
      }

      // If no global notifications, fallback to RH alerts
      final allAlerts = overlayAlerts.isNotEmpty ? overlayAlerts : [...alerts];

      // Hydrate notifications state for the overlay panel
      if (mounted) {
        setState(() {
          _notifications = List.of(allAlerts);
        });
      }
      _notificationItems.value = List.of(allAlerts);

      // Keep RH alerts for the main page section
      return RhDashboardData(
        employee: employee,
        stats: stats,
        alerts: alerts,
        activities: activities,
      );
    } catch (e) {
      debugPrint('Error loading non-essential RH dashboard data: $e');
      return null; // Return null to show error in the UI for optional parts
    }
  }

  Future<void> _reloadData() async {
    setState(() {
      _dashboardDataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _reloadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Tableau de bord RH'),
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              floating: true,
              snap: true,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              actions: [
                const ThemeControls(),
                const SizedBox(width: 8),
                // Notifications bell with badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        key: _notifIconKey,
                        onTap: _openNotificationsPanel,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).shadowColor.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<List<Alert>>(
                        valueListenable: _notificationItems,
                        builder: (context, items, _) {
                          if (items.isEmpty) return const SizedBox.shrink();
                          return Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${items.length}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onError,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () =>
                      _navigateToScreen(ProfileScreen(user: widget.user)),
                  tooltip: 'Profil',
                ),
                IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded),
                  onPressed: _logout,
                  tooltip: 'Déconnexion',
                ),
              ],
            ),
            FutureBuilder<RhDashboardData?>(
              future: _dashboardDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.data == null) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ErrorDisplay(
                          message:
                              'Votre compte RH n\'est pas associé à un profil employé. Certaines fonctionnalités sont désactivées. Veuillez contacter l\'administrateur.',
                          onRetry: _reloadData,
                        ),
                      ),
                    ),
                  );
                }

                final data = snapshot.data!;
                return SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildTopNavBar(context),
                    const SizedBox(height: 12),
                    _buildWelcomeCard(context),
                    const SizedBox(height: 12),
                    _buildMedicalVisitsHeaderCard(context),
                    const SizedBox(height: 12),
                    _buildRequestsSummary(context, data.stats),
                    _buildSectionHeader(context, 'Raccourcis'),
                    _buildMainActions(context),
                    _buildSectionHeader(context, 'Activités Récentes'),
                    _buildRecentActivity(context, data.activities),
                    _buildAlertsSection(context, data.alerts),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _closeNotificationsPanel();
    _notificationItems.dispose();
    super.dispose();
  }

  // PopupMenuButton<String> _buildPopupMenu(BuildContext context) {
  //   return PopupMenuButton<String>(
  //     onSelected: (value) {
  //       switch (value) {
  //         case 'profile':
  //           _navigateToScreen(ProfileScreen(user: widget.user));
  //           break;
  //         case 'settings':
  //           _navigateToScreen(const SettingsScreen());
  //           break;
  //       }
  //     },
  //     itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
  //       const PopupMenuItem<String>(
  //         value: 'profile',
  //         child: ListTile(leading: Icon(Icons.person), title: Text('Profil')),
  //       ),
  //       const PopupMenuItem<String>(
  //         value: 'settings',
  //         child: ListTile(
  //             leading: Icon(Icons.settings), title: Text('Paramètres')),
  //       ),
  //     ],
  //   );
  // }

  void _openEmployeeManagement() {
    // RH should use the same User Management page as Admin
    _navigateToScreen(const UserManagementScreen());
  }

  Widget _buildMainActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          _buildActionCard(
            'Gestion des salariés',
            Icons.people_outline,
            Colors.blue.shade600,
            _openEmployeeManagement,
          ),
          _buildActionCard(
            'Certificats médicaux',
            Icons.medical_information_outlined,
            Colors.teal.shade600,
            () => _navigateToScreen(const MedicalCertificatesScreen()),
          ),
          _buildActionCard(
            'Dossiers médicaux',
            Icons.folder_outlined,
            Colors.purple.shade600,
            () => _navigateToScreen(const MedicalRecordsScreen()),
          ),
          _buildActionCard(
            'Accidents du travail',
            Icons.personal_injury_outlined,
            Theme.of(context).colorScheme.primary,
            () => _navigateToScreen(const WorkAccidentsScreen()),
          ),
          _buildActionCard(
            'Visites médicales',
            Icons.event_note_outlined,
            Colors.orange.shade700,
            () => _navigateToScreen(
                const MedicalVisitsRhScreen(initialPlanifier: false)),
          ),
        ],
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
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu OSHapp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bonjour, ${widget.user.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.people_outline,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Gestion des salariés'),
            onTap: () {
              Navigator.pop(context);
              _openEmployeeManagement();
            },
          ),
          ListTile(
            leading: Icon(Icons.medical_information_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Certificats médicaux'),
            onTap: () {
              Navigator.pop(context);
              _navigateToScreen(const MedicalCertificatesScreen());
            },
          ),
          ListTile(
            leading: Icon(Icons.folder_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Dossiers médicaux'),
            onTap: () {
              Navigator.pop(context);
              _navigateToScreen(const MedicalRecordsScreen());
            },
          ),
          ListTile(
            leading: Icon(Icons.personal_injury_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Accidents du travail'),
            onTap: () {
              Navigator.pop(context);
              _navigateToScreen(const WorkAccidentsScreen());
            },
          ),
          ListTile(
            leading: Icon(Icons.event_note_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Visites médicales'),
            onTap: () {
              Navigator.pop(context);
              _navigateToScreen(
                  const MedicalVisitsRhScreen(initialPlanifier: false));
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.person_outline,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Profil'),
            onTap: () {
              Navigator.pop(context);
              _navigateToScreen(ProfileScreen(user: widget.user));
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Paramètres'),
            onTap: () {
              Navigator.pop(context);
              _navigateToScreen(const SettingsScreen());
            },
          ),
          ListTile(
            leading: Icon(Icons.logout,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Déconnexion'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildMedicalVisitsHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_services_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Visites médicales (RH)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _navigateToScreen(
                        const MedicalVisitsRhScreen(initialPlanifier: true)),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      side: BorderSide(color: theme.colorScheme.primary),
                      foregroundColor: theme.colorScheme.primary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Planifier'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _navigateToScreen(
                        const MedicalVisitsRhScreen(initialPlanifier: false)),
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      elevation: 1,
                    ),
                    child: const Text('Consulter'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _navPill(
              context,
              label: 'Tableau de bord',
              icon: Icons.dashboard_rounded,
              selected: true,
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            _navPill(
              context,
              label: 'Gestion des salariés',
              icon: Icons.people_outline,
              onPressed: _openEmployeeManagement,
            ),
            const SizedBox(width: 8),
            _navPill(
              context,
              label: 'Visites médicales',
              icon: Icons.event_note_outlined,
              onPressed: () => _navigateToScreen(
                  const MedicalVisitsRhScreen(initialPlanifier: false)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navPill(BuildContext context,
      {required String label,
      required IconData icon,
      bool selected = false,
      VoidCallback? onPressed}) {
    final theme = Theme.of(context);
    final shape = const StadiumBorder();
    if (selected) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: shape,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label)
          ],
        ),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: shape,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        foregroundColor: theme.colorScheme.onSurface,
        backgroundColor: theme.colorScheme.surface,
      ),
      child: Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final theme = Theme.of(context);
    final isHR = widget.user.hasRole('HR') || widget.user.hasRole('RH');
    final roleLabel = isHR ? 'Responsable RH' : 'Espace RH';
    final gradient = LinearGradient(
      colors: [theme.colorScheme.primary, theme.colorScheme.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              'Bienvenue sur votre espace',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              roleLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vous êtes connecté en tant que ${widget.user.email}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsSummary(
      BuildContext context, Map<String, dynamic> stats) {
    final theme = Theme.of(context);
    String v(dynamic k) => (k ?? '0').toString();
    final pending =
        v(stats['pending_visits'] ?? stats['pending'] ?? stats['en_attente']);
    final proposed = v(stats['proposed_visits'] ??
        stats['proposed'] ??
        stats['proposees'] ??
        stats['proposées']);
    final confirmed = v(stats['confirmed_visits'] ??
        stats['confirmed'] ??
        stats['confirmées'] ??
        stats['confirmees']);

    Widget chip(
        {required String count,
        required String label,
        required Color bg,
        required Color fg,
        IconData? icon}) {
      // Match quick stat card layout exactly, full-width line
      return SizedBox(
        width: double.infinity,
        child: Card(
          elevation: 0,
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Row(
              children: [
                if (icon != null) Icon(icon, size: 28, color: fg),
                if (icon != null) const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: fg,
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          chip(
            count: pending,
            label: 'En attente',
            bg: theme.colorScheme.primary.withOpacity(0.10),
            fg: theme.colorScheme.primary,
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: 10),
          chip(
            count: proposed,
            label: 'Proposées',
            bg: Colors.brown.shade600.withOpacity(0.10),
            fg: Colors.brown.shade600,
            icon: Icons.outgoing_mail,
          ),
          const SizedBox(height: 10),
          chip(
            count: confirmed,
            label: 'Confirmées',
            bg: Colors.pink.shade700.withOpacity(0.10),
            fg: Colors.pink.shade700,
            icon: Icons.verified,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context, List<Alert> alerts) {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Alertes Importantes'),
          ...alerts.map((alert) {
            final visuals = _getAlertVisuals(alert.severity);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
              leading: Icon(visuals['icon'] as IconData,
                  color: visuals['color'] as Color),
              title: Text(alert.title),
              subtitle: Text(_sanitizeMotifNotes(alert.description)),
              trailing: Icon(Icons.chevron_right,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
              onTap: () => _navigateToLink(alert.link),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, List<Activity> activities) {
    if (activities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Aucune activité récente.')),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(activities.length, (index) {
          final activity = activities[index];
          final details = _getActivityDetails(activity.type);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: InkWell(
              onTap: () => _navigateToLink(activity.link),
              child: ActivityCard(
                icon: details['icon'],
                title: activity.title,
                subtitle: activity.description,
                color: details['color'],
                iconColor: details['iconColor'],
                showChevron: true,
              ),
            ),
          );
        }),
      ),
    );
  }

  Map<String, dynamic> _getActivityDetails(String type) {
    switch (type) {
      case 'NEW_EMPLOYEE':
        return {
          'icon': Icons.person_add,
          'color': Colors.green.shade50,
          'iconColor': Colors.green
        };
      case 'CERTIFICATE_SUBMITTED':
        return {
          'icon': Icons.document_scanner,
          'color': Colors.blue.shade50,
          'iconColor': Colors.blue
        };
      case 'VISIT_REQUEST':
        return {
          'icon': Icons.calendar_today,
          'color': Colors.orange.shade50,
          'iconColor': Colors.orange
        };
      default:
        return {
          'icon': Icons.info,
          'color': Colors.grey.shade50,
          'iconColor': Colors.grey
        };
    }
  }

  Map<String, dynamic> _getAlertVisuals(String severity) {
    final s = (severity).toUpperCase();
    switch (s) {
      case 'CRITICAL':
        return {'icon': Icons.error, 'color': Colors.red.shade700};
      case 'HIGH':
      case 'WARNING':
        return {'icon': Icons.warning, 'color': Colors.orange.shade700};
      case 'MEDIUM':
        return {'icon': Icons.report_problem, 'color': Colors.amber.shade700};
      case 'LOW':
        return {'icon': Icons.info, 'color': Colors.blue.shade600};
      case 'INFO':
        return {'icon': Icons.info_outline, 'color': Colors.blueGrey};
      default:
        return {'icon': Icons.notifications, 'color': Colors.grey};
    }
  }

  void _navigateToScreen(Widget screen) {
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    }
  }

  void _navigateToLink(String? link) {
    if (!mounted || link == null) return;
    final trimmed = link.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lien invalide: $link')),
      );
      return;
    }
    final resourceType =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;

    switch (resourceType) {
      case 'employees':
        _openEmployeeManagement();
        break;
      case 'medical-records':
        _navigateToScreen(const MedicalRecordsScreen());
        break;
      case 'medical-certificates':
        _navigateToScreen(const MedicalCertificatesScreen());
        break;
      case 'work-accidents':
        _navigateToScreen(const WorkAccidentsScreen());
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lien non supporté: $link')),
        );
    }
  }
}
