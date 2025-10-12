import 'package:flutter/material.dart';

class MedicalFitness {
  final int id;
  final String decision; // e.g., 'APTE', 'INAPTE_TEMPORAIRE', 'INAPTE_DEFINITIF'
  final String? restrictions;
  final DateTime examinationDate;
  final DateTime? nextVisitDate;
  final String doctorName;
  final String? documentUrl;

  MedicalFitness({
    required this.id,
    required this.decision,
    this.restrictions,
    required this.examinationDate,
    this.nextVisitDate,
    required this.doctorName,
    this.documentUrl,
  });

  factory MedicalFitness.fromJson(Map<String, dynamic> json) {
    return MedicalFitness(
      id: json['id'],
      decision: json['decision'],
      restrictions: json['restrictions'],
      examinationDate: DateTime.parse(json['examinationDate']),
      nextVisitDate: json['nextVisitDate'] != null ? DateTime.parse(json['nextVisitDate']) : null,
      doctorName: json['doctorName'],
      documentUrl: json['documentUrl'],
    );
  }

  String get decisionDisplay {
    switch (decision) {
      case 'APTE':
        return 'Apte';
      case 'INAPTE_TEMPORAIRE':
        return 'Inapte Temporaire';
      case 'INAPTE_DEFINITIF':
        return 'Inapte Définitif';
      case 'APTE_AVEC_RESTRICTIONS':
        return 'Apte avec restrictions';
      default:
        return 'Inconnu';
    }
  }

  Color get decisionColor {
    switch (decision) {
      case 'APTE':
      case 'APTE_AVEC_RESTRICTIONS':
        return Colors.green;
      case 'INAPTE_TEMPORAIRE':
        return Colors.orange;
      case 'INAPTE_DEFINITIF':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
