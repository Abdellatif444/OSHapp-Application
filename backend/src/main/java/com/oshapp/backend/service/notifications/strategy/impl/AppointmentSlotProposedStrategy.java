package com.oshapp.backend.service.notifications.strategy.impl;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.NotificationType;
import com.oshapp.backend.service.EmailService;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.notifications.NotificationScenario;
import com.oshapp.backend.service.notifications.NotificationActor;
import com.oshapp.backend.service.notifications.policy.NotificationVisibilityPolicy;
import com.oshapp.backend.service.notifications.strategy.AbstractNotificationStrategy;
import com.oshapp.backend.service.notifications.strategy.ActorAwareNotificationStrategy;
import org.springframework.stereotype.Component;


/**
 * Strategy for slot proposal notifications.
 * Handles: Medical staff proposes new slot → Employee receives notification + email
 */
@Component
public class AppointmentSlotProposedStrategy extends AbstractNotificationStrategy implements ActorAwareNotificationStrategy {

    public AppointmentSlotProposedStrategy(NotificationService notificationService,
                                           EmailService emailService,
                                           NotificationVisibilityPolicy visibility) {
        super(notificationService, emailService, visibility);
    }

    @Override
    public boolean supports(NotificationScenario scenario) {
        return scenario == NotificationScenario.APPOINTMENT_SLOT_PROPOSED;
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage) {
        // Fallback to MEDICAL_STAFF actor when not provided
        notify(user, appointment, extraMessage, NotificationActor.MEDICAL_STAFF);
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage, NotificationActor actor) {
        String employeeName = getEmployeeName(appointment);
        String employeeEmail = getEmployeeEmail(appointment);
        String proposed = appointment.getProposedDate() != null 
            ? appointment.getProposedDate().format(DATE_TIME) : "";
        String modeSuffix = getVisitModeText(appointment);
        boolean isObligatory = false;
        try { isObligatory = appointment != null && appointment.isObligatory(); } catch (Exception ignored) {}
        String typeText = getAppointmentType(appointment);

        // Get justification from latest comment
        String justification = getLatestJustification(appointment);

        String message = buildProposalMessage(user, appointment, employeeName, employeeEmail, proposed, modeSuffix, justification, isObligatory, typeText);

        // Send notification
        notificationService.sendGeneralNotification(user,
                "Créneau proposé",
                extraMessage != null ? extraMessage : message,
                NotificationType.APPOINTMENT,
                buildAppointmentActionLink(appointment, "confirm"),
                "APPOINTMENT",
                appointment.getId());

        // Send email
        sendProposalEmail(user, appointment, employeeName, employeeEmail, justification, isObligatory, typeText);
    }

    private String buildProposalMessage(User user, Appointment appointment, String employeeName, String employeeEmail, String proposed, String modeSuffix, String justification, boolean isObligatory, String typeText) {
        boolean isRh = visibility.isRh(user);
        boolean isManager = visibility.isManagerForAppointment(user, appointment);
        boolean isEmployee = isEmployeeRecipient(user, appointment);
        boolean isMedicalStaff = visibility.isMedicalStaff(user);
        boolean isActorMedical = false;
        try {
            if (isMedicalStaff && user.getId() != null) {
                if (appointment.getUpdatedBy() != null && appointment.getUpdatedBy().getId() != null) {
                    isActorMedical = user.getId().equals(appointment.getUpdatedBy().getId());
                } else if (appointment.getCreatedBy() != null && appointment.getCreatedBy().getId() != null) {
                    isActorMedical = user.getId().equals(appointment.getCreatedBy().getId());
                }
            }
        } catch (Exception ignored) {}
        
        if (isEmployee) {
            // Employé
            if (isObligatory) {
                return String.format("Le service médical vous propose un nouveau créneau (Obligatoire – %s) – %s%s – Statut : Créneau proposé.", typeText, proposed, modeSuffix);
            }
            return String.format("Le service médical vous propose un nouveau créneau – %s%s – Statut : Créneau proposé.", proposed, modeSuffix);
        } else if (isRh || isManager) {
            // RH/Manager
            if (isObligatory) {
                return String.format("Le service médical a proposé un nouveau créneau (Obligatoire – %s) pour l'employé %s – %s – Nouvelle proposition : %s – Statut : Créneau proposé.", 
                    typeText, employeeName, employeeEmail, proposed);
            }
            return String.format("Le service médical a proposé un nouveau créneau pour l'employé %s – %s –Nouvelle proposition : %s –– Statut : Créneau proposé.", 
                employeeName, employeeEmail, proposed);
        } else if (isMedicalStaff) {
            // Service médical actor vs other medical staff
            if (isActorMedical) {
                if (isObligatory) {
                    return String.format("Vous avez proposé un nouveau créneau (Obligatoire – %s – Initiée par RH) pour %s – %s – Nouvelle proposition : %s – Statut : En attente de réponse.", 
                        typeText, employeeName, employeeEmail, proposed);
                }
                return String.format("Vous avez proposé un nouveau créneau pour %s – %s ––Nouvelle proposition : %s – Statut : En attente de réponse.", 
                    employeeName, employeeEmail, proposed);
            } else {
                if (isObligatory) {
                    return String.format("Le service médical a proposé un nouveau créneau (Obligatoire – %s – Initiée par RH) pour l'employé %s – %s – Nouvelle proposition : %s – Statut : Créneau proposé.", 
                        typeText, employeeName, employeeEmail, proposed);
                }
                return String.format("Le service médical a proposé un nouveau créneau pour l'employé %s – %s –Nouvelle proposition : %s –– Statut : Créneau proposé.", 
                    employeeName, employeeEmail, proposed);
            }
        } else {
            // Fallback
            if (isObligatory) {
                return String.format("Le service médical a proposé un nouveau créneau (Obligatoire – %s) pour l'employé %s – %s – Nouvelle proposition : %s – Statut : Créneau proposé.", 
                    typeText, employeeName, employeeEmail, proposed);
            }
            return String.format("Le service médical a proposé un nouveau créneau pour l'employé %s – %s –Nouvelle proposition : %s –– Statut : Créneau proposé.", 
                employeeName, employeeEmail, proposed);
        }
    }

    private void sendProposalEmail(User user, Appointment appointment, String employeeName, String employeeEmail, String justification, boolean isObligatory, String typeText) {
        boolean isRh = visibility.isRh(user);
        boolean isManager = visibility.isManagerForAppointment(user, appointment);
        boolean isMedicalStaff = visibility.isMedicalStaff(user);
        boolean isEmployee = isEmployeeRecipient(user, appointment);
        
        // According to scenario: Medical staff do NOT receive emails when proposing slots
        // Only Employee and RH/Managers receive emails
        if (isMedicalStaff && !isEmployee) {
            return; // No email sent to medical staff (unless they are also the employee)
        }
        
        String appointmentType = getAppointmentType(appointment);
        String subject = isObligatory
                ? String.format("Nouveau créneau proposé – Visite médicale obligatoire (%s) – %s (%s)", appointmentType, employeeName, employeeEmail)
                : String.format("Nouveau créneau proposé (%s) – %s (%s)", appointmentType, employeeName, employeeEmail);
        
        String templateName = (isRh || isManager) 
            ? resolveTemplate("appointment-proposal-rh-template")
            : resolveTemplate("appointment-proposal-template");

        if (isRh || isManager) {
            // RH/managers get email without CTA and without motif/notes
            emailService.sendAppointmentNotification(
                    java.util.List.of(user), appointment, subject, templateName
            );
        } else {
            // Employee gets email with CTA buttons
            emailService.sendAppointmentNotification(
                    java.util.List.of(user), appointment, subject, templateName,
                    buildAppointmentActionLink(appointment, "confirm"), "Confirmer le créneau",
                    buildAppointmentActionLink(appointment, "cancel"), "Refuser la proposition"
            );
        }
    }

    private String getVisitModeText(Appointment appointment) {
        if (appointment.getVisitMode() != null) {
            String modeStr = appointment.getVisitMode() == com.oshapp.backend.model.enums.VisitMode.REMOTE
                    ? "À distance" : "Présentiel";
            return " – Mode : " + modeStr;
        }
        return "";
    }

    private String getLatestJustification(Appointment appointment) {
        try {
            if (appointment.getComments() != null && !appointment.getComments().isEmpty()) {
                com.oshapp.backend.model.AppointmentComment last = appointment.getComments()
                    .get(appointment.getComments().size() - 1);
                if (last != null && last.getComment() != null && !last.getComment().isBlank()) {
                    return last.getComment().trim();
                }
            }
        } catch (Exception e) {
            // Ignore and return null
        }
        return null;
    }

    private String getEmployeeName(Appointment appointment) {
        if (appointment.getEmployee() != null && 
            appointment.getEmployee().getFirstName() != null && !appointment.getEmployee().getFirstName().isBlank() &&
            appointment.getEmployee().getLastName() != null && !appointment.getEmployee().getLastName().isBlank()) {
            return appointment.getEmployee().getFirstName() + " " + appointment.getEmployee().getLastName();
        }
        return appointment.getEmployee() != null && appointment.getEmployee().getUser() != null 
            ? appointment.getEmployee().getUser().getEmail() : "Collaborateur";
    }

    private String getEmployeeEmail(Appointment appointment) {
        return appointment.getEmployee() != null && appointment.getEmployee().getUser() != null
            ? appointment.getEmployee().getUser().getEmail() : "";
    }

}
