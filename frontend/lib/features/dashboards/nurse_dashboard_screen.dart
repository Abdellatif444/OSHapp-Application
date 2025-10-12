import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:oshapp/shared/widgets/theme_controls.dart';
import 'package:oshapp/shared/widgets/error_display.dart';

// Removed intl and appointment imports: we now display backend notification messages directly
import '../../shared/models/user.dart';
import '../../shared/models/nurse_dashboard_data.dart';
import '../../shared/models/stats.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/progress_overlay.dart';
import '../../shared/models/notification.dart';
import '../profile/profile_screen.dart';
import '../medical_records/medical_records_screen.dart';
import '../nurse/nurse_medical_visits_screen.dart';

class NurseDashboardScreen extends StatefulWidget {
  final User user;
  const NurseDashboardScreen({super.key, required this.user});

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen> {
  late Future<NurseDashboardData> _dashboardDataFuture;
  late ApiService _apiService;
  // Notifications state (hydrated from dashboard data)
  List<AppNotification> _notifications = [];
  final GlobalKey _notifIconKey = GlobalKey();
  final ValueNotifier<List<AppNotification>> _notificationItems =
      ValueNotifier<List<AppNotification>>([]);
  OverlayEntry? _notifOverlay;
  // Scroll controller for notifications list (required when Scrollbar.thumbVisibility = true)
  final ScrollController _notifScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _dashboardDataFuture = _loadData();
  }

  @override
  void dispose() {
    _closeNotificationsPanel();
    _notificationItems.dispose();
    _notifScrollController.dispose();
    super.dispose();
  }

  Future<NurseDashboardData> _loadData() async {
    final data = await _apiService.getNurseDashboardData();
    // Hydrate notifications for the dropdown
    if (mounted) {
      setState(() {
        _notifications = List.of(data.notifications);
      });
    }
    _notificationItems.value = List.of(data.notifications);
    return data;
  }

  void _reloadData() {
    setState(() {
      _dashboardDataFuture = _loadData();
    });
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _apiService.getNurseDashboardData();
      if (mounted) {
        setState(() {
          _notifications = List.of(data.notifications);
        });
        _notificationItems.value = List.of(data.notifications);
      }
    } catch (e) {
      // Handle error silently or show a snackbar if needed
    }
  }

  Future<void> _loadAppointmentCounts() async {
    // Reload the entire dashboard data to refresh appointment counts
    _reloadData();
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
    final RenderBox overlay =
        overlayState.context.findRenderObject() as RenderBox;
    final RenderBox button = ctx.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);

    final screenW = overlay.size.width;
    final double panelW = MediaQuery.of(context).size.width > 380
        ? 360
        : (MediaQuery.of(context).size.width - 20);
    const double margin = 10;
    double left =
        topLeft.dx - panelW + button.size.width; // right-align to bell
    if (left < margin) left = margin;
    if (left + panelW > screenW - margin) left = screenW - margin - panelW;
    final double top = topLeft.dy + button.size.height + 8; // below bell

    _notifOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeNotificationsPanel,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: panelW,
              child: Material(
                color: Colors.transparent,
                child: AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 120),
                  alignment: Alignment.topRight,
                  child: _buildNotificationsPanel(context),
                ),
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
        maxHeight: 380,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            InkWell(
              onTap: _closeNotificationsPanel,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
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
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.onPrimary),
                  ],
                ),
              ),
            ),

            // Body
            Flexible(
              child: ValueListenableBuilder<List<AppNotification>>(
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
                    controller: _notifScrollController,
                    thumbVisibility: true,
                    thickness: 4,
                    radius: const Radius.circular(8),
                    child: ListView.separated(
                      controller: _notifScrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final n = items[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      softWrap: true,
                                    ),
                                    if (n.message.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        n.message,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.8),
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
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (context, _) => Divider(
                        height: 0,
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
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
              child: ValueListenableBuilder<List<AppNotification>>(
                valueListenable: _notificationItems,
                builder: (context, items, _) {
                  final isEmpty = items.isEmpty;
                  return SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: isEmpty ? null : _clearAllNotifications,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        disabledForegroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
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
    final list = List<AppNotification>.from(_notificationItems.value);
    if (index < 0 || index >= list.length) return;

    final notification = list[index];
    try {
      // Supprimer de la base de données via l'API
      await _apiService.deleteNotification(notification.id);

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
      // Récupérer tous les IDs des notifications
      final notificationIds = _notifications.map((n) => n.id).toList();

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

  void _showResetMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Options de reset',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_off_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Supprimer toutes les notifications'),
                    subtitle: const Text(
                        'Efface toutes les notifications du système'),
                    onTap: () {
                      Navigator.pop(context);
                      _resetAllNotifications();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.event_busy_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: const Text('Supprimer tous les rendez-vous'),
                    subtitle:
                        const Text('Efface tous les rendez-vous du système'),
                    onTap: () {
                      Navigator.pop(context);
                      _resetAllAppointments();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetAllNotifications() async {
    try {
      await _apiService.resetAllNotifications();
      _clearAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications ont été supprimées'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetAllAppointments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer TOUS les rendez-vous ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.resetAllAppointments();
        _reloadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tous les rendez-vous ont été supprimés'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showComingSoon(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature: bientôt disponible'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Removed local appointment notification formatting helpers.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => _reloadData(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Tableau de bord Infirmier'),
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
                ValueListenableBuilder<List<AppNotification>>(
                  valueListenable: _notificationItems,
                  builder: (context, items, _) {
                    final count = items.where((n) => !n.read).length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InkWell(
                            onTap: _openNotificationsPanel,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              key: _notifIconKey,
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .shadowColor
                                        .withValues(alpha: 0.12),
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
                          if (count > 0)
                            Positioned(
                              right: -3,
                              top: -3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onError,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined),
                  onPressed: _showResetMenu,
                  tooltip: 'Reset',
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ProfileScreen(user: widget.user),
                    ));
                  },
                  tooltip: 'Profil',
                ),
                IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded),
                  onPressed: _logout,
                  tooltip: 'Déconnexion',
                ),
              ],
            ),
            FutureBuilder<NurseDashboardData>(
              future: _dashboardDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ErrorDisplay(
                          message:
                              'Erreur lors du chargement du tableau de bord.',
                          onRetry: _reloadData,
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ErrorDisplay(
                          message: 'Aucune donnée disponible.',
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
                    _buildTopNavChips(),
                    _buildWelcomeCard(context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildQuickStats(data.stats),
                          const SizedBox(height: 12),
                          _buildVisitTypesCard(data.visitTypeCounts),
                          _buildDashboardMenu(),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services_rounded,
                color: Colors.white, size: 36),
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
              'Espace Infirmier',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
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

  Widget _buildTopNavChips() {
    final theme = Theme.of(context);
    final filledStyle = ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
    final outlineStyle = OutlinedButton.styleFrom(
      side: BorderSide(color: theme.colorScheme.outline),
      foregroundColor: theme.colorScheme.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text('Tableau de bord'),
              style: filledStyle,
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: const Text('Visite médicale'),
              style: outlineStyle,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NurseMedicalVisitsScreen(
                      onNotificationUpdate: () {
                        _reloadData();
                      },
                      initialIsPlanifier: false,
                      initialStatusFilter: 'Tous',
                      initialTypeFilter: 'Tous',
                      initialVisitModeFilter: 'Tous',
                      initialDepartmentFilter: 'Tous',
                      initialSearch: '',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text('Dossiers'),
              style: outlineStyle,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MedicalRecordsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // _buildBody removed; content migrated to SliverAppBar + SliverList

  // Old animated header removed; replaced by SliverAppBar and welcome card

  Widget _buildQuickStats(Stats? stats) {
    final theme = Theme.of(context);
    final s = stats ?? Stats();
    final int total = (s.totalAppointments > 0)
        ? s.totalAppointments
        : (s.pendingCount +
            s.proposedCount +
            s.confirmedCount +
            s.completedCount);

    Widget chip({
      required String count,
      required String label,
      required Color bg,
      required Color fg,
      IconData? icon,
    }) {
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aperçu Rapide',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        chip(
          count: '$total',
          label: 'Total demandes',
          bg: Colors.red.shade700.withOpacity(0.10),
          fg: Colors.red.shade700,
          icon: Icons.list_alt_rounded,
        ),
        const SizedBox(height: 10),
        chip(
          count: '${s.pendingCount}',
          label: 'En attente',
          bg: theme.colorScheme.primary.withOpacity(0.10),
          fg: theme.colorScheme.primary,
          icon: Icons.calendar_today_rounded,
        ),
        const SizedBox(height: 10),
        chip(
          count: '${s.proposedCount}',
          label: 'Proposées',
          bg: Colors.brown.shade600.withOpacity(0.10),
          fg: Colors.brown.shade600,
          icon: Icons.outgoing_mail,
        ),
        const SizedBox(height: 10),
        chip(
          count: '${s.confirmedCount}',
          label: 'Confirmées',
          bg: Colors.pink.shade700.withOpacity(0.10),
          fg: Colors.pink.shade700,
          icon: Icons.verified,
        ),
        const SizedBox(height: 10),
        chip(
          count: '${s.completedCount}',
          label: 'Réalisées',
          bg: Colors.teal.shade700.withOpacity(0.10),
          fg: Colors.teal.shade700,
          icon: Icons.task_alt,
        ),
      ],
    );
  }

  Widget _buildVisitTypesCard(Map<String, int> counts) {
    final theme = Theme.of(context);
    // Normalize with safe defaults
    int c(String key) => (counts[key] ?? 0);

    Widget item(
        {required Color dot, required String label, required int count}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_hospital_rounded, color: Colors.red.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Types de visite',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Répartition par type pour les entrées',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Grid 2 columns, 3 rows
            Row(
              children: [
                Expanded(
                  child: item(
                    dot: Colors.orange.shade700,
                    label: 'Reprise',
                    count: c('reprise'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: item(
                    dot: Colors.blue.shade600,
                    label: 'Embauche',
                    count: c('embauche'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: item(
                    dot: Colors.purple.shade600,
                    label: 'Spontané',
                    count: c('spontane'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: item(
                    dot: Colors.teal.shade600,
                    label: 'Périodique',
                    count: c('periodique'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: item(
                    dot: Colors.red.shade600,
                    label: 'Surveillance',
                    count: c('surveillance'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: item(
                    dot: Colors.indigo.shade600,
                    label: 'Appel médecin',
                    count: c('appel_medecin'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final double tileHeight = screenWidth < 380 ? 160 : 140;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Menu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8))),
        const SizedBox(height: 16),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: tileHeight, // responsive fixed height
          ),
          children: [
            _buildActionTile(
              icon: Icons.medical_services_outlined,
              label: 'Consultations',
              color: Colors.blue,
              onTap: () => _showComingSoon('Consultations'),
            ),
            _buildActionTile(
              icon: Icons.folder_outlined,
              label: 'Dossiers',
              color: Colors.green,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MedicalRecordsScreen(),
                  ),
                );
              },
            ),
            _buildActionTile(
              icon: Icons.inventory_2_outlined,
              label: 'Stock',
              color: Colors.orange,
              onTap: () => _showComingSoon('Stock'),
            ),
            _buildActionTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NurseMedicalVisitsScreen(
                      onNotificationUpdate: () {
                        _reloadData();
                      },
                      initialIsPlanifier: false,
                      initialStatusFilter: 'Tous',
                      initialTypeFilter: 'Tous',
                      initialVisitModeFilter: 'Tous',
                      initialDepartmentFilter: 'Tous',
                      initialSearch: '',
                    ),
                  ),
                );
              },
              icon: Icons.calendar_today_outlined,
              label: 'Visite médicale',
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0.5,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.0,
                      height: 1.0,
                      letterSpacing: -0.1),
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
            child: const Text(
              'Menu OSHapp',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Accueil'),
            onTap: () {
              Navigator.pop(context); // Ferme le drawer
              // Naviguer vers l'accueil si nécessaire
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Visite médicale'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NurseMedicalVisitsScreen(
                    onNotificationUpdate: () {
                      _reloadData();
                    },
                    initialIsPlanifier: false,
                    initialStatusFilter: 'Tous',
                    initialTypeFilter: 'Tous',
                    initialVisitModeFilter: 'Tous',
                    initialDepartmentFilter: 'Tous',
                    initialSearch: '',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.medical_services_outlined),
            title: const Text('Consultations'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Naviguer vers l'écran des consultations
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Dossiers'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MedicalRecordsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Stock'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Naviguer vers l'écran du stock
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
