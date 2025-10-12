import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import 'package:oshapp/shared/config/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/models/uploaded_medical_certificate.dart';
import 'package:oshapp/shared/widgets/pdf_viewer_screen.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onConfirm;
  final VoidCallback? onPropose;
  final VoidCallback? onCancel;
  final bool isNurseView;
  final bool
      canSeePrivateInfo; // Whether user can see medicalInstructions and phone

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onConfirm,
    this.onPropose,
    this.onCancel,
    this.isNurseView = false,
    this.canSeePrivateInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Detect HR-initiated obligatory visits (incl. Embauche) to use 'Date limite'
    final bool isHrInitiatedObligatory = _isHrInitiatedObligatory(appointment);
    // Detect Reprise visits for special labeling
    final bool isRepriseVisit = _isRepriseVisit(appointment);
    // Build a single-line display for the employee who made the request
    // Prefer the creator when it's an EMPLOYEE, otherwise fall back to the appointment's employee fields.
    // Use backend-provided employee data directly (always non-null in model)
    final String employeeLine = ' ${appointment.employeeEmail}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: appointment.statusColor,
              width: 4,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête simplifiée: [Type]   Statut : <label>
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final String typeText =
                            appointment.typeDisplay ??
                                appointment.typeShortDisplay ??
                                appointment.type;
                        // Ensure 'Visite d\'Embauche' is clearly visible: allow more lines and no ellipsis
                        final bool isEmbauche = typeText.toLowerCase().contains('embauche') ||
                            appointment.type.toUpperCase().contains('PRE_RECRUITMENT') ||
                            appointment.type.toUpperCase().contains('PRE-RECRUITMENT');
                        return Text(
                          typeText,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: isEmbauche ? 3 : 2,
                          overflow:
                              isEmbauche ? TextOverflow.visible : TextOverflow.ellipsis,
                          softWrap: true,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(
                    isNurseView
                        ? (appointment.statusUiDisplayForNurse ??
                            appointment.statusUiDisplay ??
                            appointment.statusDisplay ??
                            '—')
                        : (appointment.statusUiDisplay ??
                            appointment.statusDisplay ??
                            '—'),
                    appointment.statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _simpleKV(theme, 'Salarié', employeeLine)),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                height: 16,
                thickness: 0.8,
                color: AppTheme.textLight.withOpacity(0.5),
              ),
              const SizedBox(height: 8),

              // Nurse-specific grouped layout when a slot has been proposed
              if (isNurseView &&
                  appointment.statusUiCategory == 'PROPOSED') ...[
                Text('Demande initiale :',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _simpleKV(
                    theme,
                    (isHrInitiatedObligatory || isRepriseVisit)
                        ? 'Date limite'
                        : 'Date demandée',
                    (isHrInitiatedObligatory || isRepriseVisit)
                        ? _formatDateCompactFr(appointment.requestedDateEmployee)
                        : _formatDateTimeCompactFr(appointment.requestedDateEmployee)),
                
                if (isRepriseVisit && _hasContent(appointment.reason)) ...[
                  const SizedBox(height: 6),
                  _simpleKV(
                      theme, 'Cas de reprise', appointment.reason!.trim()),
                ],
                if (_hasContent(appointment.motif)) ...[
                  const SizedBox(height: 6),
                  _simpleKV(theme, 'Motif', appointment.motif!.trim()),
                ],
                if (_hasContent(appointment.notes)) ...[
                  const SizedBox(height: 6),
                  _simpleKV(
                      theme,
                      (isHrInitiatedObligatory || isRepriseVisit)
                          ? 'Détails supplémentaires'
                          : 'Notes',
                      appointment.notes!.trim()),
                ],
                const SizedBox(height: 12),

                Text('Nouvelle proposition :',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _simpleKV(theme, 'Date proposée',
                    _formatDateTimeCompactFr(appointment.proposedDate)),
                const SizedBox(height: 6),
                _simpleKV(theme, 'Remarques', _orNeant(appointment.comments)),
                if (appointment.visitMode != null) ...[
                  const SizedBox(height: 6),
                  _simpleKV(theme, 'Modalité',
                      appointment.visitModeDisplay ?? 'Non spécifié'),
                ],
                const SizedBox(height: 16),
                // No actions when awaiting employee reply after a proposal
                const SizedBox.shrink(),
              ] else ...[
                // For HR-initiated obligatory visits, always show the initial request first
                if (isHrInitiatedObligatory &&
                    (appointment.statusUiCategory == 'PLANNED' ||
                        appointment.statusUiCategory == 'CONFIRMED' ||
                        appointment.statusUiCategory == 'CANCELLED')) ...[
                  Text('Demande initiale :',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _simpleKV(
                      theme,
                      (isHrInitiatedObligatory || isRepriseVisit)
                          ? 'Date limite'
                          : 'Date demandée',
                      _formatDateCompactFr(appointment.requestedDateEmployee)),
                      
                  if (isRepriseVisit && _hasContent(appointment.reason)) ...[
                    const SizedBox(height: 6),
                    _simpleKV(
                        theme, 'Cas de reprise', appointment.reason!.trim()),
                  ],
                  if (_hasContent(appointment.motif)) ...[
                    const SizedBox(height: 6),
                    _simpleKV(theme, 'Motif', appointment.motif!.trim()),
                  ],
                  if (_hasContent(appointment.notes)) ...[
                    const SizedBox(height: 6),
                    _simpleKV(
                        theme,
                        (isHrInitiatedObligatory || isRepriseVisit)
                            ? 'Détails supplémentaires'
                            : 'Notes',
                        appointment.notes!.trim()),
                  ],
                  if (appointment.visitMode != null) ...[
                    const SizedBox(height: 6),
                    _simpleKV(theme, 'Modalité',
                        appointment.visitModeDisplay ?? 'Non spécifié'),
                  ],
                  const SizedBox(height: 12),
                ],
                // Medical visit layout for PLANNED status
                if (appointment.statusUiCategory == 'PLANNED') ...[
                  _simpleKV(theme, 'Date proposée',
                      _formatDateTimeCompactFr(appointment.appointmentDate)),
                  const SizedBox(height: 8),
                  _simpleKV(theme, 'Modalité',
                      appointment.visitModeDisplay ?? 'Non spécifié'),
                  const SizedBox(height: 8),
                  if (canSeePrivateInfo &&
                      appointment.medicalInstructions != null &&
                      appointment.medicalInstructions!.trim().isNotEmpty) ...[
                    _simpleKV(theme, 'Consignes ou remarques',
                        appointment.medicalInstructions!),
                    const SizedBox(height: 8),
                  ],
                  if (canSeePrivateInfo &&
                      appointment.medicalServicePhone != null &&
                      appointment.medicalServicePhone!.trim().isNotEmpty) ...[
                    _simpleKV(theme, 'Contact service médical',
                        appointment.medicalServicePhone!),
                    const SizedBox(height: 8),
                  ],
                ] else if (appointment.statusUiCategory == 'CONFIRMED' &&
                    appointment.medicalInstructions != null) ...[
                  // Medical visit confirmed layout
                  _simpleKV(theme, 'Date confirmée',
                      _formatDateTimeCompactFr(appointment.appointmentDate)),
                  // const SizedBox(height: 8),
                  // _simpleKV(theme, 'Modalité',
                  //     appointment.visitModeDisplay ?? 'Non spécifié'),
                  const SizedBox(height: 8),
                  if (canSeePrivateInfo &&
                      appointment.medicalInstructions!.trim().isNotEmpty) ...[
                    _simpleKV(theme, 'Consignes ou remarques',
                        appointment.medicalInstructions!),
                    const SizedBox(height: 8),
                  ],
                  if (canSeePrivateInfo &&
                      appointment.medicalServicePhone != null &&
                      appointment.medicalServicePhone!.trim().isNotEmpty) ...[
                    _simpleKV(theme, 'Contact service médical',
                        appointment.medicalServicePhone!),
                    const SizedBox(height: 8),
                  ],
                ] else ...[
                  // Default compact layout for regular appointments
                  _simpleKV(
                      theme,
                      (isHrInitiatedObligatory || isRepriseVisit)
                          ? 'Date limite'
                          : 'Date demandée',
                      (isHrInitiatedObligatory || isRepriseVisit)
                          ? _formatDateCompactFr(appointment.requestedDateEmployee)
                          : _formatDateTimeCompactFr(appointment.requestedDateEmployee)),
                  const SizedBox(height: 8),
                  if (isRepriseVisit && _hasContent(appointment.reason))
                    _simpleKV(
                        theme, 'Cas de reprise', appointment.reason!.trim()),
                  if (_hasContent(appointment.motif))
                    _simpleKV(theme, 'Motif', appointment.motif!.trim()),
                  if (_hasContent(appointment.notes))
                    _simpleKV(
                        theme,
                        (isHrInitiatedObligatory || isRepriseVisit)
                            ? 'Détails supplémentaires'
                            : 'Notes',
                        appointment.notes!.trim()),
                  const SizedBox(height: 8),
                ],
                if (appointment.proposedDate != null &&
                    (appointment.statusUiCategory == 'PROPOSED' ||
                        appointment.statusUiCategory == 'CANCELLED' ||
                        appointment.statusUiCategory == 'CONFIRMED')) ...[
                  const SizedBox(height: 4),
                  Text('Nouvelle proposition :',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _simpleKV(theme, 'Date proposée',
                      _formatDateTimeCompactFr(appointment.proposedDate)),
                  const SizedBox(height: 6),
                  _simpleKV(theme, 'Remarques', _orNeant(appointment.comments)),
                  // if (appointment.visitMode != null) ...[
                  //   const SizedBox(height: 6),
                  //   _simpleKV(theme, 'Modalité',
                  //       appointment.visitModeDisplay ?? 'Non spécifié'),
                  // ],
                  const SizedBox(height: 8),
                ],
                if (appointment.statusUiCategory == 'CANCELLED') ...[
                  const SizedBox(height: 8),
                  _simpleKV(theme, 'Date annulée',
                      _formatDateTimeCompactFr(appointment.appointmentDate)),
                  const SizedBox(height: 8),
                  _simpleKV(theme, 'Modalité',
                      appointment.visitModeDisplay ?? 'Non spécifié'),
                  if (appointment.medicalInstructions != null) ...[
                    // Medical visit cancelled layout
                    // _simpleKV(theme, 'Date initialement proposée',
                    //     _formatDateTimeCompactFr(appointment.appointmentDate)),
                    // const SizedBox(height: 8),
                    // _simpleKV(theme, 'Modalité',
                    //     appointment.visitModeDisplay ?? 'Non spécifié'),
                    const SizedBox(height: 8),
                    if (canSeePrivateInfo &&
                        appointment.medicalInstructions!.trim().isNotEmpty) ...[
                      _simpleKV(theme, 'Consignes ou remarques',
                          appointment.medicalInstructions!),
                      const SizedBox(height: 8),
                    ],
                    _simpleKV(theme, 'Motif d\'annulation',
                        _orNeant(appointment.cancellationReason)),
                    const SizedBox(height: 8),
                    if (canSeePrivateInfo &&
                        appointment.medicalServicePhone != null &&
                        appointment.medicalServicePhone!.trim().isNotEmpty) ...[
                      _simpleKV(theme, 'Contact service médical',
                          appointment.medicalServicePhone!),
                      const SizedBox(height: 8),
                    ],
                  ] else ...[
                    // Regular appointment cancelled layout
                    // const SizedBox(height: 4),
                    // Text('Annulation :',
                    //     style: theme.textTheme.titleSmall
                    //         ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _simpleKV(theme, 'Motif d\'annulation',
                        _orNeant(appointment.cancellationReason)),
                    const SizedBox(height: 8),
                  ],
                ],
                // Afficher le mode de visite si le rendez-vous est confirmé
                if (appointment.statusUiCategory == 'CONFIRMED' &&
                    appointment.visitMode != null)
                  _simpleKV(theme, 'Modalité',
                      appointment.visitModeDisplay ?? 'Non spécifié'),
              ],
              const SizedBox(height: 16),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  // Detect HR-initiated obligatory visits (including Embauche) to display 'Date limite'
  bool _isHrInitiatedObligatory(Appointment a) {
    // Use normalized role detection from User.hasRole()
    final bool byHr = a.createdBy?.hasRole('HR') ?? false;
    // Robust Embauche detection via formatted and raw type tokens
    final String tDisp =
        (a.typeDisplay ?? a.typeShortDisplay ?? '').toLowerCase();
    final String tRaw = a.type.toUpperCase();
    final bool isEmbauche = tDisp.contains('embauche') ||
        tRaw.contains('EMBAUCHE') ||
        tRaw.contains('PRE_RECRUITMENT') ||
        tRaw.contains('PRE-RECRUITMENT') ||
        tRaw.contains('PRE_EMPLOYMENT') ||
        tRaw.contains('PRE-EMPLOYMENT');
    // Consider deadline context when obligatory and initiated by HR, or explicitly Embauche
    return (a.obligatory && byHr) || isEmbauche;
  }

  // Detect Reprise visits for special labeling
  bool _isRepriseVisit(Appointment a) {
    final String tDisp =
        (a.typeDisplay ?? a.typeShortDisplay ?? '').toLowerCase();
    final String tRaw = a.type.toUpperCase();
    return tDisp.contains('reprise') ||
        tRaw.contains('REPRISE') ||
        tRaw.contains('RETURN_TO_WORK');
  }

  // Opens the latest uploaded medical certificate for the appointment's employee
  Future<void> _openLatestCertificateInline(BuildContext context) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final List<UploadedMedicalCertificate> all = await api
          .getUploadedMedicalCertificatesForEmployee(appointment.employeeId);
      final int empId = appointment.employeeId;
      final certs = all
          .where((c) =>
              c.employeeId == empId &&
              (c.filePath != null && c.filePath!.trim().isNotEmpty))
          .toList();
      if (certs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun certificat disponible.')),
        );
        return;
      }
      bool _isReturnToWorkType(String? t) {
        if (t == null) return false;
        final low = t.toLowerCase();
        return low.contains('reprise') ||
            low.contains('return_to_work') ||
            low.contains('return to work') ||
            low.contains('retour') ||
            low.contains('reprise du travail');
      }

      final List<UploadedMedicalCertificate> preferred =
          certs.where((c) => _isReturnToWorkType(c.certificateType)).toList();
      final List<UploadedMedicalCertificate> pool =
          preferred.isNotEmpty ? preferred : certs;
      pool.sort((a, b) => b.issueDate.compareTo(a.issueDate));
      final String? filePath = pool.first.filePath;
      final String? url = api.getPublicFileUrl(filePath);
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL du certificat invalide.')),
        );
        return;
      }
      // Open inside the app via embedded PDF viewer screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: url,
            title: 'Certificat médical',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de l\'ouverture du certificat: $e')),
      );
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    // Use backend-provided action flags to determine button visibility
    // Backend logic determines availability based on user role and appointment status
    final actions = <Widget>[];
    // Precompute flags for certificate button visibility
    final bool _isReprise = _isRepriseVisit(appointment);
    // When a slot has been proposed and we're waiting for the employee's reply,
    // nurses should not propose another slot until the employee responds.
    final bool _awaitingEmployeeReply =
        isNurseView && appointment.statusUiCategory == 'PROPOSED';

    // Show confirm button if backend allows and callback is provided
    if (appointment.canConfirm && onConfirm != null) {
      actions.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Confirmer'),
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successColor,
            foregroundColor: AppTheme.textOnPrimary,
          ),
        ),
      );
    }

    // Show propose button if backend allows and callback is provided,
    // but hide it for nurses while awaiting employee reply to a proposal.
    if (!_awaitingEmployeeReply && appointment.canPropose && onPropose != null) {
      actions.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_calendar_outlined, size: 16),
          label: const Text('Proposer un créneau'),
          onPressed: onPropose,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.infoColor,
            side: const BorderSide(color: AppTheme.infoColor),
          ),
        ),
      );
    }

    // Show cancel button if backend allows and callback is provided
    if (appointment.canCancel && onCancel != null) {
      actions.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Annuler'),
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: const BorderSide(color: AppTheme.errorColor),
          ),
        ),
      );
    }

    // Always show certificate button for nurses on Reprise visits,
    // regardless of status (confirmed/cancelled/others)
    if (isNurseView && _isReprise) {
      actions.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.visibility_rounded, size: 16),
          label: const Text('Voir le certificat'),
          onPressed: () => _openLatestCertificateInline(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.infoColor,
            side: const BorderSide(color: AppTheme.infoColor),
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.end,
      children: actions,
    );
  }

  Widget _simpleKV(ThemeData theme, String label, String value) {
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label : ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          TextSpan(
            text: value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      softWrap: true,
    );
  }

  // Petit badge de statut
  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // Helper pour vérifier si un champ texte a un contenu réel
  bool _hasContent(String? v) {
    if (v == null) return false;
    final t = v.trim();
    if (t.isEmpty) return false;
    final l = t.toLowerCase();
    if (l == 'n/a' ||
        l == 'na' ||
        l == 'n.a.' ||
        l == 'néant' ||
        l == 'neant') {
      return false;
    }
    return true;
  }

  String _orNeant(String? v) {
    if (v == null) return 'Néant';
    final t = v.trim();
    if (t.isEmpty || t.toUpperCase() == 'N/A') return 'Néant';
    return t;
  }

  // Format date without time for deadlines/requested dates
  String _formatDateCompactFr(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  String _formatDateTimeCompactFr(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(date);
  }
}
