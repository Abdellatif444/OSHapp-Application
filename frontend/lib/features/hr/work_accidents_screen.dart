import 'package:flutter/material.dart';
import 'package:oshapp/shared/models/work_accident.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WorkAccidentsScreen extends StatefulWidget {
  const WorkAccidentsScreen({super.key});

  @override
  WorkAccidentsScreenState createState() => WorkAccidentsScreenState();
}

class WorkAccidentsScreenState extends State<WorkAccidentsScreen> {
  List<WorkAccident> _accidents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccidents();
  }

  Future<void> _loadAccidents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final accidents = await apiService.getWorkAccidents();
      if (mounted) {
        setState(() {
          _accidents = accidents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load work accidents: $e')),
        );
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
        title: const Text('Accidents de Travail'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAccidents,
              child: _accidents.isEmpty
                  ? const Center(
                      child: Text('Aucun accident de travail trouvé.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _accidents.length,
                      itemBuilder: (context, index) {
                        final accident = _accidents[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary, // Generic color - backend should provide status color
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  ),
                  title: Text(accident.employeeName, style: theme.textTheme.titleMedium),
                  subtitle: Text('Date: ${DateFormat('dd/MM/yyyy').format(accident.accidentDate)}\n${accident.description}'),
                  trailing: Text(accident.status, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)), // Generic color - backend should provide
                  isThreeLine: true,
                ),
              );
            },
          ),
      ),
    );
  }

  // Backend should provide status display properties - removed local logic
}
