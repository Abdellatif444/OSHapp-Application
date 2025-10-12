import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:oshapp/shared/models/medical_fitness.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/logger_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  DocumentsScreenState createState() => DocumentsScreenState();
}

class DocumentsScreenState extends State<DocumentsScreen> {
  Future<List<MedicalFitness>>? _fitnessRecordsFuture;

  @override
  void initState() {
    super.initState();
    // Defer loading to didChangeDependencies to safely use Provider
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure this runs only once, as didChangeDependencies can be called multiple times.
    if (_fitnessRecordsFuture == null) {
      _loadFitnessRecords();
    }
  }

  void _loadFitnessRecords() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _fitnessRecordsFuture = _fetchFitnessRecords(apiService);
    });
  }

  Future<List<MedicalFitness>> _fetchFitnessRecords(ApiService apiService) async {
    try {
      // First, get the current employee's profile to obtain their ID.
      final employee = await apiService.getCurrentEmployeeProfile();
      // Then, use the employee's ID to fetch their medical fitness records.
      final List<dynamic> recordsJson = await apiService.getMedicalFitnessHistory(int.parse(employee.id));
      return recordsJson.map((json) => MedicalFitness.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // Rethrow the error to be handled by the FutureBuilder.
      LoggerService.error('Error fetching fitness records: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Documents'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadFitnessRecords();
        },
        child: FutureBuilder<List<MedicalFitness>>(
          future: _fitnessRecordsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }
            final records = snapshot.data ?? [];
            if (records.isEmpty) {
              return const Center(child: Text('Aucun document trouvé.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: records.length,
              itemBuilder: (context, index) {
                return _buildFitnessCard(context, records[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFitnessCard(BuildContext context, MedicalFitness record) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              label: Text(record.decisionDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: record.decisionColor,
              avatar: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(theme, Icons.calendar_today, 'Date d\'examen', DateFormat('dd/MM/yyyy').format(record.examinationDate)),
            if (record.nextVisitDate != null)
              _buildInfoRow(theme, Icons.next_plan_outlined, 'Prochaine visite', DateFormat('dd/MM/yyyy').format(record.nextVisitDate!)),
            _buildInfoRow(theme, Icons.medical_services_outlined, 'Médecin', record.doctorName),
            if (record.restrictions != null && record.restrictions!.isNotEmpty)
              _buildInfoRow(theme, Icons.warning_amber_rounded, 'Restrictions', record.restrictions!),
            if (record.documentUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Télécharger la fiche'),
                  onPressed: () {
                    // TODO: Implement document download
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
