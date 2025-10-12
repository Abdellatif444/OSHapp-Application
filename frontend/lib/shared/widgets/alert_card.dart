import 'package:flutter/material.dart';

class AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String date;
  final Color color;
  final Color iconColor;
  final VoidCallback? onConfirm;
  final VoidCallback? onPropose;
  final String confirmLabel;
  final String proposeLabel;

  const AlertCard({
    super.key,
    required this.icon,
    required this.title,
    required this.date,
    required this.color,
    required this.iconColor,
    this.onConfirm,
    this.onPropose,
    this.confirmLabel = 'Confirm',
    this.proposeLabel = 'Propose Slot',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: color, // The light background color
          border: Border(
            left: BorderSide(
              color: iconColor, // The accent color
              width: 5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onConfirm != null)
                    TextButton(
                      onPressed: onConfirm,
                      child: Text(confirmLabel),
                    ),
                  const SizedBox(width: 8),
                  if (onPropose != null)
                    ElevatedButton(
                      onPressed: onPropose,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(proposeLabel),
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
