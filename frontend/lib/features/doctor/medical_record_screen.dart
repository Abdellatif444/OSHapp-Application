import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:provider/provider.dart';

class MedicalRecordScreen extends StatefulWidget {
  final Employee employee;
  const MedicalRecordScreen({super.key, required this.employee});

  @override
  State<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
  List<Appointment> _medicalHistory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMedicalHistory();
  }

  Future<void> _fetchMedicalHistory() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final history = await apiService.getAppointmentsForEmployee(int.parse(widget.employee.id));
      if (mounted) {
        setState(() {
          _medicalHistory = history;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dossier médical - ${widget.employee.fullName}'),
        backgroundColor: const Color(0xFFD32F2F),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _medicalHistory.isEmpty
                  ? const Center(child: Text('Aucun historique médical trouvé.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildEmployeeInfoCard(),
                        const SizedBox(height: 24),
                        Text('Historique des visites', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black87)),
                        const SizedBox(height: 8),
                        ..._medicalHistory.map((visit) => _buildVisitCard(visit)),
                      ],
                    ),
    );
  }

  Widget _buildEmployeeInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.employee.fullName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.work_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(widget.employee.jobTitle ?? 'N/A', style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.business_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(widget.employee.department ?? 'N/A', style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(Appointment visit) {
    final visitDate = visit.appointmentDate;
    final formattedDate = visitDate != null ? DateFormat('dd/MM/yyyy à HH:mm').format(visitDate) : 'Date non spécifiée';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(Icons.medical_services_outlined, color: visit.statusColor),
        title: Text(visit.typeDisplay ?? 'Visite médicale', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Le $formattedDate'),
        trailing: Text(
          visit.statusUiDisplay ?? 'En cours',
          style: TextStyle(color: visit.statusColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }


}