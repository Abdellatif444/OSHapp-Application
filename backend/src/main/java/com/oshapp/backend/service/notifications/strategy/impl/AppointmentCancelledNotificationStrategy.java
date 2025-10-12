package com.oshapp.backend.service.notifications.strategy.impl;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.NotificationType;
import com.oshapp.backend.model.enums.VisitMode;
import com.oshapp.backend.service.EmailService;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.notifications.NotificationScenario;
import com.oshapp.backend.service.notifications.policy.NotificationVisibilityPolicy;
import com.oshapp.backend.service.notifications.strategy.AbstractNotificationStrategy;
import org.springframework.stereotype.Component;


@Component
public class AppointmentCancelledNotificationStrategy extends AbstractNotificationStrategy {

    public AppointmentCancelledNotificationStrategy(NotificationService notificationService,
                                                    EmailService emailService,
                                                    NotificationVisibilityPolicy visibility) {
        super(notificationService, emailService, visibility);
    }

    @Override
    public boolean supports(NotificationScenario scenario) {
        return scenario == NotificationScenario.APPOINTMENT_CANCELLED;
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage) {
        // Build content strictly from backend logic; ignore extraMessage to keep consistent messaging
        String employeeName = (appointment.getEmployee() != null && appointment.getEmployee().getFirstName() != null && !appointment.getEmployee().getFirstName().isBlank()
                && appointment.getEmployee().getLastName() != null && !appointment.getEmployee().getLastName().isBlank())
                ? appointment.getEmployee().getFirstName() + " " + appointment.getEmployee().getLastName()
                : (appointment.getEmployee() != null && appointment.getEmployee().getUser() != null ? appointment.getEmployee().getUser().getEmail() : "Collaborateur");


        boolean isEmployeeRecipient = isEmployeeRecipient(user, appointment);
        boolean rh = visibility.isRh(user);
        boolean manager = visibility.isManagerForAppointment(user, appointment);

        String employeeEmail = appointment.getEmployee() != null && appointment.getEmployee().getUser() != null
                ? appointment.getEmployee().getUser().getEmail() : "";
        
        String when = appointment.getScheduledTime() != null
                ? appointment.getScheduledTime().format(DATE_TIME)
                : (appointment.getProposedDate() != null
                    ? appointment.getProposedDate().format(DATE_TIME)
                    : (appointment.getRequestedDateEmployee() != null
                        ? appointment.getRequestedDateEmployee().format(DATE_TIME)
                        : ""));
        String modePart = "";
        if (appointment.getVisitMode() != null) {
            String modeStr = appointment.getVisitMode() == VisitMode.REMOTE ? "À distance" : "En présentiel";
            modePart = " – Mode : " + modeStr;
        }
        
        boolean isEmployeeInitiated = isEmployeeInitiatedVisit(appointment);
        
        String defaultMsg;
        if (isEmployeeRecipient) {
            if (isEmployeeInitiated) {
                // Employé annule sa propre demande spontanée
                defaultMsg = String.format("Vous avez annulé votre demande de rendez-vous – Date demandée : %s – Mode : %s – Statut : Annulé.", 
                    when, getModeText(appointment));
            } else {
                // Employé annule un RDV proposé par le service médical
                defaultMsg = String.format("Vous avez annulé le rendez-vous proposé par le service médical – Date proposée : %s – Mode : %s – Statut : Annulé.", 
                    when, getModeText(appointment));
            }
        } else if (rh || manager) {
            if (isEmployeeInitiated) {
                defaultMsg = String.format("L'employé %s – %s a annulé sa demande de rendez-vous – Date demandée : %s – Mode : %s – Statut : Annulé.", 
                    employeeName, employeeEmail, when, getModeText(appointment));
            } else {
                defaultMsg = String.format("L'employé %s – %s a annulé le rendez-vous proposé par le service médical – Date proposée : %s – Mode : %s – Statut : Annulé.", 
                    employeeName, employeeEmail, when, getModeText(appointment));
            }
        } else {
            if (isEmployeeInitiated) {
                // Service médical: employé annule sa demande spontanée
                defaultMsg = String.format("L'employé %s – %s a annulé sa demande de rendez-vous – Statut : Annulé.", 
                    employeeName, employeeEmail);
            } else {
                // Service médical: employé annule le RDV que le service médical avait proposé
                defaultMsg = String.format("L'employé %s – %s a annulé le rendez-vous que vous aviez proposé – Statut : Annulé.", 
                    employeeName, employeeEmail);
            }
        }

        notificationService.sendGeneralNotification(user,
                "Rendez-vous annulé",
                defaultMsg,
                NotificationType.APPOINTMENT,
                buildAppointmentActionLink(appointment, "view"),
                "APPOINTMENT",
                appointment.getId());

        String appointmentType = getAppointmentType(appointment);
        String subject = String.format("Annulation (%s) – %s (%s)", 
            appointmentType, employeeName, employeeEmail);
        
        String templateName = (rh || manager) 
            ? resolveTemplate("appointment-cancellation-rh-template")
            : resolveTemplate("appointment-cancellation-medical-template");
        
        if (rh || manager) {
            // RH gets email without CTA 
            emailService.sendAppointmentNotification(
                    java.util.List.of(user), appointment, subject, templateName
            );
        } else {
            // Medical staff gets email with CTA
            emailService.sendAppointmentNotification(
                    java.util.List.of(user), appointment, subject, templateName,
                    buildAppointmentActionLink(appointment, "view"), "Voir les détails"
            );
        }
    }

    private String getModeText(Appointment appointment) {
        if (appointment.getVisitMode() == null) return "À distance";
        return appointment.getVisitMode() == VisitMode.REMOTE ? "À distance" : "Présentiel";
    }

    /**
     * Détermine si le rendez-vous a été initié par l'employé (SPONTANEOUS) 
     * ou par le service médical (PERIODIC, SURVEILLANCE_PARTICULIERE, MEDICAL_CALL)
     */
    private boolean isEmployeeInitiatedVisit(Appointment appointment) {
        if (appointment.getType() == null) return false;
        
        return switch (appointment.getType()) {
            case SPONTANEOUS -> true;
            case PERIODIC, SURVEILLANCE_PARTICULIERE, MEDICAL_CALL -> false;
            case PRE_RECRUITMENT, RETURN_TO_WORK, OTHER -> 
                // Pour ces types, on peut vérifier le createdBy si disponible
                appointment.getCreatedBy() != null && 
                appointment.getEmployee() != null && 
                appointment.getEmployee().getUser() != null &&
                appointment.getCreatedBy().getId().equals(appointment.getEmployee().getUser().getId());
        };
    }
}
