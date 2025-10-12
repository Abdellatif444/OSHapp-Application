package com.oshapp.backend.dto.enums;

// This enum MUST be an exact copy of the model enum for MapStruct to work automatically.
public enum AppointmentType {
    SPONTANEOUS,            // Visite spontanée demandée par le salarié
    PERIODIC,               // Visite périodique
    PRE_RECRUITMENT,        // Visite d'embauche
    RETURN_TO_WORK,         // Visite de reprise
    SURVEILLANCE_PARTICULIERE, // Surveillance particulière
    MEDICAL_CALL,           // À l'appel du médecin
    OTHER                   // Autre type de visite
}
