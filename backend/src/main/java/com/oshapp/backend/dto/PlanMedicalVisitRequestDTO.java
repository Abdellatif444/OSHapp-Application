package com.oshapp.backend.dto;

import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.model.enums.VisitMode;
import lombok.Data;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;

@Data
public class PlanMedicalVisitRequestDTO {

    @NotNull(message = "Employee ID is required")
    private Long employeeId;

    @NotNull(message = "Appointment type is required")
    private AppointmentType type;

    @NotNull(message = "Scheduled date and time is required")
    private LocalDateTime scheduledDateTime;

    @NotNull(message = "Visit mode is required")
    private VisitMode visitMode;

    private String medicalInstructions;
    // medicalServicePhone sera automatiquement récupéré depuis l'utilisateur connecté // Numéro du service médical
}
