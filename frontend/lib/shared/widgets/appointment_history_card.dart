import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../config/app_theme.dart';

class AppointmentHistoryCard extends StatelessWidget {
  final Appointment appointment;

  const AppointmentHistoryCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = appointment.statusColor;
    final statusIcon = _getStatusIconFromCategory(appointment.statusUiCategory ?? 'REQUESTED');

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.employeeName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.typeDisplay ?? 'Visite médicale',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  if (appointment.updatedAt != null)
                    Text(
                      'Traité le: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(appointment.updatedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (appointment.statusUiDisplay ?? 'En cours').toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIconFromCategory(String category) {
    switch (category.toUpperCase()) {
      case 'COMPLETED':
        return Icons.verified_outlined;
      case 'CONFIRMED':
        return Icons.check_circle_outline;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'PROPOSED':
        return Icons.history_outlined;
      case 'REQUESTED':
        return Icons.hourglass_empty_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
