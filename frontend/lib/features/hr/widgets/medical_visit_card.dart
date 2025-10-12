import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/features/hr/medical_certificates_screen.dart';

class MedicalVisitCard extends StatelessWidget {
  final Appointment appointment;
  final Employee? employee;
  final VoidCallback? onShowEmployeeInfo;
  final VoidCallback? onConfirm;
  final VoidCallback? onPropose;
  final VoidCallback? onCancel;

  const MedicalVisitCard({
    super.key,
    required this.appointment,
    this.employee,
    this.onShowEmployeeInfo,
    this.onConfirm,
    this.onPropose,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scenario detection (purely UI)
    final isEmbauche = _isEmbauche(appointment);
    final isReprise = _isReprise(appointment);
    // HR-initiated obligatory (incl. Embauche) for deadline label consistency
    final isHrInitiatedObligatory = _isHrInitiatedObligatory(appointment);
    // Use backend-provided display values for type and status
    final String typeHeader = appointment.typeDisplay ??
        appointment.typeShortDisplay ??
        appointment.type;
    final String statusText =
        appointment.statusUiDisplay ?? appointment.statusDisplay ?? '—';
    // Determine where to show the visit modality to avoid duplication across sections
    final bool isConfirmed = appointment.statusUiCategory == 'CONFIRMED';
    final bool isCancelled = appointment.statusUiCategory == 'CANCELLED';
    final bool showModalityInProposed = appointment.proposedDate != null &&
        appointment.statusUiCategory == 'PROPOSED' &&
        _hasContent(appointment.visitModeDisplay);

    // Build employee line (name + email)
    final empFullName = (employee?.fullName ?? '').trim();
    final apptName = appointment.employeeName.trim();
    final fallbackName = apptName.isEmpty || apptName.toUpperCase() == 'N/A'
        ? 'Employé non spécifié'
        : apptName;
    final namePart = empFullName.isNotEmpty ? empFullName : fallbackName;
    final emailPart = ((employee?.email ?? appointment.employeeEmail).trim());
    final employeeLine = (emailPart.isNotEmpty && emailPart.toUpperCase() != 'N/A')
        ? '$namePart - $emailPart'
        : namePart;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive font sizing based on card width
        final cardWidth = constraints.maxWidth;
        final baseFontSize = _getResponsiveFontSize(cardWidth);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 120),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          typeHeader,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: baseFontSize * 1.2,
                            color: theme.colorScheme.onSurface,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: appointment.statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: appointment.statusColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: appointment.statusColor,
                            fontSize: baseFontSize * 0.85,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                      theme, (isEmbauche || isReprise) ? 'Salarié' : 'Employé', employeeLine, baseFontSize),
                  const SizedBox(height: 12),
                  if (!isEmbauche &&
                      _hasContent(appointment.visitModeDisplay) &&
                      !isConfirmed &&
                      !isCancelled &&
                      !showModalityInProposed) ...[
                    _buildInfoRow(
                      theme,
                      'Modalité',
                      appointment.visitModeDisplay!.trim(),
                      baseFontSize,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _buildInfoRow(
                    theme,
                    (isHrInitiatedObligatory || isReprise) ? 'Date limite' : 'Date demandée',
                    appointment.requestedDateEmployee != null
                        ? _formatDateTimeCompactFr(
                            appointment.requestedDateEmployee!)
                        : 'Non spécifiée',
                    baseFontSize,
                  ),
                  const SizedBox(height: 10),
                  if (isReprise && (appointment.reason != null && appointment.reason!.trim().isNotEmpty)) ...[
                    _buildInfoRow(
                      theme,
                      'Cas de reprise',
                      appointment.reason!.trim(),
                      baseFontSize,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!isEmbauche && _hasContent(appointment.motif)) ...[
                    _buildInfoRow(
                      theme,
                      'Motif',
                      appointment.motif!.trim(),
                      baseFontSize,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_hasContent(appointment.notes)) ...[
                    _buildInfoRow(
                      theme,
                      (isHrInitiatedObligatory || isReprise) ? 'Détails supplémentaires' : 'Notes',
                      appointment.notes!.trim(),
                      baseFontSize,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Append updates below the initial info to preserve context
                  if (appointment.proposedDate != null &&
                      (appointment.statusUiCategory == 'PROPOSED' ||
                          appointment.statusUiCategory == 'CANCELLED' ||
                          appointment.statusUiCategory == 'CONFIRMED')) ...[
                    Text(
                      'Nouvelle proposition :',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: baseFontSize,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      theme,
                      'Date proposée',
                      appointment.proposedDate != null
                          ? _formatDateTimeCompactFrWithTime(
                              appointment.proposedDate!)
                          : '—',
                      baseFontSize,
                    ),
                    if (_hasContent(appointment.comments)) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        theme,
                        'Remarques',
                        appointment.comments!.trim(),
                        baseFontSize,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        softWrap: true,
                      ),
                    ],
                    if (showModalityInProposed) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        theme,
                        'Modalité',
                        appointment.visitModeDisplay!.trim(),
                        baseFontSize,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  if (appointment.statusUiCategory == 'CONFIRMED') ...[
                    Text(
                      'Confirmation :',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: baseFontSize,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      theme,
                      'Date confirmée',
                      appointment.appointmentDate != null
                          ? _formatDateTimeCompactFrWithTime(
                              appointment.appointmentDate!)
                          : '—',
                      baseFontSize,
                    ),
                    if (_hasContent(appointment.visitModeDisplay)) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        theme,
                        'Modalité',
                        appointment.visitModeDisplay!.trim(),
                        baseFontSize,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  if (appointment.statusUiCategory == 'CANCELLED') ...[
                    Text(
                      'Annulation :',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: baseFontSize,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      theme,
                      'Date annulée',
                      appointment.appointmentDate != null
                          ? _formatDateTimeCompactFrWithTime(
                              appointment.appointmentDate!)
                          : '—',
                      baseFontSize,
                    ),
                    if (_hasContent(appointment.cancellationReason)) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        theme,
                        "Motif d'annulation",
                        appointment.cancellationReason!.trim(),
                        baseFontSize,
                      ),
                    ],
                    if (_hasContent(appointment.visitModeDisplay)) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        theme,
                        'Modalité',
                        appointment.visitModeDisplay!.trim(),
                        baseFontSize,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  _buildActionButtons(context, baseFontSize),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _getResponsiveFontSize(double cardWidth) {
    if (cardWidth < 300) return 12.0;
    if (cardWidth < 400) return 14.0;
    if (cardWidth < 600) return 15.0;
    return 16.0;
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value,
    double baseFontSize, {
    int? maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
    bool softWrap = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: baseFontSize * 0.9,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: baseFontSize * 0.9,
            ),
            maxLines: maxLines,
            overflow: overflow,
            softWrap: softWrap,
          ),
        ),
      ],
    );
  }

  String _formatDateTimeCompactFr(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  String _formatDateTimeCompactFrWithTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(dateTime);
  }

  bool _hasContent(String? value) {
    if (value == null) return false;
    final v = value.trim();
    if (v.isEmpty) return false;
    final lower = v.toLowerCase();
    // Consider common placeholders as non-content
    if (lower == 'n/a' || lower == 'na') return false;
    if (lower == 'non spécifié' || lower == 'non specifie') return false;
    if (lower == "aucune raison d'annulation" || lower == 'aucune raison d’annulation') return false;
    if (v == '—' || v == '-') return false;
    return true;
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

  // Detect Reprise (Return to Work) visits
  bool _isReprise(Appointment a) {
    final String tDisp = (a.typeDisplay ?? a.typeShortDisplay ?? '').toLowerCase();
    if (tDisp.contains('reprise')) return true;
    final String t = a.type.toUpperCase();
    return t.contains('RETURN_TO_WORK') || t.contains('REPRISE');
  }

  // Detect HR-initiated obligatory appointments for consistent 'Date limite' label
  bool _isHrInitiatedObligatory(Appointment a) {
    final bool byHr = a.createdBy?.hasRole('HR') ?? false; // handles 'RH' via normalization
    return (a.obligatory && byHr) || _isEmbauche(a);
  }

  Widget _buildActionButtons(BuildContext context, double baseFontSize) {
    final actions = <Widget>[];
    final bool isReprise = _isReprise(appointment);

    // Show confirm button only if backend allows and callback is provided
    if (appointment.canConfirm && onConfirm != null) {
      actions.add(
        ElevatedButton.icon(
          icon: Icon(Icons.check, size: baseFontSize + 2),
          label: Text(
            'Confirmer',
            style: TextStyle(
              fontSize: baseFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      );
    }

    // Show certificates button for Reprise visits
    if (isReprise) {
      actions.add(
        OutlinedButton.icon(
          icon: Icon(Icons.picture_as_pdf_outlined, size: baseFontSize + 2),
          label: Text(
            'Voir certificats',
            style: TextStyle(
              fontSize: baseFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => MedicalCertificatesScreen(
                  employeeId: appointment.employeeId,
                  employeeName: appointment.employeeName,
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: const BorderSide(color: Colors.deepPurple, width: 1.5),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // Show propose button only if backend allows and callback is provided
    if (appointment.canPropose && onPropose != null) {
      actions.add(
        OutlinedButton.icon(
          icon: Icon(Icons.edit_calendar_outlined, size: baseFontSize + 2),
          label: Text(
            'Proposer un créneau',
            style: TextStyle(
              fontSize: baseFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onPropose,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue,
            side: const BorderSide(color: Colors.blue, width: 1.5),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // Show cancel button only if backend allows and callback is provided
    if (appointment.canCancel && onCancel != null) {
      actions.add(
        OutlinedButton.icon(
          icon: Icon(Icons.close, size: baseFontSize + 2),
          label: Text(
            'Annuler',
            style: TextStyle(
              fontSize: baseFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red, width: 1.5),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // Show employee info button if callback is provided
    if (onShowEmployeeInfo != null) {
      actions.add(
        OutlinedButton.icon(
          icon: Icon(Icons.person, size: baseFontSize + 2),
          label: Text(
            'Infos salarié',
            style: TextStyle(
              fontSize: baseFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onShowEmployeeInfo,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            side: BorderSide(color: Colors.grey[400]!, width: 1.5),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      alignment: WrapAlignment.end,
      children: actions,
    );
  }
}
