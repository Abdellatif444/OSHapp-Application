import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/models/appointment_request.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:oshapp/features/hr/medical_visits_rh_screen.dart';

class AppointmentRequestFormInline extends StatefulWidget {
  final void Function(Appointment newAppointment)? onSuccess;

  const AppointmentRequestFormInline({super.key, this.onSuccess});

  @override
  State<AppointmentRequestFormInline> createState() =>
      _AppointmentRequestFormInlineState();
}

class _AppointmentRequestFormInlineState
    extends State<AppointmentRequestFormInline> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    String? label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(8);
    final baseBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: focusedBorder,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  Future<void> _pickDate() async {
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final theme = Theme.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showSuccessDialog(Appointment appointment) async {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Prefer the actual scheduled date; otherwise show the employee's requested date.
        // As a last resort, use the locally submitted date/time to reflect what the user entered.
        final DateTime? preferredDateTime = appointment.appointmentDate ??
            appointment.requestedDateEmployee ??
            (_selectedDate != null && _selectedTime != null
                ? DateTime(
                    _selectedDate!.year,
                    _selectedDate!.month,
                    _selectedDate!.day,
                    _selectedTime!.hour,
                    _selectedTime!.minute,
                  )
                : null);

        final String dateDisplay = preferredDateTime != null
            ? DateFormat('EEE d MMM y', 'fr_FR').format(preferredDateTime)
            : 'Non définie';

        final String timeDisplay = preferredDateTime != null
            ? DateFormat.Hm('fr_FR').format(preferredDateTime)
            : 'Non définie';

        // Patient fallback: if employeeName is missing, fall back to current user names/email
        final String patientDisplay = (appointment.employeeName
                    .trim()
                    .isNotEmpty &&
                appointment.employeeName != 'N/A')
            ? appointment.employeeName
            : (() {
                final auth = Provider.of<AuthService>(context, listen: false);
                final user = auth.user;
                final fullName = user?.employee?.fullName;
                if (fullName != null && fullName.trim().isNotEmpty)
                  return fullName;
                final username = user?.username;
                if (username != null && username.trim().isNotEmpty)
                  return username;
                return appointment.employeeEmail.isNotEmpty
                    ? appointment.employeeEmail
                    : '—';
              })();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          title: Row(
            children: [
              Icon(Icons.check_circle,
                  color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              Text('Demande Envoyée', style: theme.textTheme.titleLarge),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Votre demande de rendez-vous a été transmise avec succès.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Détails du RDV',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const Divider(height: 20),
                        _buildDetailRow(theme, Icons.person_outline, 'Patient',
                            patientDisplay),
                        _buildDetailRow(theme, Icons.medical_services_outlined,
                            'Type', appointment.typeDisplay),
                        _buildDetailRow(
                          theme,
                          Icons.note_alt_outlined,
                          'Motif',
                          (appointment.motif != null &&
                                  appointment.motif!.trim().isNotEmpty)
                              ? appointment.motif
                              : (_reasonController.text.trim().isNotEmpty
                                  ? _reasonController.text.trim()
                                  : '—'),
                        ),
                        _buildDetailRow(
                          theme,
                          Icons.calendar_today_outlined,
                          'Date',
                          dateDisplay,
                        ),
                        _buildDetailRow(
                          theme,
                          Icons.access_time_outlined,
                          'Heure',
                          timeDisplay,
                        ),
                        // Notes (optionnel)
                        ...(() {
                          final String? notesDisplay =
                              (appointment.notes != null &&
                                      appointment.notes!.trim().isNotEmpty)
                                  ? appointment.notes
                                  : (_notesController.text.trim().isNotEmpty
                                      ? _notesController.text.trim()
                                      : null);
                          return notesDisplay != null
                              ? [
                                  _buildDetailRow(
                                    theme,
                                    Icons.notes_outlined,
                                    'Notes',
                                    notesDisplay,
                                  ),
                                ]
                              : <Widget>[];
                        })(),

                        _buildDetailRow(theme, Icons.info_outline, 'Statut',
                            appointment.statusUiDisplay),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fermer'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(
      ThemeData theme, IconData icon, String label, String? value) {
    final String displayValue =
        (value == null || value.trim().isEmpty) ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _formKey.currentState?.reset();
      _reasonController.clear();
      _notesController.clear();
      _selectedDate = null;
      _selectedTime = null;
    
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      _showErrorSnackBar('Veuillez sélectionner une date et une heure');
      return;
    }

    setState(() => _submitting = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    final user = auth.user;

    final empId = int.tryParse(user?.employee?.id ?? '');
    if (empId == null) {
      _showErrorSnackBar('Profil employé introuvable ou ID invalide.');
      setState(() => _submitting = false);
      return;
    }

    final requestedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    if (requestedDateTime.isBefore(DateTime.now())) {
      _showErrorSnackBar(
          'La date sélectionnée ne peut pas être dans le passé.');
      setState(() => _submitting = false);
      return;
    }

    final request = AppointmentRequest(
      employeeId: empId,
      motif: _reasonController.text.trim(),
      notes: _notesController.text.trim(),
      requestedDateEmployee: requestedDateTime.toIso8601String(),
    );

    try {
      final newAppointment = await api.createAppointment(request);

      // Best-effort notify N+1/N+2 managers
      try {
        final managerIds = <int>{};
        final n1Id = user?.n1Id;
        final n2Id = user?.n2Id;
        if (n1Id != null) managerIds.add(n1Id);
        if (n2Id != null) managerIds.add(n2Id);
        if (managerIds.isNotEmpty) {
          final employeeName =
              (user?.employee != null && (user!.employee!.fullName.isNotEmpty))
                  ? user.employee!.fullName
                  : ((user?.username ?? '').isNotEmpty
                      ? (user?.username ?? '')
                      : (user?.email ?? ''));
          await api.sendAppointmentNotification(
            appointmentId: newAppointment.id,
            notificationType: 'APPOINTMENT',
            recipientIds: managerIds.toList(),
            customMessage: 'Nouvelle demande de rendez-vous par $employeeName',
          );
        }
      } catch (_) {
        // Non-blocking: ignore notification failure here
      }

      if (!mounted) return;
      await _showSuccessDialog(newAppointment);
      if (!mounted) return;
      widget.onSuccess?.call(newAppointment);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("Erreur lors de l'envoi de la demande: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Motif de la visite', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Décrivez brièvement la raison de votre demande de visite médicale',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: _decoration(
                  hint:
                      'Ex: Visite périodique, douleur au dos, contrôle post-accident, consultation préventive…',
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le motif est obligatoire.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final cols = w < 520 ? 1 : 2;
                  final gap = 16.0;
                  final fieldWidth = (w - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date souhaitée',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Sélectionnez votre date de préférence pour la visite',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: _decoration(
                                  prefixIcon: const Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _selectedDate != null
                                      ? DateFormat.yMd('fr_FR')
                                          .format(_selectedDate!)
                                      : 'Sélectionner une date',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Heure souhaitée',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Indiquez votre créneau horaire préféré',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickTime,
                              child: InputDecorator(
                                decoration: _decoration(
                                  prefixIcon: const Icon(Icons.access_time),
                                ),
                                child: Text(
                                  _selectedTime != null
                                      ? _selectedTime!.format(context)
                                      : 'Sélectionner une heure',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Notes supplémentaires (optionnel)',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: _decoration(
                  hint: 'Ex: Notes pour le médecin',
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _resetForm,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.restart_alt),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Réinitialiser',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      onPressed: _submitting ? null : _submit,
                      gradient: LinearGradient(colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.85),
                      ]),
                      radius: 8,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.medical_services_outlined,
                                    size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Envoyer la demande de visite',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
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
