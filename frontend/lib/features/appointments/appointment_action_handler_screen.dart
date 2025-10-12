import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/models/appointment.dart';

class AppointmentActionHandlerScreen extends StatefulWidget {
  final int appointmentId;
  final String? action; // view | confirm | propose | cancel

  const AppointmentActionHandlerScreen(
      {super.key, required this.appointmentId, this.action});

  @override
  State<AppointmentActionHandlerScreen> createState() =>
      _AppointmentActionHandlerScreenState();
}

class _AppointmentActionHandlerScreenState
    extends State<AppointmentActionHandlerScreen> {
  bool _started = false;
  late ApiService _api;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = Provider.of<ApiService>(context, listen: false);
    if (!_started) {
      _started = true;
      // Defer to next frame to ensure context is fully ready
      WidgetsBinding.instance.addPostFrameCallback((_) => _process());
    }
  }

  Future<void> _process() async {
    final action = (widget.action ?? 'view').toLowerCase();
    try {
      if (action == 'confirm') {
        await _api.confirmAppointment(widget.appointmentId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Rendez-vous confirmé.'),
              backgroundColor: Colors.green),
        );
        // Navigate to details after confirm
        return;
      }

      if (action == 'cancel') {
        final reason = await _askCancelReason();
        if (!mounted) return;
        if (reason == null || reason.trim().isEmpty) {
          return;
        }
        await _api.cancelAppointment(widget.appointmentId,
            reason: reason.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Rendez-vous annulé.'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).maybePop();
        return;
      }

      // For view/propose we need appointment details
      final appointment = await _api.getAppointmentById(widget.appointmentId);

      if (!mounted) return;
      if (action == 'propose') {
        // Navigate to the Propose Slot screen with the loaded appointment
        Navigator.of(context).pushNamed(
          '/propose-slot',
          arguments: appointment,
        );
        return;
      }

      // Default: open details
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
      Navigator.of(context).maybePop();
    }
  }

  Future<String?> _askCancelReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Motif d\'annulation'),
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
                child: const Text('Retour')),
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
  }

  @override
  Widget build(BuildContext context) {
    // Simple placeholder while processing
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
