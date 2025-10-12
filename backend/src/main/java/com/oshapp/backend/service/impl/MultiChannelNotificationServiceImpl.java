package com.oshapp.backend.service.impl;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.NotificationType;
import com.oshapp.backend.model.enums.RoleName;
import com.oshapp.backend.service.EmailService;
import com.oshapp.backend.service.MultiChannelNotificationService;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.UserService;
import com.oshapp.backend.service.notifications.NotificationScenario;
import com.oshapp.backend.service.notifications.strategy.NotificationStrategy;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import com.oshapp.backend.service.notifications.NotificationActor;
import com.oshapp.backend.service.notifications.strategy.ActorAwareNotificationStrategy;


import java.time.format.DateTimeFormatter;
import java.util.Collections;
import java.util.List;
import java.util.Set;

@Service
@Slf4j
@RequiredArgsConstructor
public class MultiChannelNotificationServiceImpl implements MultiChannelNotificationService {

    private final NotificationService notificationService;
    private final EmailService emailService;
    private final UserService userService;

    @Autowired(required = false)
    private List<NotificationStrategy> notificationStrategies = Collections.emptyList();
    
    @Value("${app.frontend.base-url:http://localhost:3000}")
    private String frontendBaseUrl;

    private String joinUrl(String base, String pathAndQuery) {
        String b = base;
        String p = pathAndQuery;
        if (b.endsWith("/")) b = b.substring(0, b.length() - 1);
        if (!p.startsWith("/")) p = "/" + p;
        return b + p;
    }

    private String buildAppointmentActionLink(Appointment appointment, String action) {
        if (appointment == null || appointment.getId() == null) return frontendBaseUrl;
        String path = String.format("appointment_action?id=%d", appointment.getId());
        if (action != null && !action.isBlank()) path += "&action=" + action;
        return joinUrl(frontendBaseUrl, path);
    }

    private String enrichSubject(String base, Appointment appointment) {
        if (base == null) return "";
        try {
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
            if (appointment != null) {
                if (appointment.getScheduledTime() != null) return base + " — " + appointment.getScheduledTime().format(fmt);
                if (appointment.getProposedDate() != null) return base + " — " + appointment.getProposedDate().format(fmt);
                if (appointment.getRequestedDateEmployee() != null) return base + " — " + appointment.getRequestedDateEmployee().format(fmt);
            }
        } catch (Exception e) {
            log.warn("Failed to enrich email subject for appointment {}: {}", appointment != null ? appointment.getId() : null, e.getMessage());
        }
        return base;
    }

    private boolean isRh(User user) {
        try {
            return user != null && user.getRoles() != null && user.getRoles().stream().anyMatch(r -> r.getName() == RoleName.ROLE_RH);
        } catch (Exception e) {
            return false;
        }
    }

    private boolean isManagerForAppointment(User user, Appointment appointment) {
        if (user == null || appointment == null || appointment.getEmployee() == null) return false;
        try {
            return (appointment.getEmployee().getManager1() != null &&
                    appointment.getEmployee().getManager1().getUser() != null &&
                    user.getId() != null && user.getId().equals(appointment.getEmployee().getManager1().getUser().getId()))
                || (appointment.getEmployee().getManager2() != null &&
                    appointment.getEmployee().getManager2().getUser() != null &&
                    user.getId() != null && user.getId().equals(appointment.getEmployee().getManager2().getUser().getId()));
        } catch (Exception e) {
            return false;
        }
    }

    private boolean isMedicalStaff(User user) {
        try {
            return user != null && user.getRoles() != null && user.getRoles().stream()
                .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE || r.getName() == RoleName.ROLE_DOCTOR);
        } catch (Exception e) {
            return false;
        }
    }

    private boolean shouldHideEmailCta(User user, Appointment appointment) {
        return isRh(user) || isManagerForAppointment(user, appointment);
    }

    

    @Override
    public void notifyUsersWithChannels(Set<User> users, String title, String message, List<String> channels) {
        if (users == null || users.isEmpty()) return;
        for (User user : users) {
            notificationService.sendGeneralNotification(user, title, message, NotificationType.APPOINTMENT, null, null, null);
            emailService.sendAppointmentNotification(Collections.singletonList(user), null, title, "generic-notification-template");
        }
    }

    @Override
    public void sendAppointmentNotification(User user, Appointment appointment) {
        notificationService.sendAppointmentNotification(user, appointment);
        String subject = enrichSubject("Nouveau rendez-vous", appointment);
        if (shouldHideEmailCta(user, appointment)) {
            emailService.sendAppointmentNotification(Collections.singletonList(user), appointment, subject, "appointment-generic");
        } else {
            emailService.sendAppointmentNotification(Collections.singletonList(user), appointment, subject, "appointment-generic",
                buildAppointmentActionLink(appointment, "view"), "Ouvrir le rendez-vous");
        }
    }

    @Override
    public void sendAppointmentStatusNotification(User user, Appointment appointment) {
        notificationService.sendAppointmentStatusNotification(user, appointment);
        String subject = enrichSubject("Mise à jour de votre rendez-vous", appointment);
        if (shouldHideEmailCta(user, appointment)) {
            emailService.sendAppointmentNotification(Collections.singletonList(user), appointment, subject, "appointment-generic");
        } else {
            emailService.sendAppointmentNotification(Collections.singletonList(user), appointment, subject, "appointment-generic",
                buildAppointmentActionLink(appointment, "view"), "Voir le rendez-vous");
        }
    }

    @Override
    public void sendObligatoryAppointmentNotification(User user, Appointment appointment) {
        notificationService.sendGeneralNotification(user,
                "Visite médicale obligatoire",
                "Une visite médicale obligatoire a été programmée pour vous. Veuillez confirmer votre disponibilité.",
                NotificationType.APPOINTMENT,
                buildAppointmentActionLink(appointment, "confirm"),
                "APPOINTMENT",
                appointment.getId());

        emailService.sendAppointmentNotification(Collections.singletonList(user), appointment,
                enrichSubject("Visite médicale obligatoire", appointment), "appointment-generic",
                buildAppointmentActionLink(appointment, "confirm"), "Confirmer le rendez-vous");
    }

    @Override
    public void sendBulkObligatoryAppointments(List<User> users, List<Appointment> appointments) {
        if (users == null || appointments == null) return;
        for (int i = 0; i < users.size() && i < appointments.size(); i++) {
            sendObligatoryAppointmentNotification(users.get(i), appointments.get(i));
        }
    }

    @Override
    public void notifyAllActors(Appointment appointment, List<User> actors) {
        if (actors == null) return;
        for (User actor : actors) {
            if (actor != null) sendAppointmentNotification(actor, appointment);
        }
    }

    @Override
    public void notifyManagersOfProposal(Appointment appointment, List<User> managers) {
        String message = String.format("Un créneau médical a été proposé pour %s %s. Vous pouvez signaler une indisponibilité si nécessaire.",
                appointment.getEmployee().getFirstName(), appointment.getEmployee().getLastName());
        notifyManagers(managers, appointment, "Proposition de créneau médical", message, "appointment-proposal-template", NotificationType.VALIDATION);
    }

    @Override
    public void notifyConfirmation(Appointment appointment, User employee, List<User> managers) {
        if (employee != null) sendAppointmentStatusNotification(employee, appointment);
        String message = String.format("Le rendez-vous médical de %s %s a été confirmé.",
                appointment.getEmployee().getFirstName(), appointment.getEmployee().getLastName());
        notifyManagers(managers, appointment, "Rendez-vous médical confirmé", message, "appointment-confirmation-template", NotificationType.APPOINTMENT);
    }

    private void notifyManagers(List<User> managers, Appointment appointment, String title, String message, String emailTemplate, NotificationType notificationType) {
        if (managers == null) return;
        for (User manager : managers) {
            if (manager != null) {
                notificationService.sendGeneralNotification(manager, title, message, notificationType,
                        buildAppointmentActionLink(appointment, "view"), "APPOINTMENT", appointment.getId());
                emailService.sendAppointmentNotification(Collections.singletonList(manager), appointment,
                        enrichSubject(title, appointment), emailTemplate != null ? emailTemplate : "appointment-generic");
            }
        }
    }

    @Override
    public void notifyUsers(List<User> users, Appointment appointment, String scenario, String extraMessage) {
        if (users == null || users.isEmpty()) return;
        for (User user : users) {
            if (user == null) continue;
            try {
                if (delegateToStrategyWithActor(user, appointment, scenario, extraMessage, null)) continue;
            } catch (Exception e) {
                log.error("Strategy handler failed for scenario {} and user {}. Error: {}", scenario, user.getId(), e.getMessage());
            }
            // Minimal legacy fallback only
            switch (scenario) {
                case "CREATION":
                    sendAppointmentNotification(user, appointment);
                    break;
                case "STATUS_UPDATE":
                    sendAppointmentStatusNotification(user, appointment);
                    break;
                case "OBLIGATORY":
                    sendObligatoryAppointmentNotification(user, appointment);
                    break;
                default:
                    log.warn("Unknown notification scenario (legacy fallback): {}", scenario);
            }
        }
    }

    @Override
    public void notifyUsers(List<User> users, Appointment appointment, String scenario, String extraMessage, NotificationActor actor) {
        if (users == null || users.isEmpty()) return;
        for (User user : users) {
            if (user == null) continue;
            try {
                if (delegateToStrategyWithActor(user, appointment, scenario, extraMessage, actor)) continue;
            } catch (Exception e) {
                log.error("Strategy handler (actor-aware) failed for scenario {} and user {}. Error: {}", scenario, user.getId(), e.getMessage());
            }
            // Minimal legacy fallback only
            switch (scenario) {
                case "CREATION":
                    sendAppointmentNotification(user, appointment);
                    break;
                case "STATUS_UPDATE":
                    sendAppointmentStatusNotification(user, appointment);
                    break;
                case "OBLIGATORY":
                    sendObligatoryAppointmentNotification(user, appointment);
                    break;
                default:
                    log.warn("Unknown notification scenario (legacy fallback): {}", scenario);
            }
        }
    }

    private boolean delegateToStrategyWithActor(User user, Appointment appointment, String scenarioStr, String extraMessage, NotificationActor actorOverride) {
        try {
            NotificationScenario scenario = NotificationScenario.fromString(scenarioStr);
            if (scenario == null || notificationStrategies == null || notificationStrategies.isEmpty()) return false;
            NotificationActor actor = actorOverride != null ? actorOverride : NotificationScenario.extractActor(scenarioStr);
            for (NotificationStrategy strategy : notificationStrategies) {
                try {
                    if (strategy != null && strategy.supports(scenario)) {
                        if (strategy instanceof ActorAwareNotificationStrategy) {
                            ((ActorAwareNotificationStrategy) strategy)
                                .notify(user, appointment, extraMessage, actor);
                        } else {
                            strategy.notify(user, appointment, extraMessage);
                        }
                        return true;
                    }
                } catch (Exception ex) {
                    log.error("Strategy {} failed for scenario {} and user {}: {}", strategy != null ? strategy.getClass().getSimpleName() : "null", scenarioStr, user.getId(), ex.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Delegate to strategy (actor-aware) failed for scenario {}: {}", scenarioStr, e.getMessage());
        }
        return false;
    }

    @Override
    public void sendEmailNotification(String email, String subject, String content) {
        if (email == null || email.isBlank()) return;
        try {
            emailService.sendSimpleEmail(email, subject != null ? subject : "", content != null ? content : "");
        } catch (Exception ex) {
            log.error("Failed to send email notification to {}: {}", email, ex.getMessage());
        }
    }

    @Override
    public void sendInAppNotification(Long userId, String title, String message) {
        if (userId == null) return;
        try {
            userService.findById(userId).ifPresentOrElse(user ->
                notificationService.sendGeneralNotification(user,
                        title != null ? title : "Notification",
                        message != null ? message : "",
                        NotificationType.APPOINTMENT),
                () -> log.warn("User not found for in-app notification: id={}", userId)
            );
        } catch (Exception ex) {
            log.error("Failed to send in-app notification to user {}: {}", userId, ex.getMessage());
        }
    }
}
