import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/widgets/appointment_card.dart';
import 'package:oshapp/shared/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';

class MedicalRequestsScreen extends StatefulWidget {
  const MedicalRequestsScreen({super.key});

  @override
  State<MedicalRequestsScreen> createState() => _MedicalRequestsScreenState();
}

class _MedicalRequestsScreenState extends State<MedicalRequestsScreen> {
  late final ApiService _apiService;
  List<Appointment> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // ApiService is fetched here and not in _loadRequests to ensure it's available
    // for other methods like _submitProposal without needing to pass it around.
    _apiService = Provider.of<ApiService>(context, listen: false);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response =
          await _apiService.getAppointments({'status': 'REQUESTED'});
      if (mounted) {
        setState(() {
          _requests = response['appointments'] as List<Appointment>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _proposeSlot(Appointment request) async {
    // Navigate to the propose slot screen
    final result = await Navigator.of(context).pushNamed(
      '/propose-slot',
      arguments: request,
    );
    
    if (result == true) {
      // Refresh the list if the proposal was successful
      _loadRequests();
    }
  }

  Future<void> _submitProposal(
      int appointmentId, DateTime date, String motif, String? visitMode) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _apiService.proposeAppointmentSlot(
        appointmentId: appointmentId,
        proposedDate: date,
        comments: motif,
        visitMode: visitMode,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposition envoyée avec succès.')),
        );
        _loadRequests(); // Refresh list
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la proposition: $e')),
        );
      }
    }
  }

  void _showDetails(Appointment req) {
    final String requestedLabel = _isHrInitiatedObligatory(req)
        ? 'Date limite'
        : 'Date demandée';
    final String notesLabel = _isHrInitiatedObligatory(req)
        ? 'Détails supplémentaires'
        : 'Notes';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détails de la demande'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Employé: ${req.employeeName}'),
              const SizedBox(height: 8),
              Text(
                  '$requestedLabel: ${DateFormat('dd/MM/yyyy HH:mm').format(req.requestedDateEmployee!)}'),
              const SizedBox(height: 8),
              Text('Type: ${req.type}'),
              const SizedBox(height: 8),
              Text('Motif initial: ${req.reason ?? 'Non spécifié'}'),
              const SizedBox(height: 8),
              if (req.notes != null && req.notes!.trim().isNotEmpty) ...[
                Text('$notesLabel: ${req.notes!.trim()}'),
                const SizedBox(height: 8),
              ],
              Text('Statut: ${req.statusUiDisplay}',
                  style: TextStyle(
                      color: req.statusColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // Detect HR-initiated obligatory appointments (incl. Embauche) to display 'Date limite'
  bool _isHrInitiatedObligatory(Appointment a) {
    final bool byHr = a.createdBy?.roles.any((r) {
          final t = r.trim().toUpperCase();
          if (t.startsWith('ROLE_')) {
            final s = t.substring(5);
            return s == 'HR' || s == 'RH';
          }
          return t == 'HR' || t == 'RH';
        }) ??
        false;
    final String tDisp = (a.typeDisplay ?? a.typeShortDisplay ?? '').toLowerCase();
    final String tRaw = a.type.toUpperCase();
    final bool isEmbauche = tDisp.contains('embauche') ||
        tRaw.contains('EMBAUCHE') ||
        tRaw.contains('PRE_RECRUITMENT') ||
        tRaw.contains('PRE-RECRUITMENT') ||
        tRaw.contains('PRE_EMPLOYMENT') ||
        tRaw.contains('PRE-EMPLOYMENT');
    return (a.obligatory && byHr) || isEmbauche;
  }

  Future<void> _confirmAppointment(Appointment appointment) async {
    final visitMode = await _showVisitModeDialog();
    if (visitMode == null) return;

    final confirmed = await showConfirmDialog(context);
    if (!confirmed) return;

    try {
      await _apiService.confirmAppointment(appointment.id, visitMode: visitMode);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rendez-vous confirmé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadRequests();
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

  Future<String?> _showVisitModeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        String selectedMode = 'IN_PERSON';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text('Modalité'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Veuillez choisir la modalité :'),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Présentiel'),
                    value: 'IN_PERSON',
                    groupValue: selectedMode,
                    onChanged: (value) {
                      setState(() => selectedMode = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('À distance'),
                    value: 'REMOTE',
                    groupValue: selectedMode,
                    onChanged: (value) {
                      setState(() => selectedMode = value!);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedMode),
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleAction(String action, Appointment req) {
    if (action == 'proposer') {
      _proposeSlot(req);
    } else if (action == 'confirmer') {
      _confirmAppointment(req);
    } else if (action == 'voir') {
      _showDetails(req);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Demandes de Rendez-vous'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRequests,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Erreur: $_error'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                          onPressed: _loadRequests,
                          child: const Text('Réessayer')),
                    ],
                  ))
                : _requests.isEmpty
                    ? const Center(child: Text('Aucune demande en attente.'))
                    : RefreshIndicator(
                        onRefresh: _loadRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final req = _requests[index];
                            return AppointmentCard(
                              appointment: req,
                              onConfirm: () => _confirmAppointment(req),
                              onPropose: () => _proposeSlot(req),
                            );
                          },
                        ),
                      ));
  }
}
