import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:oshapp/shared/models/appointment_request.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'package:animated_background/animated_background.dart';

class RequestAppointmentScreen extends StatefulWidget {
  const RequestAppointmentScreen({super.key});

  @override
  RequestAppointmentScreenState createState() =>
      RequestAppointmentScreenState();
}

class RequestAppointmentScreenState extends State<RequestAppointmentScreen>
    with TickerProviderStateMixin {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  String _visitMode = 'IN_PERSON';
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitRequest() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date et une heure.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final employee = auth.employee ?? auth.user?.employee;
    final empId = int.tryParse(employee?.id ?? '');
    if (employee == null || empId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil employé introuvable ou ID employé invalide.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final requestedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final request = AppointmentRequest(
      employeeId: empId,
      motif: _reasonController.text.isEmpty ? null : _reasonController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      requestedDateEmployee: requestedDateTime.toIso8601String(),
      visitMode: _visitMode,
    );

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.createAppointment(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande de rendez-vous envoyée avec succès.')),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi de la demande: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demander un Rendez-vous')),
      body: AnimatedBackground(
        behaviour: RandomParticleBehaviour(
          options: ParticleOptions(
            baseColor: Colors.red.shade700,
            spawnOpacity: 0.0,
            opacityChangeRate: 0.25,
            minOpacity: 0.1,
            maxOpacity: 0.3,
            particleCount: 70,
            spawnMaxRadius: 15.0,
            spawnMinRadius: 10.0,
            spawnMaxSpeed: 50.0,
            spawnMinSpeed: 30,
          ),
        ),
        vsync: this,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 20,
                      spreadRadius: 5)
                ],
              ),
              child: Form(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(labelText: 'Motif'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                          labelText: 'Notes (facultatif)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _visitMode,
                      decoration:
                          const InputDecoration(labelText: 'Modalité'),
                      items: const [
                        DropdownMenuItem(
                            value: 'IN_PERSON', child: Text('Sur site')),
                        DropdownMenuItem(
                            value: 'REMOTE', child: Text('À distance')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _visitMode = value;
                          });
                        }
                      },
                      validator: (value) => value == null ? 'Veuillez choisir une modalité' : null,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Date souhaitée'),
                      subtitle: Text(_selectedDate == null
                          ? 'Aucune date sélectionnée'
                          : DateFormat.yMMMd('fr_FR').format(_selectedDate!)),
                      trailing:
                          const Icon(Icons.calendar_today, color: Colors.red),
                      onTap: () => _pickDate(context),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Heure souhaitée'),
                      subtitle: Text(_selectedTime == null
                          ? 'Aucune heure sélectionnée'
                          : _selectedTime!.format(context)),
                      trailing:
                          const Icon(Icons.access_time, color: Colors.red),
                      onTap: () => _pickTime(context),
                    ),
                    const SizedBox(height: 32),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitRequest,
                            child: const Text('Envoyer la Demande'),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
