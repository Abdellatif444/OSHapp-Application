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
import lombok.extern.slf4j.Slf4j;
import java.util.HashMap;
import java.util.Map;

@Component
@Slf4j
public class MedicalVisitPlannedStrategy extends AbstractNotificationStrategy implements ActorAwareNotificationStrategy {

    public MedicalVisitPlannedStrategy(NotificationService notificationService,
                                       EmailService emailService,
                                       NotificationVisibilityPolicy visibility) {
        super(notificationService, emailService, visibility);
    }

    @Override
    public boolean supports(NotificationScenario scenario) {
        return scenario == NotificationScenario.MEDICAL_VISIT_PLANNED;
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage) {
        notify(user, appointment, extraMessage, NotificationActor.MEDICAL_STAFF);
    }

    @Override
    public void notify(User user, Appointment appointment, String extraMessage, NotificationActor actor) {
        log.info("MedicalVisitPlannedStrategy: Notifying user {} (email: {}) for appointment type: {}", 
                user.getUsername(), user.getEmail(), appointment.getType());
        
        String employeeName = getEmployeeName(appointment);
        String employeeEmail = getEmployeeEmail(appointment);
        String when = appointment.getScheduledTime() != null ? appointment.getScheduledTime().format(DATE_TIME) : "";
        String visitTypeText = getVisitTypeText(appointment);
        String modeText = getModeText(appointment);

        String message = buildPlannedVisitMessage(user, appointment, employeeName, employeeEmail, when, visitTypeText, modeText);

        // Concaténer extraMessage au lieu de l'écraser, pour rester cohérent avec les autres stratégies
        String finalMessage = (extraMessage != null && !extraMessage.isBlank())
                ? message + " – " + extraMessage
                : message;

        notificationService.sendGeneralNotification(user,
                "Proposition de visite médicale",
                finalMessage,
                NotificationType.APPOINTMENT,
                buildAppointmentActionLink(appointment, "view"),
                "APPOINTMENT",
                appointment.getId());

        sendPlannedVisitEmail(user, appointment, employeeName, visitTypeText);
    }

    private String getEmployeeName(Appointment appointment) {
        return (appointment.getEmployee() != null && appointment.getEmployee().getFirstName() != null && !appointment.getEmployee().getFirstName().isBlank()
                && appointment.getEmployee().getLastName() != null && !appointment.getEmployee().getLastName().isBlank())
                ? appointment.getEmployee().getFirstName() + " " + appointment.getEmployee().getLastName()
                : (appointment.getEmployee() != null && appointment.getEmployee().getUser() != null ? appointment.getEmployee().getUser().getEmail() : "Collaborateur");
    }

    private String getEmployeeEmail(Appointment appointment) {
        return appointment.getEmployee() != null && appointment.getEmployee().getUser() != null
                ? appointment.getEmployee().getUser().getEmail() : "";
    }

    private String getModeText(Appointment appointment) {
        return appointment.getVisitMode() != null 
            ? (appointment.getVisitMode() == com.oshapp.backend.model.enums.VisitMode.REMOTE ? "À distance" : "Présentiel")
            : "Non spécifié";
    }

    private String buildPlannedVisitMessage(User user, Appointment appointment, String employeeName, String employeeEmail, 
                                            String when, String visitTypeText, String modeText) {
        boolean isEmployeeRecipient = isEmployeeRecipient(user, appointment);
        boolean isRh = visibility.isRh(user);
        boolean isMedicalStaff = visibility.isMedicalStaff(user);

        if (isEmployeeRecipient) {
            StringBuilder msg = new StringBuilder();
            msg.append(String.format("Le service médical vous propose une visite médicale (%s) le %s – Modalité : %s", 
                visitTypeText, when, modeText));
            
            // Consignes visibles pour l'employé
            if (appointment.getMedicalInstructions() != null && !appointment.getMedicalInstructions().isBlank()) {
                msg.append(" – Consignes : ").append(appointment.getMedicalInstructions());
            }
            
            msg.append(" – Statut : En attente.");
            return msg.toString();
            
        } else if (isRh) {
            // RH ne voit PAS les consignes ni le téléphone - format exact spécifié
            return String.format("Le service médical a proposé une visite médicale (%s) pour [%s – %s] le %s – Modalité : %s – Statut : En attente.", 
                visitTypeText, employeeName, employeeEmail, when, modeText);
                
        } else if (isMedicalStaff) {
            boolean isActorMedical = appointment.getCreatedBy() != null && appointment.getCreatedBy().getId() != null
                && user.getId() != null && appointment.getCreatedBy().getId().equals(user.getId());
            StringBuilder msg = new StringBuilder();
            if (isActorMedical) {
                msg.append(String.format("Vous avez planifié une visite médicale (%s) pour [%s – %s] le %s – Modalité : %s", 
                    visitTypeText, employeeName, employeeEmail, when, modeText));
            } else {
                msg.append(String.format("Le service médical a planifié une visite médicale (%s) pour [%s – %s] le %s – Modalité : %s", 
                    visitTypeText, employeeName, employeeEmail, when, modeText));
            }
            
            // Consignes visibles pour le service médical
            if (appointment.getMedicalInstructions() != null && !appointment.getMedicalInstructions().isBlank()) {
                msg.append(" – Consignes : ").append(appointment.getMedicalInstructions());
            }
            
            msg.append(" – Statut : En attente.");
            return msg.toString();
        }

        // Fallback - pas de consignes
        return String.format("Le service médical a proposé une visite médicale (%s) pour [%s – %s] le %s – Modalité : %s – Statut : En attente.", 
            visitTypeText, employeeName, employeeEmail, when, modeText);
    }

    private void sendPlannedVisitEmail(User user, Appointment appointment, String employeeName, String visitTypeText) {
        boolean isEmployeeRecipient = isEmployeeRecipient(user, appointment);
        boolean isRh = visibility.isRh(user);

        // Normaliser le sujet pour inclure l'email entre parenthèses, comme dans les autres stratégies
        String subject = "Proposition de visite médicale – " + employeeName + formatEmployeeEmail(appointment);

        String template = getEmailTemplate(isRh, isEmployeeRecipient);
        
        // Debug logging to identify template resolution issues
        log.info("MedicalVisitPlannedStrategy: Sending email to {} (employee recipient: {}, RH: {}, template: {})", 
                user.getEmail(), isEmployeeRecipient, isRh, template);

        // Préparer le contexte supplémentaire attendu par les templates Thymeleaf
        Map<String, Object> extra = new HashMap<>();
        extra.put("visitTypeText", visitTypeText);
        extra.put("appointmentDateTime", appointment.getScheduledTime() != null ? appointment.getScheduledTime().format(DATE_TIME) : "");
        extra.put("visitModeText", getModeText(appointment));
        extra.put("medicalInstructions", appointment.getMedicalInstructions());
        extra.put("employeeName", employeeName);
        extra.put("employeeEmail", getEmployeeEmail(appointment));
        extra.put("medicalServicePhone", appointment.getMedicalServicePhone());

        if (isRh) {
            emailService.sendAppointmentNotification(
                java.util.List.of(user), appointment, subject, template,
                null, null,
                null, null,
                extra
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
                buildAppointmentActionLink(appointment, isEmployeeRecipient ? "confirm" : "view"), 
                isEmployeeRecipient ? "Répondre" : "Voir les détails",
                secondaryUrl, secondaryLabel,
                extra
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

    private String getEmailTemplate(boolean isRh, boolean isEmployee) {
        if (isRh) {
            return resolveTemplate("medical-visit-planned-rh-template");
        } else if (isEmployee) {
            return resolveTemplate("medical-visit-planned-employee-template");
        } else {
            return resolveTemplate("medical-visit-planned-medical-template");
        }
    }

    private String formatEmployeeEmail(Appointment appointment) {
        String email = getEmployeeEmail(appointment);
        return email.isBlank() ? "" : " (" + email + ")";
    }
}
