package com.oshapp.backend.service.notifications.strategy.impl;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.NotificationType;
import com.oshapp.backend.service.EmailService;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.notifications.NotificationActor;
import com.oshapp.backend.service.notifications.NotificationScenario;
import com.oshapp.backend.service.notifications.policy.NotificationVisibilityPolicy;
import com.oshapp.backend.service.notifications.strategy.AbstractNotificationStrategy;
import com.oshapp.backend.service.notifications.strategy.ActorAwareNotificationStrategy;
import org.springframework.stereotype.Component;


/**
 * Unified strategy for all appointment confirmation scenarios.
 * Handles confirmations by employees, medical staff, and RH with appropriate messaging and privacy rules.
 */
@Component
public class AppointmentConfirmedStrategy extends AbstractNotificationStrategy implements ActorAwareNotificationStrategy {

    public AppointmentConfirmedStrategy(NotificationService notificationService,
                                        EmailService emailService,
                                        NotificationVisibilityPolicy visibility) {
        super(notificationService, emailService, visibility);
    }

    @Override
    public boolean supports(NotificationScenario scenario) {
        return scenario == NotificationScenario.APPOINTMENT_CONFIRMED;
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage) {
        // Fallback for strategies that don't provide actor context
        notify(user, appointment, extraMessage, null);
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage, NotificationActor actor) {
        String employeeName = (appointment.getEmployee() != null && appointment.getEmployee().getFirstName() != null && !appointment.getEmployee().getFirstName().isBlank()
                && appointment.getEmployee().getLastName() != null && !appointment.getEmployee().getLastName().isBlank())
                ? appointment.getEmployee().getFirstName() + " " + appointment.getEmployee().getLastName()
                : (appointment.getEmployee() != null && appointment.getEmployee().getUser() != null ? appointment.getEmployee().getUser().getEmail() : "Collaborateur");
        String employeeEmail = appointment.getEmployee() != null && appointment.getEmployee().getUser() != null
                ? appointment.getEmployee().getUser().getEmail() : "";

        String when = appointment.getScheduledTime() != null ? appointment.getScheduledTime().format(DATE_TIME)
                : (appointment.getProposedDate() != null ? appointment.getProposedDate().format(DATE_TIME) : "");
        String modePart = "";
        if (appointment.getVisitMode() != null) {
            String modeStr = appointment.getVisitMode() == com.oshapp.backend.model.enums.VisitMode.REMOTE
                    ? " –mode: À distance" : " –mode: Présentiel";
            modePart = modeStr;
        }

        // Build message based on actor and recipient
        String defaultMsg = buildConfirmationMessage(user, appointment, actor, employeeName, employeeEmail, when, modePart);

        notificationService.sendGeneralNotification(user,
                "Rendez-vous confirmé",
                extraMessage != null ? extraMessage : defaultMsg,
                NotificationType.APPOINTMENT,
                buildAppointmentActionLink(appointment, "view"),
                "APPOINTMENT",
                appointment.getId());

        // Send email with appropriate template and CTA based on role
        sendConfirmationEmail(user, appointment, actor, employeeName);
    }

    private String buildConfirmationMessage(User user, Appointment appointment, NotificationActor actor, 
                                            String employeeName, String employeeEmail, String when, String modePart) {
        boolean isEmployeeRecipient = isEmployeeRecipient(user, appointment);
        boolean isRh = visibility.isRh(user);
        boolean isManager = visibility.isManagerForAppointment(user, appointment);
        boolean isEmployeeInitiated = isEmployeeInitiatedVisit(appointment);

        if (actor == NotificationActor.EMPLOYEE) {
            // Employee confirmed proposed slot
            if (isEmployeeRecipient) {
                if (isEmployeeInitiated) {
                    // Employé confirme sa propre demande après proposition du service médical
                    return String.format("Vous avez confirmé le créneau proposé pour votre demande de rendez-vous –Date confirmée : %s – Mode : %s– Statut : Confirmé.", 
                        when, getModeText(appointment));
                } else {
                    // Employé confirme un créneau proposé par le service médical (visite planifiée)
                    return String.format("Vous avez confirmé le créneau proposé par le service médical –Date confirmée : %s – Mode : %s– Statut : Confirmé.", 
                        when, getModeText(appointment));
                }
            } else if (isRh || isManager) {
                if (isEmployeeInitiated) {
                    return String.format("L'employé %s – %s a confirmé le créneau proposé pour sa demande de rendez-vous –Date confirmée : %s – Mode : %s– – Statut : Confirmé.", 
                        employeeName, employeeEmail, when, getModeText(appointment));
                } else {
                    return String.format("L'employé %s – %s a confirmé le rendez-vous proposé par le service médical –Date confirmée : %s – Mode : %s– – Statut : Confirmé.", 
                        employeeName, employeeEmail, when, getModeText(appointment));
                }
            } else {
                if (isEmployeeInitiated) {
                    // Service médical: employé confirme le créneau pour sa demande
                    return String.format("L'employé %s – %s a confirmé le créneau proposé pour sa demande – –Date confirmée : %s – Mode : %s– Statut : Confirmé.", 
                        employeeName, employeeEmail, when, getModeText(appointment));
                } else {
                    // Service médical: employé confirme le rendez-vous que le service médical avait proposé
                    return String.format("L'employé %s – %s a confirmé le rendez-vous que vous aviez proposé – –Date confirmée : %s – Mode : %s– Statut : Confirmé.", 
                        employeeName, employeeEmail, when, getModeText(appointment));
                }
            }

        } else if (actor == NotificationActor.MEDICAL_STAFF || actor == null) {
            // Medical staff confirmed request
            boolean isActorMedical = appointment.getUpdatedBy() != null && user.getId() != null
                && appointment.getUpdatedBy().getId() != null
                && user.getId().equals(appointment.getUpdatedBy().getId());
            if (isEmployeeRecipient) {
                if (isEmployeeInitiated) {
                    // Employé: sa demande a été confirmée par le service médical
                    String[] parts = when.split(" ");
                    String datePart = parts.length > 0 ? parts[0] : when;
                    String timePart = parts.length > 1 ? parts[1] : "";
                    return String.format("Votre demande de rendez-vous a été confirmée par le service médical – Date : %s – %s Statut : Confirmé.", 
                        datePart, timePart);
                } else {
                    // Employé: visite planifiée par le service médical confirmée
                    String[] parts = when.split(" ");
                    String datePart = parts.length > 0 ? parts[0] : when;
                    String timePart = parts.length > 1 ? parts[1] : "";
                    return String.format("La visite médicale planifiée a été confirmée par le service médical – Date : %s – %s Statut : Confirmé.", 
                        datePart, timePart);
                }
            } else if (isRh || isManager) {
                if (isEmployeeInitiated) {
                    return String.format("Le service médical a confirmé la demande de rendez-vous de l'employé %s – %s – Date validé : %s –mode: %s –– Statut : Confirmé.", 
                        employeeName, employeeEmail, when, getModeText(appointment));
                } else {
                    return String.format("Le service médical a confirmé la visite planifiée pour l'employé %s – %s – Date validé : %s –mode: %s –– Statut : Confirmé.", 
                        employeeName, employeeEmail, when, getModeText(appointment));
                }
            } else {
                // Service médical: actor vs. other medical staff
                if (isActorMedical) {
                    if (isEmployeeInitiated) {
                        // Acting medical staff confirme une demande employé
                        return String.format("Vous avez confirmé la demande de rendez-vous de %s – %s – Date validé : %s  –mode: %s –Statut : Confirmé.", 
                            employeeName, employeeEmail, when, getModeText(appointment));
                    } else {
                        // Acting medical staff confirme une visite qu'il avait planifiée
                        return String.format("Vous avez confirmé la visite planifiée pour %s – %s – Date validé : %s  –mode: %s –Statut : Confirmé.", 
                            employeeName, employeeEmail, when, getModeText(appointment));
                    }
                } else {
                    if (isEmployeeInitiated) {
                        return String.format("Le service médical a confirmé la demande de rendez-vous de l'employé %s – %s – Date validé : %s –mode: %s –– Statut : Confirmé.", 
                            employeeName, employeeEmail, when, getModeText(appointment));
                    } else {
                        return String.format("Le service médical a confirmé la visite planifiée pour l'employé %s – %s – Date validé : %s –mode: %s –– Statut : Confirmé.", 
                            employeeName, employeeEmail, when, getModeText(appointment));
                    }
                }
            }
        } else if (actor == NotificationActor.RH) {
            if (isEmployeeInitiated) {
                return String.format("Le service médical a confirmé la demande de rendez-vous pour l'employé %s– %s – Date validé : %s –mode: %s  – Statut : Confirmé.", 
                    employeeName, employeeEmail, when, getModeText(appointment));
            } else {
                return String.format("Le service médical a confirmé la visite planifiée pour %s –%s– Date validé : %s –mode: %s –  Statut : Confirmé.", 
                    employeeName, employeeEmail, when, getModeText(appointment));
            }
        }

        // Fallback
        if (isEmployeeInitiated) {
            return String.format("Demande de rendez-vous confirmée pour %s le %s – Statut : Confirmé.", employeeName, when);
        } else {
            return String.format("Visite planifiée confirmée pour %s le %s – Statut : Confirmé.", employeeName, when);
        }
    }

    private String getModeText(Appointment appointment) {
        if (appointment.getVisitMode() == null) return "Présentiel ou à distance";
        return appointment.getVisitMode() == com.oshapp.backend.model.enums.VisitMode.REMOTE 
            ? "À distance" : "Présentiel";
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


    private void sendConfirmationEmail(User user, Appointment appointment, NotificationActor actor, String employeeName) {
        boolean isRh = visibility.isRh(user);
        boolean isManager = visibility.isManagerForAppointment(user, appointment);
        
        String subject = getEmailSubject(actor, employeeName);
        String templateName = getEmailTemplate(isRh, user);

        if (isRh || isManager) {
            emailService.sendAppointmentNotification(
                    java.util.List.of(user), appointment, subject, templateName
            );
        } else {
            String secondaryUrl = null;
            String secondaryLabel = null;
            try {
                if (appointment != null && appointment.getType() == com.oshapp.backend.model.enums.AppointmentType.RETURN_TO_WORK) {
                    secondaryUrl = buildAppointmentActionLink(appointment, "certificate");
                    secondaryLabel = "Voir le certificat";
                }
            } catch (Exception ignored) {}

            emailService.sendAppointmentNotification(
                    java.util.List.of(user), appointment, subject, templateName,
                    buildAppointmentActionLink(appointment, "view"), "Voir le rendez-vous",
                    secondaryUrl, secondaryLabel
            );
        }
    }

    private String getEmailSubject(NotificationActor actor, String employeeName) {
        if (actor == NotificationActor.EMPLOYEE) {
            return "Confirmation du créneau proposé — " + employeeName;
        } else {
            return enrichSubject("Confirmation de votre rendez-vous médical", null);
        }
    }

    private String getEmailTemplate(boolean isRh, User user) {
        if (isRh) {
            return resolveTemplate("appointment-confirmation-rh-template");
        } else if (visibility.isMedicalStaff(user)) {
            return resolveTemplate("appointment-confirmation-medical-template");
        } else {
            return resolveTemplate("appointment-confirmation-template");
        }
    }
}
