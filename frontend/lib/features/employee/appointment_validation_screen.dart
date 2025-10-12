import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/widgets/app_logo.dart';

class AppointmentValidationScreen extends StatefulWidget {
  final Appointment appointment;
  
  const AppointmentValidationScreen({
    super.key, 
    required this.appointment,
  });

  @override
  State<AppointmentValidationScreen> createState() => _AppointmentValidationScreenState();
}

class _AppointmentValidationScreenState extends State<AppointmentValidationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportReasonController = TextEditingController();
  final _commentsController = TextEditingController();
  
  String _selectedAction = 'CONFIRM'; // CONFIRM ou CANCEL
  bool _isLoading = false;
  bool _acknowledgeManagerComments = false;
  


  @override
  void dispose() {
    _reportReasonController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submitValidation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      if (_selectedAction == 'CONFIRM') {
        await apiService.confirmAppointment(widget.appointment.id);
      } else { // CANCEL
        final reason = _reportReasonController.text.trim();
        await apiService.cancelAppointment(widget.appointment.id, reason: reason);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedAction == 'CONFIRM'
                ? 'Rendez-vous confirmé !'
                : 'Rendez-vous annulé !'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        // Navigue en arrière et signale un succès pour rafraîchir la liste précédente.
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'opération: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Validation du Rendez-vous',
          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWorkflowHeader(theme),
              const SizedBox(height: 24),
              _buildAppointmentSummary(theme),
              const SizedBox(height: 24),
              _buildActionSelection(theme),
              const SizedBox(height: 24),
              if (_selectedAction == 'CANCEL') _buildReportForm(theme),
              const SizedBox(height: 32),
              _buildSubmitButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const AppLogo(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finalisez votre rendez-vous',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confirmez ou annulez la proposition.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildWorkflowStep(theme, '1', 'Demande', true),
              _buildWorkflowConnector(theme),
              _buildWorkflowStep(theme, '2', 'Proposition', true),
              _buildWorkflowConnector(theme),
              _buildWorkflowStep(theme, '3', 'Validation', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep(ThemeData theme, String number, String label, bool isActive) {
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : theme.colorScheme.surface,
            border: Border.all(
              color: isActive ? activeColor : inactiveColor,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isActive ? theme.colorScheme.onPrimary : inactiveColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isActive ? activeColor : inactiveColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowConnector(ThemeData theme) {
    return Container(
      width: 20,
      height: 2,
      color: theme.colorScheme.primary,
      margin: const EdgeInsets.only(bottom: 20),
    );
  }

  Widget _buildAppointmentSummary(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5))
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Récapitulatif du Rendez-vous', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildSummaryRow(theme, 'Type de visite', widget.appointment.typeDisplay ?? 'Visite médicale'),
            _buildSummaryRow(theme, 'Date proposée',
                widget.appointment.proposedDate != null
                    ? _formatDateTime(widget.appointment.proposedDate!)
                    : 'Non définie'),
            if (widget.appointment.comments != null && widget.appointment.comments!.isNotEmpty)
              _buildSummaryRow(theme, 'Commentaires du service médical', widget.appointment.comments!),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Veuillez confirmer votre présence ou demander un report avant la date proposée.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.appointment.comments != null && widget.appointment.comments!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: CheckboxListTile(
                  title: const Text('Je reconnais avoir lu les commentaires du manager.'),
                  value: _acknowledgeManagerComments,
                  onChanged: (bool? value) {
                    setState(() {
                      _acknowledgeManagerComments = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Votre décision', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            RadioListTile<String>(
              title: const Text('Confirmer le rendez-vous'),
              subtitle: const Text('J''accepte la date et l''heure proposées.'),
              value: 'CONFIRM',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
              activeColor: theme.colorScheme.primary,
            ),
            RadioListTile<String>(
              title: const Text('Annuler le rendez-vous'),
              subtitle: const Text('Je ne peux pas assister à ce rendez-vous.'),
              value: 'CANCEL',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
              activeColor: theme.colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportForm(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.errorContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_calendar, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Annulation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Motif d\'annulation (obligatoire)', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reportReasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Expliquez la raison de l\'annulation...',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le motif est obligatoire'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    final isConfirm = _selectedAction == 'CONFIRM';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitValidation,
        style: ElevatedButton.styleFrom(
          backgroundColor: isConfirm ? theme.colorScheme.primary : theme.colorScheme.error,
          foregroundColor: isConfirm ? theme.colorScheme.onPrimary : theme.colorScheme.onError,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(isConfirm ? 'Confirmer Définitivement' : 'Annuler le Rendez-vous'),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
