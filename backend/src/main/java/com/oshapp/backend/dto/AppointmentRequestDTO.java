package com.oshapp.backend.dto;

import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.model.enums.Priority;
import com.oshapp.backend.model.enums.VisitMode;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Data Transfer Object for creating or updating an appointment.
 * It consolidates fields for different appointment creation scenarios.
 */
@Data
public class AppointmentRequestDTO {

    // For single appointment requests (e.g., by an employee for themselves)
    private Long employeeId;

    // For bulk appointment creation (e.g., by HR for multiple employees)
    private List<Long> employeeIds;

    private Long nurseId;

    private Long doctorId;

    @NotNull(message = "Appointment type is required")
    private AppointmentType type;

    // Employee can suggest a date for spontaneous visits
    private LocalDateTime requestedDateEmployee;
    private String motif;
    private String notes; 

    // HR/Doctor can propose multiple slots for obligatory visits
    private List<LocalDateTime> proposedDateSlots;

    private String reason;
   // Renamed from comments to match frontend

    private String location;

    private VisitMode visitMode; // IN_PERSON or REMOTE

    private boolean isUrgent = false; // Added from frontend

    private List<String> preferredTimeSlots; // Added from frontend

    private boolean isObligatory = false;

    private Priority priority;

    private boolean flexibleSchedule = false;

    private List<String> notificationChannels;

    // Fields for updates by other actors (manager, doctor)
    private String managerComments;
    private String rejectionReason;
    private LocalDateTime scheduledTime;
}