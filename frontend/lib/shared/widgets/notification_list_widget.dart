import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/models/notification.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/services/auth_service.dart';
 

class NotificationListWidget extends StatefulWidget {
  final int maxItems;
  final bool showTitle;
  const NotificationListWidget(
      {super.key, this.maxItems = 5, this.showTitle = true});

  @override
  State<NotificationListWidget> createState() => _NotificationListWidgetState();
}

class _NotificationListWidgetState extends State<NotificationListWidget> {
  late Future<List<AppNotification>> _futureNotifications;
  late ApiService _apiService;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _apiService = Provider.of<ApiService>(context);
      _futureNotifications = _apiService.getNotifications();
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  void _refresh() {
    setState(() {
      _futureNotifications = _apiService.getNotifications();
    });
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await _apiService.markNotificationAsRead(notificationId);
      _refresh();
    } catch (_) {
      // Silently ignore; marking as read is non-critical for UX here
    }
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      await _apiService.deleteNotification(notificationId);
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Notification supprimée.'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onNotificationTap(AppNotification notif) async {
    try {
      if (notif.relatedEntityType == 'APPOINTMENT' &&
          notif.relatedEntityId != null) {
        await _openAppointmentActions(notif);
      } else {
        _showDetails(notif);
      }
    } finally {
      if (!mounted) return;
      await _markAsRead(notif.id);
    }
  }

  Future<void> _openAppointmentActions(AppNotification notification) async {
    final int appointmentId = notification.relatedEntityId!;
    Appointment appointment;
    try {
      appointment = await _apiService.getAppointmentById(appointmentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Impossible de charger le rendez-vous: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final requestedByEmployee = appointment.statusUiCategory == 'REQUESTED';
        final proposedByMedic = appointment.statusUiCategory == 'PROPOSED';
        final auth = Provider.of<AuthService>(ctx, listen: false);
        final roles = auth.roles.map((r) => r.toUpperCase()).toList();
        final isMedic = roles.contains('DOCTOR') || roles.contains('NURSE');
        final isEmployee = roles.contains('EMPLOYEE') && !isMedic;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rendez-vous #${appointment.id}',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Employé: ${appointment.employeeName}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('Statut: ${appointment.statusUiDisplay}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (isMedic && requestedByEmployee) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmer'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _confirmAppointment(appointment.id);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Proposer un créneau'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
                if (isEmployee && proposedByMedic) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmer'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _confirmAppointment(appointment.id);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _cancelAppointment(appointment.id);
                    },
                  ),
                ],
              ]),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAppointment(int appointmentId) async {
    try {
      await _apiService.confirmAppointment(appointmentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Rendez-vous confirmé avec succès.'),
            backgroundColor: Colors.green),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de la confirmation: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _cancelAppointment(int appointmentId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Annuler le rendez-vous'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration:
                  const InputDecoration(labelText: 'Motif (obligatoire)'),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le motif est obligatoire'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Retour'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    try {
      await _apiService.cancelAppointment(appointmentId, reason: reason.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Rendez-vous annulé.'),
            backgroundColor: Colors.green),
      );
      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de l\'annulation: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notifications récentes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
                tooltip: 'Rafraîchir',
              ),
            ],
          ),
        FutureBuilder<List<AppNotification>>(
          future: _futureNotifications,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur : \\${snapshot.error}'));
            }
            final notifications = snapshot.data ?? [];
            if (notifications.isEmpty) {
              return const Text('Aucune notification.');
            }
            final toShow = notifications.length > widget.maxItems
                ? notifications.sublist(0, widget.maxItems)
                : notifications;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: toShow.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final notif = toShow[index];

                return Card(
                  color: notif.read ? Colors.white : const Color(0xFFFFEBEE),
                  child: InkWell(
                    onTap: () => _onNotificationTap(notif),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row with icon, title and actions
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                notif.read
                                    ? Icons.notifications
                                    : Icons.notifications_active,
                                color: notif.read
                                    ? Colors.grey
                                    : const Color(0xFFD32F2F),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  softWrap: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!notif.read)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Marquer comme lu',
                                      onPressed: () => _markAsRead(notif.id),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    tooltip: 'Supprimer',
                                    onPressed: () => _deleteNotification(notif.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Body message: always display backend-composed text for consistency and privacy
                          Text(
                            notif.message,
                            softWrap: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notif.timeAgo,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showDetails(AppNotification notif) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notif.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notif.message),
            const SizedBox(height: 8),
            Text('Type : \\${notif.typeDisplay}'),
            Text('Reçu : \\${notif.timeAgo}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
