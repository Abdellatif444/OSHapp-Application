package com.oshapp.backend.dto.enums;

public enum AppointmentStatus {
    REQUESTED("Demandé"),
    PROPOSED("Proposé"),
    CONFIRMED("Confirmé"),
    REPORTED("Reporté"),
    CANCELLED("Annulé"),
    COMPLETED("Terminé"),
    OBLIGATORY("Obligatoire");

    private final String displayName;

    AppointmentStatus(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}
