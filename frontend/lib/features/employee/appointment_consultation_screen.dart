import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/models/user.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/auth_service.dart';

class AppointmentConsultationScreen extends StatelessWidget {
  final Appointment appointment;

  const AppointmentConsultationScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Rendez-vous'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 24),
            _buildInfoCard(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    // Use backend-provided display data directly
    final displayLabel = appointment.statusUiDisplay ?? 'En cours';
    final displayColor = appointment.statusColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appointment.type,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(displayLabel),
          backgroundColor: displayColor.withValues(alpha: 0.2),
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            color: displayColor,
            fontWeight: FontWeight.bold,
          ),
          side: BorderSide.none,
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, ThemeData theme) {
    final authUser = Provider.of<AuthService>(context, listen: false).user;
    final requestedByTop = _computeRequestedBy() ?? _displayUser(authUser);
    // HR-initiated obligatory (incl. Embauche) for deadline label consistency
    final bool isHrInitiatedObligatory = _isHrInitiatedObligatory(appointment);
    final String requestedDateLabel =
        isHrInitiatedObligatory ? 'Date limite' : 'Date demandée';
    final String notesLabel =
        isHrInitiatedObligatory ? 'Détails supplémentaires' : 'Notes';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (requestedByTop != null && requestedByTop.isNotEmpty)
              _buildInfoRow(
                  theme, Icons.person_outline, 'Demandé par', requestedByTop),
            _buildInfoRow(
                theme,
                Icons.calendar_today,
                appointment.statusUiCategory == 'CANCELLED'
                    ? 'Date annulée'
                    : 'Date confirmée',
                _formatDate(appointment.appointmentDate)),
            _buildInfoRow(theme, Icons.schedule, 'Date Proposée',
                _formatDate(appointment.proposedDate)),
            _buildInfoRow(theme, Icons.edit_calendar_outlined, requestedDateLabel,
                _formatDate(appointment.requestedDateEmployee)),
            const SizedBox(height: 4),
            // Relative info lines similar to list cards
            Builder(
              builder: (context) {
                final scheduled = appointment.appointmentDate ?? appointment.proposedDate ?? appointment.requestedDateEmployee;
                final showPassed = scheduled != null && scheduled.isBefore(DateTime.now());
                final statusRel = _statusRelativeLabel(appointment);
                final remaining = _timeRemainingUntil(appointment.proposedDate) ??
                    _timeRemainingUntil(appointment.requestedDateEmployee);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (statusRel != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Text(
                          statusRel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withAlpha(179),
                          ),
                        ),
                      ),
                    ],
                    if (showPassed) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Text(
                          'Rendez-vous déjà passé ${_formatRelativeTimeFr(scheduled!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withAlpha(179),
                          ),
                        ),
                      ),
                    ],
                    if (!showPassed && remaining != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Text(
                          remaining,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withAlpha(179),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            // Actors (Demandé/Proposé/Confirmé/Annulé par)
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final proposedBy = _computeProposedBy();
                final confirmedBy = _computeConfirmedBy();
                final cancelledBy = _computeCancelledBy();
                return Column(
                  children: [
                    if (proposedBy != null && proposedBy.isNotEmpty)
                      _buildInfoRow(theme, Icons.medical_services_outlined,
                          'Proposé par', proposedBy),
                    if (confirmedBy != null && confirmedBy.isNotEmpty)
                      _buildInfoRow(theme, Icons.verified_outlined, 'Confirmé par',
                          confirmedBy),
                    if (appointment.statusUiCategory == 'CANCELLED' &&
                        cancelledBy != null &&
                        cancelledBy.isNotEmpty)
                      _buildInfoRow(theme, Icons.cancel_outlined, 'Annulé par',
                          cancelledBy),
                  ],
                );
              },
            ),
            _buildInfoRow(
                theme,
                Icons.medical_services_outlined,
                'Médecin',
                _inlineNameEmail(appointment.doctor) ?? ''),
            _buildInfoRow(
                theme,
                Icons.person_outline,
                'Infirmier/ère',
                _inlineNameEmail(appointment.nurse) ?? ''),
            _buildInfoRow(theme, Icons.notes_outlined, 'Motif/Raison',
                appointment.motif ?? 'Aucun motif renseigné'),
            _buildInfoRow(theme, Icons.comment_outlined, notesLabel,
                appointment.notes ?? 'Aucune note'),
            if (appointment.statusUiCategory == 'CANCELLED')
              _buildInfoRow(
                  theme,
                  Icons.notes_outlined,
                  'Raison d\'annulation de la demande:',
                  appointment.cancellationReason ?? 'Aucune raison d\'annulation'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    if (value.isEmpty || value == 'Date non spécifiée' || value.trim() == 'Non assigné') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date non spécifiée';
    return DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(date);
  }

  // Display helpers for actor attribution
  String? _displayUser(User? u) {
    if (u == null) return null;
    final fullName = (u.employee?.fullName ?? '').trim();
    if (fullName.isNotEmpty) return fullName;
    final email = (u.email).trim();
    if (email.isNotEmpty) return email;
    final username = (u.username).trim();
    if (username.isNotEmpty) return username;
    return null;
  }

  String? _inlineNameEmail(User? u) {
    if (u == null) return null;
    final fullName = (u.employee?.fullName ?? '').trim();
    final email = (u.email).trim();
    final username = (u.username).trim();
    if (fullName.isNotEmpty && email.isNotEmpty) return '$fullName — $email';
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email;
    if (username.isNotEmpty) return username;
    return null;
  }

  String? _displayEmployee() {
    final name = (appointment.employeeName).trim();
    final email = (appointment.employeeEmail).trim();
    if (name.isNotEmpty && name.toUpperCase() != 'N/A') return name;
    if (email.isNotEmpty && email.toUpperCase() != 'N/A') return email;
    return null;
  }

  bool _isMedic(User? u) {
    if (u == null) return false;
    return u.hasRole('DOCTOR') || u.hasRole('NURSE');
  }

  String? _computeRequestedBy() {
    // Prefer employee; fallback to creator
    final by = _displayEmployee() ?? _displayUser(appointment.createdBy);
    return by;
  }

  String? _computeProposedBy() {
    // Show only if a proposal exists or status is PROPOSED
    final hasProposal = appointment.proposedDate != null ||
        appointment.statusUiCategory == 'PROPOSED';
    if (!hasProposal) return null;
    final by =
        _displayUser(appointment.doctor) ?? _displayUser(appointment.nurse);
    if (by != null) return by;
    // Fallback: if creator is medical staff
    if (_isMedic(appointment.createdBy)) {
      final creator = _displayUser(appointment.createdBy);
      if (creator != null) return creator;
    }
    return null;
  }

  String? _computeConfirmedBy() {
    final isConfirmed = appointment.appointmentDate != null ||
        appointment.statusUiCategory == 'CONFIRMED' ||
        appointment.statusUiCategory == 'COMPLETED';
    if (!isConfirmed) return null;
    // Heuristic: if request was by employee, confirmation likely by medical staff
    final creatorIsEmployee = appointment.createdBy != null &&
        appointment.createdBy!.hasRole('EMPLOYEE');
    if (creatorIsEmployee) {
      return _displayUser(appointment.doctor) ??
          _displayUser(appointment.nurse) ??
          _displayEmployee();
    }
    // Otherwise, confirmation likely by employee
    return _displayEmployee() ??
        _displayUser(appointment.doctor) ??
        _displayUser(appointment.nurse) ??
        _displayUser(appointment.createdBy);
  }

  String? _computeCancelledBy() {
    if (appointment.statusUiCategory != 'CANCELLED') return null;
    // Best-effort ordering: medical staff -> creator -> employee
    return _displayUser(appointment.doctor) ??
        _displayUser(appointment.nurse) ??
        _displayUser(appointment.createdBy) ??
        _displayEmployee();
  }

  // Relative time helpers (FR)
  String _formatRelativeTimeFr(DateTime date) {
    final now = DateTime.now();
    Duration diff = now.difference(date);

    if (diff.isNegative) {
      diff = date.difference(now);
      if (diff.inSeconds < 60) return 'dans quelques secondes';
      if (diff.inMinutes < 60) return 'dans ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'dans ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
      if (diff.inDays < 7) return 'dans ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
      final weeks = (diff.inDays / 7).floor();
      if (weeks < 5) return 'dans $weeks semaine${weeks > 1 ? 's' : ''}';
      final months = (diff.inDays / 30).floor();
      if (months < 12) return 'dans $months mois';
      final years = (diff.inDays / 365).floor();
      return 'dans $years an${years > 1 ? 's' : ''}';
    }

    if (diff.inSeconds < 60) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return 'il y a $weeks semaine${weeks > 1 ? 's' : ''}';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return 'il y a $months mois';
    final years = (diff.inDays / 365).floor();
    return 'il y a $years an${years > 1 ? 's' : ''}';
  }

  String? _statusRelativeLabel(Appointment a) {
    final pivot = a.updatedAt ?? a.createdAt;
    final rel = _formatRelativeTimeFr(pivot);
    // Backend should provide localized status labels - using backend category directly
    final statusDisplay = a.statusUiCategory ?? 'Statut';
    return '$statusDisplay $rel';
  }

  String? _timeRemainingUntil(DateTime? date) {
    if (date == null) return null;
    final now = DateTime.now();
    if (!date.isAfter(now)) return null;
    final rel = _formatRelativeTimeFr(date); // returns 'dans X' for future
    if (rel.startsWith('dans ')) {
      return 'Il reste ${rel.substring(5)}';
    }
    return 'Il reste $rel';
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