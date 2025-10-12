import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/appointment.dart';
import '../../shared/models/employee.dart';
import '../../shared/models/notification.dart' as app_notification;
import '../../shared/models/user.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/error_display.dart';
import '../../shared/widgets/progress_overlay.dart';
import '../../shared/widgets/theme_controls.dart';
// import '../../shared/widgets/appointment_card.dart';

import '../documents/documents_screen.dart';
import '../profile/profile_screen.dart';
import '../employee/employee_medical_visits_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final User user;

  const EmployeeDashboardScreen({super.key, required this.user});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardData {
  final List<Appointment> appointments;
  final List<Employee> subordinates;
  final List<app_notification.AppNotification> notifications;

  _EmployeeDashboardData({
    required this.appointments,
    required this.subordinates,
    required this.notifications,
  });
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with TickerProviderStateMixin {
  // API Service
  late ApiService _apiService;
  
  // Notifications state (aligned with nurse dashboard)
  List<app_notification.AppNotification> _notifications = [];
  final GlobalKey _notifIconKey = GlobalKey();
  final ValueNotifier<List<app_notification.AppNotification>>
      _notificationItems =
      ValueNotifier<List<app_notification.AppNotification>>([]);
  OverlayEntry? _notifOverlay;

  // Scrolling controller for main dashboard list
  late final ScrollController _scrollController;
  
  // Timer for periodic notification refresh
  Timer? _notificationRefreshTimer;

  void _logout() {
    final auth = Provider.of<AuthService>(context, listen: false);
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

        await auth.logout(
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
              child: ValueListenableBuilder<
                  List<app_notification.AppNotification>>(
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
                        final text = (n.message.isNotEmpty)
                            ? '${n.title} - ${n.message}'
                            : n.title;
                        return ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: Text(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Supprimer',
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () => _deleteNotificationAt(index),
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
              child: ValueListenableBuilder<
                  List<app_notification.AppNotification>>(
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

  void _startNotificationRefresh() {
    _notificationRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _refreshNotifications();
      }
    });
  }

  Future<void> _refreshNotifications() async {
    try {
      final notifications = await _apiService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = List.of(notifications);
        });
        _notificationItems.value = List.of(notifications);
      }
    } catch (e) {
      debugPrint('Failed to refresh notifications: $e');
    }
  }

  void _deleteNotificationAt(int index) async {
    final list =
        List<app_notification.AppNotification>.from(_notificationItems.value);
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

  // (Removed) Inline medical section scrolling logic — navigation now opens
  // dedicated EmployeeMedicalVisitsScreen.

  // Minimal greeting when employee profile is not yet available
  Widget _buildGreetingSliverMinimal(
      User user, List<app_notification.AppNotification> notifications) {
    return SliverAppBar(
      title: const Text('Tableau de bord Employé'),
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
        ValueListenableBuilder<List<app_notification.AppNotification>>(
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
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
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
          icon: const Icon(Icons.person_outline),
          onPressed: () => _navigateTo(ProfileScreen(user: user)),
          tooltip: 'Profil',
        ),
        IconButton(
          icon: const Icon(Icons.exit_to_app_rounded),
          onPressed: _logout,
          tooltip: 'Déconnexion',
        ),
      ],
    );
  }

  Future<_EmployeeDashboardData>? _dashboardDataFuture;
  late AnimationController _animationController;
  late Animation<Color?> _color1Animation;
  late Animation<Color?> _color2Animation;
  late Animation<Color?> _bodyColor1Animation;
  late Animation<Color?> _bodyColor2Animation;

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _reloadData();

    _scrollController = ScrollController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _color1Animation = ColorTween(
      begin: Colors.deepOrange.shade400,
      end: Colors.purple.shade400,
    ).animate(_animationController);

    _color2Animation = ColorTween(
      begin: Colors.red.shade600,
      end: Colors.deepPurple.shade700,
    ).animate(_animationController);

    _bodyColor1Animation = ColorTween(
      begin: Colors.grey.shade200,
      end: Colors.blue.shade100,
    ).animate(_animationController);

    _bodyColor2Animation = ColorTween(
      begin: Colors.blueGrey.shade50,
      end: Colors.purple.shade100,
    ).animate(_animationController);

    // Start periodic notification refresh every 10 seconds
    _startNotificationRefresh();
  }

  @override
  void dispose() {
    _closeNotificationsPanel();
    _notificationRefreshTimer?.cancel();
    _notificationItems.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _reloadData() {
    setState(() {
      _dashboardDataFuture = _loadData();
    });
  }

  Future<_EmployeeDashboardData> _loadData() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    List<Appointment> appointments = [];
    List<app_notification.AppNotification> notifications = [];
    List<Employee> subordinates = [];

    try {
      appointments = await apiService.getMyAppointments();
    } catch (e) {
      debugPrint('Failed to load appointments: $e');
    }

    try {
      notifications = await apiService.getNotifications();
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }

    try {
      final isManager = await apiService.checkManagerStatus();
      if (isManager) {
        subordinates = await apiService.getSubordinates();
      }
    } catch (e) {
      debugPrint('Failed to load subordinates: $e');
    }

    if (mounted) {
      setState(() {
        _notifications = List.of(notifications);
      });
      _notificationItems.value = List.of(notifications);
    }

    return _EmployeeDashboardData(
      appointments: appointments,
      notifications: notifications,
      subordinates: subordinates,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: _buildDrawer(),
      body: FutureBuilder<_EmployeeDashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorDisplay(
                message: snapshot.error.toString(), onRetry: _reloadData);
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Aucune donnée disponible.'));
          }

          final data = snapshot.data!;
          final employee = widget.user.employee; // May be null for new accounts
          final isManager =
              data.subordinates.isNotEmpty; // derive from loaded data

          return RefreshIndicator(
            onRefresh: () async => _reloadData(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (employee != null)
                  _buildGreetingSliver(employee, data.notifications)
                else
                  _buildGreetingSliverMinimal(widget.user, data.notifications),
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildWelcomeCard(context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildQuickActionsGrid(),
                          const SizedBox(height: 24),
                          if (isManager && data.subordinates.isNotEmpty)
                            _buildTeamCarousel(data.subordinates),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
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
            const Icon(Icons.badge_rounded, color: Colors.white, size: 36),
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
              'Espace Employé',
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

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen))
        .then((_) => _reloadData());
  }

  Widget _buildGreetingSliver(
      Employee employee, List<app_notification.AppNotification> notifications) {
    return SliverAppBar(
      title: const Text('Tableau de bord Employé'),
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
        ValueListenableBuilder<List<app_notification.AppNotification>>(
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
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
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
          icon: const Icon(Icons.person_outline),
          onPressed: () => _navigateTo(ProfileScreen(user: widget.user)),
          tooltip: 'Profil',
        ),
        IconButton(
          icon: const Icon(Icons.exit_to_app_rounded),
          onPressed: _logout,
          tooltip: 'Déconnexion',
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final double tileHeight = screenWidth < 380 ? 160 : 140;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Actions Rapides',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: tileHeight,
        ),
        children: [
          _buildActionTile(
              icon: Icons.calendar_today_outlined,
              label: 'Visite Médicale',
              color: Colors.red,
              onTap: () => _navigateTo(const EmployeeMedicalVisitsScreen())),
          _buildActionTile(
              icon: Icons.description_outlined,
              label: 'Documents',
              color: Colors.green,
              onTap: () => _navigateTo(const DocumentsScreen())),
          _buildActionTile(
              icon: Icons.history_outlined,
              label: 'Historique',
              color: Colors.orange,
              onTap: () => _showComingSoon('Historique')),
        ],
      ),
    ]);
  }

  Widget _buildTeamCarousel(List<Employee> subordinates) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mon Équipe', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: subordinates.length,
          itemBuilder: (context, index) {
            final sub = subordinates[index];
            return SizedBox(
              width: 80,
              child: Column(children: [
                CircleAvatar(radius: 30, child: Text(sub.initials)),
                const SizedBox(height: 8),
                Text(sub.fullName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
        ]),
      ),
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
                        letterSpacing: -0.1,
                      ),
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
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_color1Animation.value!, _color2Animation.value!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: child,
              );
            },
            child: const Text('Menu',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ),
          _buildDrawerItem(
              Icons.home_outlined, 'Accueil', () => Navigator.pop(context)),
          _buildDrawerItem(Icons.calendar_today_outlined, 'Visite Médicale',
              () {
            Navigator.pop(context);
            _navigateTo(const EmployeeMedicalVisitsScreen());
          }),
          _buildDrawerItem(Icons.add_box_outlined, 'Demander un RDV', () {
            Navigator.pop(context);
            _navigateTo(const EmployeeMedicalVisitsScreen(
                initialTab: EmployeeMedicalTab.planifier));
          }),
          _buildDrawerItem(Icons.description_outlined, 'Documents', () {
            Navigator.pop(context);
            _navigateTo(const DocumentsScreen());
          }),
          _buildDrawerItem(Icons.person_outline, 'Profil', () {
            Navigator.pop(context);
            _navigateTo(ProfileScreen(user: widget.user));
          }),
          const Divider(),
          _buildDrawerItem(Icons.logout, 'Déconnexion', _logout),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _showComingSoon(String feature) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$feature — bientôt disponible',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
  }
}
