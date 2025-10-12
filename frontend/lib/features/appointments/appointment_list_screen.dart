import 'package:flutter/material.dart';
import 'package:oshapp/shared/widgets/appointment_card.dart';
import 'package:oshapp/shared/widgets/error_display.dart';
import 'package:provider/provider.dart';

import '../../shared/models/appointment.dart';
import '../../shared/services/api_service.dart';

class AppointmentListScreen extends StatefulWidget {
  final String title;
  final List<Appointment>? appointments;
  final Future<List<Appointment>>? appointmentsFuture;

  const AppointmentListScreen({
    super.key,
    required this.title,
    this.appointments,
    this.appointmentsFuture,
  }) : assert(appointments != null || appointmentsFuture != null,
          'Vous devez fournir soit une liste de rendez-vous, soit un future.');

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  late Future<List<Appointment>> _future;

  @override
  void initState() {
    super.initState();
    if (widget.appointmentsFuture != null) {
      _future = widget.appointmentsFuture!;
    } else if (widget.title == 'Historique') {
      // Cas spécifique pour l'historique, qui a sa propre logique de fetch
      _future = Provider.of<ApiService>(context, listen: false).getAppointmentHistory();
    } else {
      _future = Future.value(widget.appointments ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Appointment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: ErrorDisplay(
                message: 'Erreur de chargement: ${snapshot.error}',
                onRetry: () {
                  setState(() {
                    // Relance le future approprié
                    if (widget.appointmentsFuture != null) {
                      _future = widget.appointmentsFuture!;
                    } else if (widget.title == 'Historique') {
                      _future = Provider.of<ApiService>(context, listen: false).getAppointmentHistory();
                    }
                  });
                },
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Aucun rendez-vous à afficher.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final appointments = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              return AppointmentCard(
                appointment: appointments[index],
                // Les actions ne sont pas nécessaires sur cet écran de simple consultation
              );
            },
          );
        },
      ),
    );
  }
}
