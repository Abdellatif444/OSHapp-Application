package com.oshapp.backend.dto;

import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.model.enums.Priority;
import com.oshapp.backend.model.enums.VisitMode;
import lombok.Data;

import java.time.LocalDateTime;

import java.util.List;

/**
 * 
 */
@Data
public class AppointmentResponseDTO {

    private Long id;

    private String motif; 
    private String notes;
    
    // Nouveau scénario: planification par service médical
    private String medicalInstructions; // Consignes/remarques du service médical
    private String medicalServicePhone; // Numéro de téléphone du service médical
    
    private VisitMode visitMode;
    private String requestedDateEmployee;
    private Long employeeId;
    
    private EmployeeSummaryDTO employee;
    private UserSummaryDTO nurse;
    private UserSummaryDTO doctor;
  
    private String reason;
    private LocalDateTime proposedDate;

    
    private AppointmentType type;
    private AppointmentStatus status;
    
    private LocalDateTime requestedDate;
    
    private LocalDateTime scheduledTime;
    private LocalDateTime appointmentDate; // Date unifiée pour l'affichage (peut provenir de scheduledTime, proposedDate ou requestedDate)
    private String createdByUsername;
    private List<AppointmentCommentDTO> comments;
    private String location;
    private boolean isObligatory;
    private Priority priority;
    private boolean flexibleSchedule;
    private String cancellationReason;
    private String rescheduleReason;
    private UserSummaryDTO createdBy;
    private UserSummaryDTO updatedBy;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private List<String> notificationChannels;
    private List<LocalDateTime> proposedDateSlots;
    
    // Formatted display fields for frontend
    private String statusDisplay;
    private String typeDisplay;
    private String typeShortDisplay;
    private String visitModeDisplay;
    private String statusUiDisplay;
    private String statusUiDisplayForNurse;
    private String statusUiCategory;
    
    // Action fields - tell frontend which actions are available for current user
    private boolean canConfirm;
    private boolean canCancel;
    private boolean canPropose;
    private boolean canComment;
}
