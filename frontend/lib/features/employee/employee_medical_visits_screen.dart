import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/config/app_config.dart';
import 'package:oshapp/shared/widgets/appointment_card.dart';
import 'package:oshapp/shared/widgets/confirm_dialog.dart';
import 'package:oshapp/features/appointments/widgets/appointment_request_form_inline.dart';

enum EmployeeMedicalTab { consulter, planifier }

class EmployeeMedicalVisitsScreen extends StatefulWidget {
  final EmployeeMedicalTab initialTab;
  const EmployeeMedicalVisitsScreen(
      {super.key, this.initialTab = EmployeeMedicalTab.consulter});

  @override
  State<EmployeeMedicalVisitsScreen> createState() =>
      _EmployeeMedicalVisitsScreenState();
}

class _EmployeeMedicalVisitsScreenState
    extends State<EmployeeMedicalVisitsScreen> {
  late EmployeeMedicalTab _tab;
  late ApiService _api;

  Future<List<Appointment>>? _future;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    // Avoid null Future before _api is available
    _future = Future.value(const <Appointment>[]);
    // Read provider immediately (listen: false is allowed in initState)
    _api = Provider.of<ApiService>(context, listen: false);
    // Then trigger first load next frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
    });
  }

  Widget _buildProcessFlow(ThemeData theme) {
    Widget step(IconData icon, String title, String subtitle, {Color? color}) {
      final bg = (color ?? Colors.green).withValues(alpha: 0.08);
      final bd = (color ?? Colors.green).withValues(alpha: 0.35);
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bd),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color ?? Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            )
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Responsive columns: 1 on very small screens, 2 on phones, 4 on wide
        final cols = w < 380 ? 1 : (w < 700 ? 2 : 4);
        final gap = 8.0;
        final tileWidth = (w - gap * (cols - 1)) / cols;
        List<Widget> tiles = [
          SizedBox(
            width: tileWidth,
            child: step(
              Icons.assignment_outlined,
              'Soumission',
              'Vous remplissez et envoyez le formulaire avec vos disponibilités et le motif de visite.',
            ),
          ),
          SizedBox(
            width: tileWidth,
            child: step(
              Icons.notifications_active_outlined,
              'Notification',
              'Le service médical est notifié de votre demande.',
            ),
          ),
          SizedBox(
            width: tileWidth,
            child: step(
              Icons.medical_services_outlined,
              'Traitement',
              'L’équipe médicale examine votre demande et la valide.',
            ),
          ),
          SizedBox(
            width: tileWidth,
            child: step(
              Icons.check_circle_outline,
              'Confirmation',
              'Vous recevrez la confirmation ou une proposition alternative.',
            ),
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles,
        );
      },
    );
  }

  Widget _buildReviewNote(ThemeData theme) {
    final bg = theme.colorScheme.error.withValues(alpha: 0.06);
    final bd = theme.colorScheme.error.withValues(alpha: 0.32);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bd),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Votre demande sera examinée par le service médical. Vous serez notifié(e) dès que votre rendez-vous sera confirmé.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequest(ThemeData theme, Appointment appt) {
    final amber = Colors.amber;
    final bg = amber.withValues(alpha: 0.08);
    final bd = amber.withValues(alpha: 0.35);
    final date =
        appt.requestedDateEmployee ?? appt.proposedDate ?? appt.appointmentDate;
    final dateStr =
        date != null ? DateFormat.yMMMMd('fr_FR').format(date) : 'Non définie';
    final isHrInitiatedObligatory = _isHrInitiatedObligatory(appt);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bd),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demande en cours',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: appt.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  appt.statusUiDisplay ?? 'En cours',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: appt.statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _kv(
                      theme,
                      'Motif',
                      appt.motif?.isNotEmpty == true
                          ? appt.motif!
                          : (appt.reason ?? '—'))),
              const SizedBox(width: 12),
              Expanded(child: _kv(theme, isHrInitiatedObligatory ? 'Date limite' : 'Date souhaitée', dateStr)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'Vous ne pouvez pas créer une nouvelle demande tant que la précédente n’est pas traitée.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(v,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildSpontaneousHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.volunteer_activism, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Demande de visite médicale spontanée',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
            'Remplissez les informations ci-dessous pour demander une visite médicale spontanée.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
      ],
    );
  }

  void _reload() {
    setState(() {
      _future = _api.getMyAppointments();
    });
  }

  Future<void> _onRefresh() async {
    _reload();
  }

  Future<void> _handleConfirmAppointment(Appointment appointment) async {
    final confirmed = await showConfirmDialog(context);
    if (!confirmed) return;
    try {
      await _api.confirmAppointment(appointment.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rendez-vous confirmé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la confirmation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleCancelAppointment(Appointment appointment) async {
    // Show dialog to get cancellation reason
    final reason = await _showCancellationDialog();
    if (reason == null || reason.trim().isEmpty) return;

    try {
      await _api.cancelAppointment(appointment.id, reason: reason.trim());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rendez-vous annulé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'annulation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showCancellationDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Annuler le rendez-vous'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Veuillez indiquer la raison de l\'annulation:'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Motif d\'annulation',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le motif est obligatoire';
                    }
                    return null;
                  },
                ),
              ],
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
              child: const Text('Confirmer l\'annulation'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Visite médicale'),
        backgroundColor: Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            tooltip: 'Réinitialiser tout (test)',
            onPressed: _showResetDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle buttons inside a centered pill container like Nurse screen
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          context,
                          EmployeeMedicalTab.planifier,
                          label: 'Planifier (Spontanée)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTabButton(
                          context,
                          EmployeeMedicalTab.consulter,
                          label: 'Consulter mes visites',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _tab == EmployeeMedicalTab.planifier
                    ? FutureBuilder<List<Appointment>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Erreur lors du chargement: ${snapshot.error}'),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _reload,
                                    style: OutlinedButton.styleFrom(
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      side: BorderSide(
                                          color: theme.colorScheme.primary),
                                      foregroundColor:
                                          theme.colorScheme.primary,
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Réessayer'),
                                  ),
                                ],
                              ),
                            );
                          }
                          final list = snapshot.data ?? const <Appointment>[];
                          // Find pending/proposed ongoing request
                          Appointment? pending;
                          if (list.isNotEmpty) {
                            final open = list
                                .where((a) =>
                                    a.statusUiCategory == 'REQUESTED' ||
                                    a.statusUiCategory == 'PROPOSED')
                                .toList();
                            if (open.isNotEmpty) {
                              open.sort((a, b) {
                                final da =
                                    a.requestedDateEmployee ?? a.createdAt;
                                final db =
                                    b.requestedDateEmployee ?? b.createdAt;
                                return db.compareTo(da); // latest first
                              });
                              pending = open.first;
                            }
                          }
                          final showForm =
                              AppConfig.showSpontaneousFormAlways ||
                                  pending == null;

                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProcessFlow(theme),
                                  const SizedBox(height: 12),
                                  _buildReviewNote(theme),
                                  const SizedBox(height: 12),
                                  if (pending != null)
                                    _buildPendingRequest(theme, pending),
                                  if (showForm) _buildSpontaneousHeader(theme),
                                  if (showForm)
                                    AppointmentRequestFormInline(
                                      onSuccess: (newAppt) {
                                        setState(() {
                                          _tab = EmployeeMedicalTab.consulter;
                                        });
                                        _reload();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : FutureBuilder<List<Appointment>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Erreur lors du chargement: ${snapshot.error}'),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _reload,
                                    style: OutlinedButton.styleFrom(
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      side: BorderSide(
                                          color: theme.colorScheme.primary),
                                      foregroundColor:
                                          theme.colorScheme.primary,
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Réessayer'),
                                  )
                                ],
                              ),
                            );
                          }
                          final list = snapshot.data ?? const <Appointment>[];
                          if (list.isEmpty) {
                            return Center(
                              child: Card(
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.medical_information_outlined,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 12),
                                      const Text(
                                          'Aucun rendez-vous pour le moment'),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          return RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: LayoutBuilder(
                              builder: (ctx, constraints) {
                                final w = constraints.maxWidth;
                                int cols;
                                if (w < 600) {
                                  cols = 1;
                                } else if (w < 900) {
                                  cols = 2;
                                } else if (w < 1200) {
                                  cols = 3;
                                } else {
                                  cols = 4;
                                }
                                const spacing = 12.0;
                                final tileWidth =
                                    (w - spacing * (cols - 1)) / cols;

                                return SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 8.0),
                                  child: Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children:
                                        List.generate(list.length, (index) {
                                      final a = list[index];
                                      return SizedBox(
                                        width: tileWidth,
                                        child: AppointmentCard(
                                          appointment: a,
                                          onConfirm: () =>
                                              _handleConfirmAppointment(a),
                                          onCancel: () =>
                                              _handleCancelAppointment(a),
                                          canSeePrivateInfo:
                                              true, // Employé peut voir consignes et téléphone
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildTabButton(BuildContext context, EmployeeMedicalTab tab,
      {required String label}) {
    final theme = Theme.of(context);
    final isActive = _tab == tab;
    if (isActive) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.85)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => setState(() => _tab = tab),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return OutlinedButton(
      onPressed: () => setState(() => _tab = tab),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const StadiumBorder(),
        side: BorderSide(color: theme.colorScheme.primary, width: 1.2),
        foregroundColor: theme.colorScheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Réinitialiser tout'),
          content: const Text(
            'Cette action supprimera tous les rendez-vous et notifications pour les tests.\n\nÊtes-vous sûr de vouloir continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetAll();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réinitialiser'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetAll() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réinitialisation en cours...'),
          duration: Duration(seconds: 2),
        ),
      );

      await _api.resetAllAppointments();
      await _api.resetAllNotifications();
      _reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réinitialisation terminée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la réinitialisation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Detect Embauche-type visits robustly based on raw and formatted type fields
  bool _isEmbauche(Appointment a) {
    final String tDisp = (a.typeDisplay ?? a.typeShortDisplay ?? '').toLowerCase();
    if (tDisp.contains("embauche")) return true;
    final String t = a.type.toUpperCase();
    return t.contains('EMBAUCHE') ||
        t.contains('PRE_RECRUITMENT') ||
        t.contains('PRE-RECRUITMENT') ||
        t.contains('PRE_EMPLOYMENT') ||
        t.contains('PRE-EMPLOYMENT');
  }

  // Detect HR-initiated obligatory appointments for consistent 'Date limite' label
  bool _isHrInitiatedObligatory(Appointment a) {
    final bool byHr = a.createdBy?.hasRole('HR') ?? false; // handles 'RH' via normalization
    return (a.obligatory && byHr) || _isEmbauche(a);
  }
}
