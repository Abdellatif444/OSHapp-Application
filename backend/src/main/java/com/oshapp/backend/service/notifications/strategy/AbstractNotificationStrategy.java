package com.oshapp.backend.service.notifications.strategy;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.service.EmailService;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.notifications.policy.NotificationVisibilityPolicy;
import org.springframework.beans.factory.annotation.Value;

import java.time.format.DateTimeFormatter;

/**
 * Base class for appointment notification strategies.
 * Centralizes helper methods and privacy decisions via NotificationVisibilityPolicy.
 */
public abstract class AbstractNotificationStrategy implements NotificationStrategy {

    protected final NotificationService notificationService;
    protected final EmailService emailService;
    protected final NotificationVisibilityPolicy visibility;

    @Value("${app.frontend.base-url:http://localhost:3000}")
    protected String frontendBaseUrl;

    protected static final DateTimeFormatter DATE_TIME = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    protected AbstractNotificationStrategy(NotificationService notificationService,
                                           EmailService emailService,
                                           NotificationVisibilityPolicy visibility) {
        this.notificationService = notificationService;
        this.emailService = emailService;
        this.visibility = visibility;
    }

    protected String joinUrl(String base, String pathAndQuery) {
        String b = base;
        String p = pathAndQuery;
        if (b.endsWith("/")) b = b.substring(0, b.length() - 1);
        if (!p.startsWith("/")) p = "/" + p;
        return b + p;
    }

    protected String buildAppointmentActionLink(Appointment appointment, String action) {
        if (appointment == null || appointment.getId() == null) return frontendBaseUrl;
        String path = String.format("appointment_action?id=%d", appointment.getId());
        if (action != null && !action.isBlank()) {
            path += "&action=" + action;
        }
        return joinUrl(frontendBaseUrl, path);
    }

    protected String enrichSubject(String base, Appointment appointment) {
        if (base == null) return "";
        try {
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
            if (appointment != null) {
                if (appointment.getScheduledTime() != null) {
                    return base + " — " + appointment.getScheduledTime().format(fmt);
                }
                if (appointment.getProposedDate() != null) {
                    return base + " — " + appointment.getProposedDate().format(fmt);
                }
                if (appointment.getRequestedDateEmployee() != null) {
                    return base + " — " + appointment.getRequestedDateEmployee().format(fmt);
                }
            }
        } catch (Exception e) {
            // Ignore formatting errors
        }
        return base;
    }

    protected String getAppointmentType(Appointment appointment) {
        // Return concise French labels for appointment types
        try {
            if (appointment == null || appointment.getType() == null) return "Non spécifié";
            switch (appointment.getType()) {
                case PRE_RECRUITMENT:
                    return "Embauche";
                case RETURN_TO_WORK:
                    return "Reprise";
                case PERIODIC:
                    return "Périodique";
                case SPONTANEOUS:
                    return "Spontané";
                case SURVEILLANCE_PARTICULIERE:
                    return "Surveillance particulière";
                case MEDICAL_CALL:
                    return "À l'appel du médecin";
                case OTHER:
                default:
                    return "Autre";
            }
        } catch (Exception e) {
            return "Non spécifié";
        }
    }

    protected String resolveTemplate(String templateName) {
        if (templateName == null || templateName.isBlank()) return "appointment-generic";
        try {
            String path = "templates/" + templateName + ".html";
            if (this.getClass().getClassLoader().getResource(path) != null) {
                return templateName;
            }
        } catch (Exception ignored) {}
        return "appointment-generic";
    }

    protected boolean isEmployeeRecipient(User user, Appointment appointment) {
        return appointment != null && appointment.getEmployee() != null && appointment.getEmployee().getUser() != null
                && user != null && appointment.getEmployee().getUser().getId() != null
                && appointment.getEmployee().getUser().getId().equals(user.getId());
    }
}
