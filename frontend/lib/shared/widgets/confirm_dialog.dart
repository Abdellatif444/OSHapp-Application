import 'package:flutter/material.dart';

/// Reusable confirmation dialog for appointment actions.
/// Returns true if the user confirms, false otherwise.
Future<bool> showConfirmDialog(
  BuildContext context, {
  String title = 'Confirmer le rendez-vous',
  String content = 'Voulez-vous confirmer ce rendez-vous ?\nCette action notifiera les parties concernées.',
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.check),
          label: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
