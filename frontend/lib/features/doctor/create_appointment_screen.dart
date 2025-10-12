import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:oshapp/shared/models/appointment_request.dart';
import 'package:intl/intl.dart';


import '../../shared/models/employee.dart';
import '../../shared/services/api_service.dart';
import '../../shared/utils/string_extensions.dart';

class CreateAppointmentScreen extends StatefulWidget {
  const CreateAppointmentScreen({super.key});

  @override
  CreateAppointmentScreenState createState() => CreateAppointmentScreenState();
}

class CreateAppointmentScreenState extends State<CreateAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late ApiService _apiService;
  late TextEditingController _employeeSearchController;

  bool _isSubmitting = false;
  Employee? _selectedEmployee;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedVisitType;
  String _visitMode = 'IN_PERSON';
  final _commentsController = TextEditingController();

  final List<String> _visitTypes = [
    'PERIODIC',
    'PRE_EMPLOYMENT',
    'RETURN_TO_WORK',
    'SPONTANEOUS_REQUEST',
    'OTHER'
  ];



  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final finalDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        // TODO: Refactor ApiService to accept a strongly-typed Appointment object
        final request = AppointmentRequest(
          motif: 'Rendez-vous médical pour ${_selectedEmployee!.fullName}',
          notes: _commentsController.text,
          requestedDateEmployee: finalDateTime.toIso8601String(),
          visitMode: _visitMode,
          // type: _selectedVisitType!,
          employeeId: int.parse(_selectedEmployee!.id),
        );

        await _apiService.createAppointment(request);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rendez-vous planifié avec succès!')),
          );
          Navigator.of(context).pop();
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la planification: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planifier un rendez-vous'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Sélectionner un employé et définir les détails du rendez-vous.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              _buildEmployeeDropdown(),
              const SizedBox(height: 16),
              _buildDateTimePicker(),
              const SizedBox(height: 16),
              _buildVisitTypeDropdown(),
              const SizedBox(height: 16),
              _buildVisitModeDropdown(),
              const SizedBox(height: 16),
              _buildCommentsField(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSubmitting ? const SizedBox.shrink() : const Icon(Icons.calendar_today),
                  label: Text(_isSubmitting ? 'Planification...' : 'Planifier le rendez-vous'),
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    return TypeAheadField<Employee?>(
      suggestionsCallback: (pattern) async {
        if (pattern.isEmpty) {
          return [];
        }
        return await _apiService.searchEmployees(pattern);
      },
      itemBuilder: (context, Employee? suggestion) {
        final employee = suggestion!;
        return ListTile(
          title: Text(employee.fullName),
          subtitle: Text('ID: ${employee.id}'),
        );
      },
      onSelected: (Employee? suggestion) {
        final employee = suggestion!;
        setState(() {
          _selectedEmployee = employee;
        });
        _employeeSearchController.text = employee.fullName;
      },
      builder: (context, controller, focusNode) {
        _employeeSearchController = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Rechercher un employé',
            hintText: 'Entrez le nom ou l''identifiant...',
            prefixIcon: Icon(Icons.search),
          ),
          validator: (value) {
            if (_selectedEmployee == null) {
              return 'Veuillez sélectionner un employé dans la liste.';
            }
            return null;
          },
        );
      },
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Aucun employé trouvé.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Date du rendez-vous',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            controller: TextEditingController(
              text: _selectedDate == null ? '' : DateFormat('dd/MM/yyyy').format(_selectedDate!),
            ),
            onTap: () => _selectDate(context),
            validator: (value) => _selectedDate == null ? 'Veuillez choisir une date' : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Heure',
              suffixIcon: Icon(Icons.access_time),
            ),
            readOnly: true,
            controller: TextEditingController(
              text: _selectedTime == null ? '' : _selectedTime!.format(context),
            ),
            onTap: () => _selectTime(context),
            validator: (value) => _selectedTime == null ? 'Veuillez choisir une heure' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitTypeDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Type de visite'),
      value: _selectedVisitType,
      items: _visitTypes.map((String type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(type.replaceAll('_', ' ').toLowerCase().capitalizeAll()),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedVisitType = newValue;
        });
      },
      validator: (value) => value == null ? 'Veuillez choisir un type de visite' : null,
    );
  }

  Widget _buildCommentsField() {
    return TextFormField(
      controller: _commentsController,
      decoration: const InputDecoration(
        labelText: 'Commentaires (optionnel)',
        alignLabelWithHint: true,
      ),
      maxLines: 3,
    );
  }

  Widget _buildVisitModeDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Modalité'),
      value: _visitMode,
      items: const [
        DropdownMenuItem(value: 'IN_PERSON', child: Text('Sur site')),
        DropdownMenuItem(value: 'REMOTE', child: Text('À distance')),
      ],
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _visitMode = newValue;
          });
        }
      },
      validator: (value) => value == null ? 'Veuillez choisir une modalité' : null,
    );
  }
}
