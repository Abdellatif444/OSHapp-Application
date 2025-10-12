package com.oshapp.backend.model.enums;

public enum AppointmentStatus {
    REQUESTED_EMPLOYEE,//employee demander un rendez-vous
    PROPOSED_MEDECIN,//medecin propose premiere fois un rendez-vous pour requested employee
    PLANNED_BY_MEDICAL_STAFF,//service médical planifie une visite (nouveau scénario)
    CONFIRMED,//medecin ou employee confirme le rendez-vous
    COMPLETED,//rendez-vous termine
    CANCELLED,//rendez-vous annule par employee parce que il ne veut plus le rendez-vous ou il n'accepte pas la date proposee par le medecin
    OBLIGATORY;//rendez-vous obligatoire
}
