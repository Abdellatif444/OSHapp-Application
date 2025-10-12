package com.oshapp.backend.service.notifications.strategy.impl;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.NotificationType;
import com.oshapp.backend.model.enums.VisitMode;
import com.oshapp.backend.service.EmailService;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.notifications.NotificationActor;
import com.oshapp.backend.service.notifications.NotificationScenario;
import com.oshapp.backend.service.notifications.policy.NotificationVisibilityPolicy;
import com.oshapp.backend.service.notifications.strategy.AbstractNotificationStrategy;
import com.oshapp.backend.service.notifications.strategy.ActorAwareNotificationStrategy;
import org.springframework.stereotype.Component;

import java.util.EnumMap;
import java.util.Map;

@Component
public class MedicalVisitConfirmedByEmployeeStrategy extends AbstractNotificationStrategy implements ActorAwareNotificationStrategy {

    private final Map<MessageContext, String> templateMap = new EnumMap<>(MessageContext.class);

    public MedicalVisitConfirmedByEmployeeStrategy(NotificationService notificationService,
                                                   EmailService emailService,
                                                   NotificationVisibilityPolicy visibility) {
        super(notificationService, emailService, visibility);

        // Préparation des templates par contexte
        templateMap.put(MessageContext.RH, resolveTemplate("medical-visit-confirmed-rh-template"));
        templateMap.put(MessageContext.EMPLOYEE, resolveTemplate("medical-visit-confirmed-employee-template"));
        templateMap.put(MessageContext.MEDICAL, resolveTemplate("medical-visit-confirmed-medical-template"));
    }

    @Override
    public boolean supports(NotificationScenario scenario) {
        return scenario == NotificationScenario.MEDICAL_VISIT_CONFIRMED_BY_EMPLOYEE;
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage) {
        notify(user, appointment, extraMessage, NotificationActor.EMPLOYEE);
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage, NotificationActor actor) {
        String employeeName = getEmployeeName(appointment);
        String employeeEmail = getEmployeeEmail(appointment);
        String when = appointment.getScheduledTime() != null ? appointment.getScheduledTime().format(DATE_TIME) : "";
        String visitTypeText = getAppointmentType(appointment);
        String modeText = getModeText(appointment);

        String message = buildConfirmedMessage(user, appointment, employeeName, employeeEmail, when, visitTypeText, modeText);

        // ✅ On concatène extraMessage au lieu d’écraser
        String finalMessage = (extraMessage != null && !extraMessage.isBlank())
                ? message + " – " + extraMessage
                : message;

        notificationService.sendGeneralNotification(
                user,
                "Visite médicale confirmée",
                finalMessage,
                NotificationType.APPOINTMENT,
                buildAppointmentActionLink(appointment, "view"),
                "APPOINTMENT",
                appointment.getId()
        );

        sendConfirmedEmail(user, appointment, employeeName, visitTypeText);
    }

    private String getEmployeeName(Appointment appointment) {
        if (appointment.getEmployee() != null
                && appointment.getEmployee().getFirstName() != null && !appointment.getEmployee().getFirstName().isBlank()
                && appointment.getEmployee().getLastName() != null && !appointment.getEmployee().getLastName().isBlank()) {
            return appointment.getEmployee().getFirstName() + " " + appointment.getEmployee().getLastName();
        }
        return (appointment.getEmployee() != null && appointment.getEmployee().getUser() != null)
                ? appointment.getEmployee().getUser().getEmail()
                : "Collaborateur";
    }

    private String getEmployeeEmail(Appointment appointment) {
        return (appointment.getEmployee() != null && appointment.getEmployee().getUser() != null)
                ? appointment.getEmployee().getUser().getEmail()
                : "";
    }

    private String getModeText(Appointment appointment) {
        return appointment.getVisitMode() != null
                ? (appointment.getVisitMode() == VisitMode.REMOTE ? "À distance" : "Présentiel")
                : "Présentiel";
    }

    private String buildConfirmedMessage(User user, Appointment appointment, String employeeName, String employeeEmail,
                                         String when, String visitTypeText, String modeText) {

        boolean isEmployeeRecipient = isEmployeeRecipient(user, appointment);
        boolean isRh = visibility.isRh(user);
        boolean isMedicalStaff = visibility.isMedicalStaff(user);
        boolean isEmployeeInitiated = isEmployeeInitiatedVisit(appointment);
        boolean isObligatory = false;
        try { isObligatory = appointment != null && appointment.isObligatory(); } catch (Exception ignored) {}

        String emailDisplay = employeeName + (employeeEmail.isBlank() ? "" : " (" + employeeEmail + ")");

        if (isEmployeeRecipient) {
            StringBuilder msg = new StringBuilder();
            
            if (isEmployeeInitiated) {
                // Employé confirme sa propre demande de visite spontanée
                msg.append(String.format("Vous avez confirmé votre demande de visite médicale (%s) du %s – Modalité : %s",
                        visitTypeText, when, modeText));
            } else {
                // Employé confirme une visite proposée par le service médical
                if (isObligatory) {
                    msg.append(String.format("Vous avez confirmé la visite médicale obligatoire (%s) proposée par le service médical le %s – Modalité : %s",
                            visitTypeText, when, modeText));
                } else {
                    msg.append(String.format("Vous avez confirmé la visite médicale (%s) proposée par le service médical le %s – Modalité : %s",
                            visitTypeText, when, modeText));
                }
            }

            appendInstructions(msg, appointment);
            msg.append(" – Statut : Confirmé.");
            return msg.toString();

        } else if (isRh) {
            if (isEmployeeInitiated) {
                return String.format("L'employé [%s] a confirmé sa demande de visite médicale (%s) le %s – Modalité : %s – Statut : Confirmé.",
                        emailDisplay, visitTypeText, when, modeText);
            } else {
                if (isObligatory) {
                    return String.format("L'employé [%s] a confirmé la visite médicale obligatoire (%s) proposée par le service médical le %s – Modalité : %s – Statut : Confirmé.",
                            emailDisplay, visitTypeText, when, modeText);
                } else {
                    return String.format("L'employé [%s] a confirmé la visite médicale (%s) proposée par le service médical le %s – Modalité : %s – Statut : Confirmé.",
                            emailDisplay, visitTypeText, when, modeText);
                }
            }

        } else if (isMedicalStaff) {
            StringBuilder msg = new StringBuilder();
            
            if (isEmployeeInitiated) {
                // Employé confirme sa propre demande spontanée
                msg.append(String.format("L'employé [%s] a confirmé sa demande de visite médicale (%s) du %s – Modalité : %s",
                        emailDisplay, visitTypeText, when, modeText));
            } else {
                // Employé confirme une visite que le service médical avait proposée
                if (isObligatory) {
                    msg.append(String.format("L'employé [%s] a confirmé la visite médicale obligatoire (%s) que vous aviez proposée le %s – Modalité : %s",
                            emailDisplay, visitTypeText, when, modeText));
                } else {
                    msg.append(String.format("L'employé [%s] a confirmé la visite médicale (%s) que vous aviez proposée le %s – Modalité : %s",
                            emailDisplay, visitTypeText, when, modeText));
                }
            }

            appendInstructions(msg, appointment);
            msg.append(" – Statut : Confirmé.");
            return msg.toString();
        }

        // fallback message
        if (isEmployeeInitiated) {
            return String.format("L'employé [%s] a confirmé sa demande de visite médicale (%s) le %s – Modalité : %s – Statut : Confirmé.",
                    emailDisplay, visitTypeText, when, modeText);
        } else {
            if (isObligatory) {
                return String.format("L'employé [%s] a confirmé la visite médicale obligatoire (%s) proposée par le service médical le %s – Modalité : %s – Statut : Confirmé.",
                        emailDisplay, visitTypeText, when, modeText);
            } else {
                return String.format("L'employé [%s] a confirmé la visite médicale (%s) proposée par le service médical le %s – Modalité : %s – Statut : Confirmé.",
                        emailDisplay, visitTypeText, when, modeText);
            }
        }
    }

    private void sendConfirmedEmail(User user, Appointment appointment, String employeeName, String visitTypeText) {
        boolean isEmployeeRecipient = isEmployeeRecipient(user, appointment);
        boolean isRh = visibility.isRh(user);

        boolean isObligatory = false;
        try { isObligatory = appointment != null && appointment.isObligatory(); } catch (Exception ignored) {}
        String subject = isRh
                ? (isObligatory ? "Rendez-vous confirmé – Visite médicale obligatoire (" + visitTypeText + ") – " + employeeName + formatEmployeeEmail(appointment)
                                 : "Rendez-vous confirmé – " + employeeName + formatEmployeeEmail(appointment))
                : (isObligatory ? "Confirmation – Visite médicale obligatoire (" + visitTypeText + ") – " + employeeName + formatEmployeeEmail(appointment)
                                 : "Confirmation de visite médicale – " + employeeName + formatEmployeeEmail(appointment));

        MessageContext context = isRh ? MessageContext.RH : (isEmployeeRecipient ? MessageContext.EMPLOYEE : MessageContext.MEDICAL);
        String template = templateMap.get(context);

        if (isRh) {
            emailService.sendAppointmentNotification(
                    java.util.List.of(user), appointment, subject, template
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
                    java.util.List.of(user), appointment, subject, template,
                    buildAppointmentActionLink(appointment, "view"),
                    "Voir les détails",
                    secondaryUrl,
                    secondaryLabel
            );
        }
    }

    private String getVisitTypeText(Appointment appointment) {
        if (appointment.getType() == null) return "Non spécifié";

        return switch (appointment.getType()) {
            case PERIODIC -> "Périodique";
            case SURVEILLANCE_PARTICULIERE -> "Surveillance particulière";
            case MEDICAL_CALL -> "À l'appel du médecin";
            case PRE_RECRUITMENT -> "Pré-recrutement";
            case RETURN_TO_WORK -> "Reprise de travail";
            case SPONTANEOUS -> "Spontané";
            case OTHER -> "Autre";
        };
    }

    private void appendInstructions(StringBuilder msg, Appointment appointment) {
        if (appointment.getMedicalInstructions() != null && !appointment.getMedicalInstructions().isBlank()) {
            msg.append(" – Consignes : ").append(appointment.getMedicalInstructions());
        }
    }

    private String formatEmployeeEmail(Appointment appointment) {
        String email = getEmployeeEmail(appointment);
        return email.isBlank() ? "" : " (" + email + ")";
    }

    /**
     * Détermine si la visite a été initiée par l'employé (SPONTANEOUS) 
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

    private enum MessageContext {
        EMPLOYEE,
        RH,
        MEDICAL
    }
}
