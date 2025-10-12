package com.oshapp.backend.mapper;

import com.oshapp.backend.dto.*;
import com.oshapp.backend.model.Appointment;
import org.mapstruct.Mapping;
import java.util.List;
import org.mapstruct.*;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE, uses = {UserMapper.class, EmployeeMapper.class, AppointmentCommentMapper.class})
public interface AppointmentMapper {


    @Mapping(source = "employee.id", target = "employeeId")
    @Mapping(source = "motif", target = "motif")
    @Mapping(source = "notes", target = "notes")
    @Mapping(source = "requestedDateEmployee", target = "requestedDateEmployee")
    @Mapping(source = "cancellationReason", target = "cancellationReason")
    @Mapping(source = "visitMode", target = "visitMode")
    // appointmentDate sera géré dynamiquement dans @AfterMapping
    @AfterMapping
    default void populateDisplayFields(@MappingTarget AppointmentResponseDTO dto, Appointment appointment) {
        // Populate formatted display fields
        dto.setStatusDisplay(getStatusDisplay(appointment.getStatus()));
        dto.setTypeDisplay(getTypeDisplay(appointment.getType()));
        dto.setTypeShortDisplay(getTypeShortDisplay(appointment.getType()));
        dto.setVisitModeDisplay(getVisitModeDisplay(appointment.getVisitMode()));
        dto.setStatusUiDisplay(getStatusUiDisplay(appointment.getStatus()));
        dto.setStatusUiDisplayForNurse(getStatusUiDisplayForNurse(appointment.getStatus()));
        dto.setStatusUiCategory(getStatusUiCategory(appointment.getStatus()));
        
        // Mapping intelligent de appointmentDate selon le contexte
        if (appointment.getScheduledTime() != null) {
            // Pour les visites médicales planifiées et les rendez-vous confirmés
            dto.setAppointmentDate(appointment.getScheduledTime());
        } else if (appointment.getProposedDate() != null) {
            // Pour les créneaux proposés par le médecin
            dto.setAppointmentDate(appointment.getProposedDate());
        } else if (appointment.getRequestedDateEmployee() != null) {
            // Pour les demandes d'employés en attente
            dto.setAppointmentDate(appointment.getRequestedDateEmployee());
        }
        
        // Confidentialité: medicalInstructions et medicalServicePhone toujours mappés
        // La logique de visibilité sera gérée côté service selon le rôle utilisateur
        dto.setMedicalInstructions(appointment.getMedicalInstructions());
        dto.setMedicalServicePhone(appointment.getMedicalServicePhone());
        
        // Les actions seront définies côté service selon le rôle et le statut
        dto.setCanConfirm(false);
        dto.setCanCancel(false);
        dto.setCanPropose(false);
        dto.setCanComment(false);
    }
    
    AppointmentResponseDTO toDto(Appointment appointment);

    default List<AppointmentResponseDTO> toDto(List<Appointment> appointments) {
        if (appointments == null) {
            return java.util.Collections.emptyList();
        }
        return appointments.stream()
                .filter(appointment -> appointment.getEmployee() != null)
                .map(this::toDto)
                .collect(java.util.stream.Collectors.toList());
    }



    @Mapping(target = "id", ignore = true)
    @Mapping(target = "employee", ignore = true) // Should be set manually in service from employeeId
    @Mapping(target = "doctor", ignore = true)   // Should be set manually in service from doctorId
    @Mapping(target = "nurse", ignore = true)    // Should be set manually in service from nurseId
    @Mapping(target = "status", ignore = true)   // Status is managed by the workflow, not by request
    @Mapping(target = "createdBy", ignore = true)// Should be set from security context
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    Appointment toEntity(AppointmentRequestDTO appointmentRequestDTO);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "employee", ignore = true)
    @Mapping(target = "doctor", ignore = true)
    @Mapping(target = "nurse", ignore = true)
    @Mapping(target = "status", ignore = true)
    @Mapping(target = "createdBy", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    void updateEntityFromDto(AppointmentRequestDTO dto, @MappingTarget Appointment entity);
    
    // Helper methods for formatting display fields
    default String getStatusDisplay(com.oshapp.backend.model.enums.AppointmentStatus status) {
        if (status == null) return "Inconnu";
        switch (status) {
            case REQUESTED_EMPLOYEE:
                return "En attente de la réponse de médecin ou infirmier";
            case PROPOSED_MEDECIN:
                return "Proposé par médecin ou infirmier";
            case PLANNED_BY_MEDICAL_STAFF:
                return "Planifié par le service médical";
            case CONFIRMED:
                return "Confirmé";
            case CANCELLED:
                return "Annulé";
            case COMPLETED:
                return "Terminé";
            case OBLIGATORY:
                return "Planifié (Obligatoire)";
            default:
                return status.name();
        }
    }
    
    default String getTypeDisplay(com.oshapp.backend.model.enums.AppointmentType type) {
        if (type == null) return "Inconnu";
        switch (type) {
            case RETURN_TO_WORK:
                return "Visite de Reprise";
            case PRE_RECRUITMENT:
                return "Visite d'Embauche";
            case PERIODIC:
                return "Visite Périodique";
            case SURVEILLANCE_PARTICULIERE:
                return "Surveillance Particulière";
            case MEDICAL_CALL:
                return "À l'appel du médecin";
            case SPONTANEOUS:
                return "Visite Spontanée";
            case OTHER:
                return "Visite Obligatoire";
            default:
                return type.name();
        }
    }
    
    default String getTypeShortDisplay(com.oshapp.backend.model.enums.AppointmentType type) {
        if (type == null) return "Inconnu";
        switch (type) {
            case RETURN_TO_WORK:
                return "Reprise";
            case PRE_RECRUITMENT:
                return "Embauche";
            case PERIODIC:
                return "Périodique";
            case SURVEILLANCE_PARTICULIERE:
                return "Surveillance";
            case MEDICAL_CALL:
                return "Appel médecin";
            case SPONTANEOUS:
                return "Spontanée";
            case OTHER:
                return "Obligatoire";
            default:
                return getTypeDisplay(type);
        }
    }
    
    default String getVisitModeDisplay(com.oshapp.backend.model.enums.VisitMode visitMode) {
        if (visitMode == null) return "Non spécifié";
        switch (visitMode) {
            case IN_PERSON:
                return "Présentiel";
            case REMOTE:
                return "À distance";
            default:
                return visitMode.name();
        }
    }
    
    default String getStatusUiDisplay(com.oshapp.backend.model.enums.AppointmentStatus status) {
        String category = getStatusUiCategory(status);
        switch (category) {
            case "REQUESTED":
                return "En attente";
            case "PROPOSED":
                return "Créneau proposé";
            case "PLANNED":
                return "Planifié par le service médical";
            case "CONFIRMED":
                return "Confirmé";
            case "CANCELLED":
                return "Annulé";
            case "COMPLETED":
                return "Terminé";
            default:
                return getStatusDisplay(status);
        }
    }
    
    default String getStatusUiDisplayForNurse(com.oshapp.backend.model.enums.AppointmentStatus status) {
        String category = getStatusUiCategory(status);
        switch (category) {
            case "REQUESTED":
                return "En attente";
            case "PROPOSED":
                return "En attente (réponse employé)";
            case "PLANNED":
                return "En attente (réponse employé)";
            case "CONFIRMED":
                return "Confirmé";
            case "CANCELLED":
                return "Annulé";
            case "COMPLETED":
                return "Terminé";
            default:
                return getStatusDisplay(status);
        }
    }
    
    default String getStatusUiCategory(com.oshapp.backend.model.enums.AppointmentStatus status) {
        if (status == null) return "UNKNOWN";
        switch (status) {
            case REQUESTED_EMPLOYEE:
                return "REQUESTED";
            case PROPOSED_MEDECIN:
                return "PROPOSED";
            case PLANNED_BY_MEDICAL_STAFF:
                return "PLANNED";
            case CONFIRMED:
                return "CONFIRMED";
            case OBLIGATORY:
                // HR-initiated obligatory requests should appear as 'En attente'
                return "REQUESTED";
            case CANCELLED:
                return "CANCELLED";
            case COMPLETED:
                return "COMPLETED";
            default:
                return status.name();
        }
    }
}

