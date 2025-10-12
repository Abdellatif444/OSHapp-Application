package com.oshapp.backend.service.notifications.strategy.impl;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.NotificationType;
import com.oshapp.backend.service.EmailService;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.notifications.NotificationScenario;
import com.oshapp.backend.service.notifications.policy.NotificationVisibilityPolicy;
import com.oshapp.backend.service.notifications.strategy.AbstractNotificationStrategy;
import org.springframework.stereotype.Component;


/**
 * Strategy for appointment request notifications.
 * Handles: Employee creates request → Medical staff receives notification + email
 */
@Component
public class AppointmentRequestedStrategy extends AbstractNotificationStrategy {

    public AppointmentRequestedStrategy(NotificationService notificationService,
                                        EmailService emailService,
                                        NotificationVisibilityPolicy visibility) {
        super(notificationService, emailService, visibility);
    }

    @Override
    public boolean supports(NotificationScenario scenario) {
        return scenario == NotificationScenario.APPOINTMENT_REQUESTED;
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage) {
        String employeeName = getEmployeeName(appointment);
        String employeeEmail = getEmployeeEmail(appointment);
        
        // Build notification message
        String message = buildRequestMessage(user, appointment, employeeName, employeeEmail);
        
        // Send notification to employee who requested
        if (isEmployeeRecipient(user, appointment)) {
            String when = appointment.getRequestedDateEmployee() != null 
                ? appointment.getRequestedDateEmployee().format(DATE_TIME) : "";
            String employeeMessage = String.format("Votre demande de rendez-vous a été envoyée au service médical –Date souhaitée : %s– Statut : En attente.", when);
            
            notificationService.sendGeneralNotification(user,
                    "Demande envoyée",
                    (extraMessage != null && !extraMessage.isBlank()) ? employeeMessage + " – " + extraMessage : employeeMessage,
                    NotificationType.APPOINTMENT,
                    buildAppointmentActionLink(appointment, "view"),
                    "APPOINTMENT",
                    appointment.getId());
            return;
        }
        
        // Send notification
        String finalMessage = (extraMessage != null && !extraMessage.isBlank()) ? message + " – " + extraMessage : message;
        notificationService.sendGeneralNotification(user,
                "Nouvelle demande de rendez-vous",
                finalMessage,
                NotificationType.APPOINTMENT,
                buildAppointmentActionLink(appointment, "view"),
                "APPOINTMENT",
                appointment.getId());

        // Send email to employee, medical staff, RH and managers
        if (isEmployeeRecipient(user, appointment) || visibility.isMedicalStaff(user) || visibility.isRh(user) || visibility.isManagerForAppointment(user, appointment)) {
            sendRequestEmail(user, appointment, employeeName);
        }
    }

    private String buildRequestMessage(User user, Appointment appointment, String employeeName, String employeeEmail) {
        boolean isRh = visibility.isRh(user);
        boolean isManager = visibility.isManagerForAppointment(user, appointment);
        boolean isEmployee = isEmployeeRecipient(user, appointment);
        boolean isObligatory = false;
        try { isObligatory = appointment != null && appointment.isObligatory(); } catch (Exception ignored) {}
        String typeText = getAppointmentType(appointment);
        
        String when = (appointment != null && appointment.getRequestedDateEmployee() != null)
            ? appointment.getRequestedDateEmployee().format(DATE_TIME) : "";
        
        if (isEmployee) {
            if (isObligatory) {
                // Employé (obligatoire)
                return String.format("Une visite médicale obligatoire (%s) a été créée – Statut : En attente.", typeText);
            }
            // Employé (standard)
            return String.format("Votre demande de rendez-vous a été envoyée au service médical –Date souhaitée : %s– Statut : En attente.", when);
        } else if (isRh || isManager) {
            if (isObligatory) {
                // RH/Manager (obligatoire)
                return String.format("Une visite médicale obligatoire (%s) a été créée pour l'employé %s – %s – Statut : En attente.",
                        typeText, employeeName, employeeEmail);
            }
            // RH/Manager (standard)
            return String.format("Le service médical a reçu une demande de rendez-vous pour l'employé %s – %s Date souhaitée : %s– Statut : En attente.", 
                employeeName, employeeEmail, when);
        } else {
            if (isObligatory) {
                // Service médical (obligatoire)
                return String.format("RH a initié une visite médicale obligatoire (%s) pour %s – %s – Statut : En attente.",
                        typeText, employeeName, employeeEmail);
            }
            // Service médical (standard)
            String motif = getMotifText(appointment);
            String notes = getNotesText(appointment);
            return String.format("Nouvelle demande de rendez-vous médical – %s – %s – Statut : En attente.Date souhaitée : %s  motif:%s notes: %s", 
                employeeName, employeeEmail, when, motif, notes);
        }
    }
    
    private String getMotifText(Appointment appointment) {
        String motif = appointment.getMotif();
        if (motif == null || motif.isBlank() || "N/A".equalsIgnoreCase(motif.trim())) {
            motif = appointment.getReason();
        }
        return (motif != null && !motif.isBlank() && !"N/A".equalsIgnoreCase(motif.trim())) 
            ? motif.trim() : "Néant";
    }
    
    private String getNotesText(Appointment appointment) {
        String notes = appointment.getNotes();
        return (notes != null && !notes.isBlank() && !"N/A".equalsIgnoreCase(notes.trim())) 
            ? notes.trim() : "Néant";
    }

    private void sendRequestEmail(User user, Appointment appointment, String employeeName) {
        String employeeEmail = getEmployeeEmail(appointment);
        String appointmentType = getAppointmentType(appointment);
        boolean isObligatory = false;
        try { isObligatory = appointment != null && appointment.isObligatory(); } catch (Exception ignored) {}
        String subject = isObligatory
                ? String.format("Visite médicale obligatoire (%s) – %s (%s)", appointmentType, employeeName, employeeEmail)
                : String.format("Nouvelle demande de rendez-vous (%s) – %s (%s)", appointmentType, employeeName, employeeEmail);
        
        boolean isRh = visibility.isRh(user);
        boolean isManager = visibility.isManagerForAppointment(user, appointment);
        
        String templateName = (isRh || isManager) 
            ? resolveTemplate("appointment-requested-rh-template") 
            : resolveTemplate("appointment-requested-template");
        
        if (isRh || isManager) {
            // RH gets email without CTA (no actions available)
            emailService.sendAppointmentNotification(
                    java.util.List.of(user), appointment, subject, templateName
            );
        } else {
            // Medical staff gets email with primary CTA and optional secondary CTA (Voir le certificat) for Reprise
            String secondaryUrl = null;
            String secondaryLabel = null;
            try {
                if (appointment != null && appointment.getType() == com.oshapp.backend.model.enums.AppointmentType.RETURN_TO_WORK) {
                    secondaryUrl = buildAppointmentActionLink(appointment, "certificate");
                    secondaryLabel = "Voir le certificat";
                }
            } catch (Exception ignored) {}

            // Choose primary CTA label: for HR-initiated obligatory/Embauche, prefer 'Proposer un créneau'
            String primaryLabel = "Confirmer ou proposer un créneau";
            try {
                boolean isEmbauche = appointment != null && appointment.getType() == com.oshapp.backend.model.enums.AppointmentType.PRE_RECRUITMENT;
                if (isObligatory || isEmbauche) {
                    primaryLabel = "Proposer un créneau";
                }
            } catch (Exception ignored) {}

            emailService.sendAppointmentNotification(
                    java.util.List.of(user), 
                    appointment, 
                    subject, 
                    templateName,
                    buildAppointmentActionLink(appointment, "view"), 
                    primaryLabel,
                    secondaryUrl,
                    secondaryLabel
            );
        }
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
