package com.oshapp.backend.service.impl;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.RoleName;
import com.oshapp.backend.service.EmailService;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.io.ClassPathResource;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import java.util.List;
import java.util.Arrays;
import java.util.Map;

@Service
@Slf4j
@RequiredArgsConstructor
public class EmailServiceImpl implements EmailService {

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;
    private final Environment environment;

    @Value("${spring.mail.username:}")
    private String mailUsername;

    @Value("${app.mail.redirect.enabled:false}")
    private boolean redirectEnabled;

    private boolean isDockerProfileActive() {
        return Arrays.stream(environment.getActiveProfiles()).anyMatch(p -> "docker".equalsIgnoreCase(p));
    }

    private String resolveRecipientEmail(String original) {
        if (original == null || original.isBlank()) return null;
        if (redirectEnabled && original.toLowerCase().endsWith("@gmail.com")) {
            if (mailUsername != null && !mailUsername.isBlank()) {
                log.warn("[Mail Redirect] redirecting email from {} to {} (app.mail.redirect.enabled=true)", original, mailUsername);
                return mailUsername;
            }
        }
        return original;
    }

    private String getUserDisplayName(User user) {
        if (user.getEmployee() != null && user.getEmployee().getFirstName() != null && !user.getEmployee().getFirstName().isEmpty()) {
            return user.getEmployee().getFirstName();
        }
        return user.getUsername();
    }

    @Override
    @Async
    public void sendActivationEmail(User user, String token) {
        try {
            MimeMessage mimeMessage = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

            Context context = new Context();
            context.setVariable("name", getUserDisplayName(user));
            context.setVariable("token", token);

            String htmlContent = templateEngine.process("activation-email", context);

            helper.setTo(user.getEmail());
            helper.setSubject("Activez votre compte OSHapp");
            helper.setText(htmlContent, true);

            mailSender.send(mimeMessage);
            log.info("Activation email sent to {}", user.getEmail());
        } catch (MessagingException e) {
            log.error("Failed to send activation email to {}", user.getEmail(), e);
        }
    }

    @Override
    @Async
    public void sendPasswordResetEmail(User user, String token) {
        try {
            MimeMessage mimeMessage = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

            Context context = new Context();
            context.setVariable("name", getUserDisplayName(user));
            context.setVariable("token", token);

            String htmlContent = templateEngine.process("password-reset-email", context);

            String toEmail = resolveRecipientEmail(user.getEmail());
            if (toEmail == null || toEmail.isBlank()) {
                log.warn("Skipping password reset email: unresolved recipient for username={}", user.getUsername());
                return;
            }
            helper.setTo(toEmail);
            helper.setSubject("Réinitialisation de votre mot de passe OSHapp");
            helper.setText(htmlContent, true);

            mailSender.send(mimeMessage);
            log.info("Password reset email sent to {}", user.getEmail());
        } catch (MessagingException e) {
            log.error("Failed to send password reset email to {}", user.getEmail(), e);
        }
    }

    @Override
    @Async
    public void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template) {
        if (recipients == null || recipients.isEmpty()) {
            log.warn("No recipients for appointment notification with subject: {}", subject);
            return;
        }
        // Delegate to overload without CTA
        sendAppointmentNotification(recipients, appointment, subject, template, null, null, null, null);
    }

    @Override
    @Async
    public void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template,
                                            String actionUrl, String actionLabel) {
        // Delegate to overload with potential secondary CTA, passing null for secondary
        sendAppointmentNotification(recipients, appointment, subject, template, actionUrl, actionLabel, null, null);
    }

    @Override
    @Async
    public void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template,
                                            String actionUrl, String actionLabel,
                                            String secondaryActionUrl, String secondaryActionLabel) {
        if (recipients == null || recipients.isEmpty()) {
            log.warn("No recipients for appointment notification with subject: {}", subject);
            return;
        }
        for (User recipient : recipients) {
            try {
                // Skip emailing the sender (current actor) to avoid self-emails
                if (appointment != null) {
                    try {
                        Long recId = recipient.getId();
                        Long updId = appointment.getUpdatedBy() != null ? appointment.getUpdatedBy().getId() : null;
                        Long crtId = appointment.getCreatedBy() != null ? appointment.getCreatedBy().getId() : null;
                        boolean isSelf = (recId != null && updId != null && recId.equals(updId)) ||
                                         (recId != null && crtId != null && recId.equals(crtId));
                        if (isSelf) {
                            boolean isPrivileged = false;
                            try {
                                isPrivileged = recipient.getRoles() != null && recipient.getRoles().stream()
                                    .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE || r.getName() == RoleName.ROLE_DOCTOR || r.getName() == RoleName.ROLE_RH);
                            } catch (Exception ex) {
                                isPrivileged = false;
                            }
                            if (!isPrivileged) {
                                log.info("Skipping appointment email to sender (non-privileged self): username={}, email={}", recipient.getUsername(), recipient.getEmail());
                                continue;
                            }
                            // Allow self-email for medical staff and RH
                            log.debug("Allowing self-email for privileged recipient: username={}, roles={} ", recipient.getUsername(), recipient.getRoles());
                        }
                    } catch (Exception ex) {
                        log.warn("Failed to evaluate sender email skip for recipient {}: {}", recipient != null ? recipient.getId() : null, ex.getMessage());
                    }
                }
                if (recipient.getEmail() == null || recipient.getEmail().isBlank()) {
                    log.warn("Skipping email for recipient without email address: username={}", recipient.getUsername());
                    continue;
                }
                MimeMessage mimeMessage = mailSender.createMimeMessage();
                MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, true, "utf-8"); // true enables multipart for attachments

                Context context = new Context();
                context.setVariable("recipientName", getUserDisplayName(recipient));
                context.setVariable("appointment", appointment);
                context.setVariable("subject", subject);
                if (actionUrl != null && !actionUrl.isBlank()) {
                    context.setVariable("actionUrl", actionUrl);
                    context.setVariable("actionLabel", (actionLabel != null && !actionLabel.isBlank()) ? actionLabel : "Ouvrir l'application");
                }
                if (secondaryActionUrl != null && !secondaryActionUrl.isBlank()) {
                    context.setVariable("secondaryActionUrl", secondaryActionUrl);
                    context.setVariable("secondaryActionLabel", (secondaryActionLabel != null && !secondaryActionLabel.isBlank()) ? secondaryActionLabel : "Annuler");
                }

                String htmlContent = templateEngine.process(template, context);

                String toEmail = resolveRecipientEmail(recipient.getEmail());
                if (toEmail == null || toEmail.isBlank()) {
                    log.warn("Skipping email for recipient with unresolved email: username={}", recipient.getUsername());
                    continue;
                }
                helper.setTo(toEmail);
                helper.setSubject(subject);
                helper.setText(htmlContent, true);
                
                // Add logo as inline attachment
                try {
                    ClassPathResource logoResource = new ClassPathResource("static/images/logo_ohse_capital.png");
                    helper.addInline("logo", logoResource);
                } catch (Exception e) {
                    log.warn("Could not attach logo to email: {}", e.getMessage());
                }

                mailSender.send(mimeMessage);
                log.info("Appointment notification sent to {} with subject: {}", recipient.getEmail(), subject);
            } catch (MessagingException e) {
                log.error("Failed to send appointment notification to {} with subject: {}", recipient.getEmail(), subject, e);
            }
        }
    }

    // Overload with two CTAs and extra template variables
    @Override
    @Async
    public void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template,
                                            String actionUrl, String actionLabel,
                                            String secondaryActionUrl, String secondaryActionLabel,
                                            Map<String, Object> extraContext) {
        if (recipients == null || recipients.isEmpty()) {
            log.warn("No recipients for appointment notification with subject: {}", subject);
            return;
        }
        for (User recipient : recipients) {
            try {
                // Skip emailing the sender (current actor) to avoid self-emails
                if (appointment != null) {
                    try {
                        Long recId = recipient.getId();
                        Long updId = appointment.getUpdatedBy() != null ? appointment.getUpdatedBy().getId() : null;
                        Long crtId = appointment.getCreatedBy() != null ? appointment.getCreatedBy().getId() : null;
                        if ((recId != null && updId != null && recId.equals(updId)) ||
                            (recId != null && crtId != null && recId.equals(crtId))) {
                            log.info("Skipping appointment email to sender (self): username={}, email={}", recipient.getUsername(), recipient.getEmail());
                            continue;
                        }
                    } catch (Exception ex) {
                        log.warn("Failed to evaluate sender email skip for recipient {}: {}", recipient != null ? recipient.getId() : null, ex.getMessage());
                    }
                }
                if (recipient.getEmail() == null || recipient.getEmail().isBlank()) {
                    log.warn("Skipping email for recipient without email address: username={}", recipient.getUsername());
                    continue;
                }
                MimeMessage mimeMessage = mailSender.createMimeMessage();
                MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, true, "utf-8"); // true enables multipart for attachments

                Context context = new Context();
                context.setVariable("recipientName", getUserDisplayName(recipient));
                context.setVariable("appointment", appointment);
                context.setVariable("subject", subject);
                if (actionUrl != null && !actionUrl.isBlank()) {
                    context.setVariable("actionUrl", actionUrl);
                    context.setVariable("actionLabel", (actionLabel != null && !actionLabel.isBlank()) ? actionLabel : "Ouvrir l'application");
                }
                if (secondaryActionUrl != null && !secondaryActionUrl.isBlank()) {
                    context.setVariable("secondaryActionUrl", secondaryActionUrl);
                    context.setVariable("secondaryActionLabel", (secondaryActionLabel != null && !secondaryActionLabel.isBlank()) ? secondaryActionLabel : "Annuler");
                }
                if (extraContext != null && !extraContext.isEmpty()) {
                    for (Map.Entry<String, Object> entry : extraContext.entrySet()) {
                        if (entry.getKey() != null) {
                            context.setVariable(entry.getKey(), entry.getValue());
                        }
                    }
                }

                String htmlContent = templateEngine.process(template, context);

                String toEmail = resolveRecipientEmail(recipient.getEmail());
                if (toEmail == null || toEmail.isBlank()) {
                    log.warn("Skipping email for recipient with unresolved email: username={}", recipient.getUsername());
                    continue;
                }
                helper.setTo(toEmail);
                helper.setSubject(subject);
                helper.setText(htmlContent, true);
                
                // Add logo as inline attachment
                try {
                    ClassPathResource logoResource = new ClassPathResource("static/images/logo_ohse_capital.png");
                    helper.addInline("logo", logoResource);
                } catch (Exception e) {
                    log.warn("Could not attach logo to email: {}", e.getMessage());
                }

                mailSender.send(mimeMessage);
                log.info("Appointment notification (with extra context) sent to {} with subject: {}", recipient.getEmail(), subject);
            } catch (MessagingException e) {
                log.error("Failed to send appointment notification (with extra context) to {} with subject: {}", recipient.getEmail(), subject, e);
            }
        }
    }

    @Override
    @Async
    public void sendObligatoryAppointmentNotification(User user, Appointment appointment) {
        String subject = "Convocation à une visite médicale obligatoire";
        String content = String.format(
                "Bonjour %s,\n\nVous êtes convoqué(e) pour une visite médicale obligatoire le %s à %s.\n\nCordialement,\nLe Service de Santé au Travail",
                getUserDisplayName(user),
                appointment.getProposedDate().toLocalDate(),
                appointment.getProposedDate().toLocalTime()
        );
        sendEmail(user.getEmail(), subject, content);
    }

    @Override
    @Async
    public void sendSimpleEmail(String to, String subject, String text) {
        String resolved = resolveRecipientEmail(to);
        if (resolved == null || resolved.isBlank()) {
            log.warn("Skipping simple email: unresolved or empty recipient for to={}", to);
            return;
        }
        sendEmail(resolved, subject, text);
    }

    @Async
    protected void sendEmail(String to, String subject, String text) {
        try {
            MimeMessage mimeMessage = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");
            helper.setText(text, true);
            helper.setTo(to);
            helper.setSubject(subject);
            mailSender.send(mimeMessage);
            log.info("Email sent to {} with subject: {}", to, subject);
        } catch (MessagingException e) {
            log.error("Failed to send email to {} with subject: {}", to, subject, e);
        }
    }
}


// import com.oshapp.backend.model.Appointment;
// import com.oshapp.backend.model.User;
// import com.oshapp.backend.service.EmailService;
// import jakarta.mail.MessagingException;
// import jakarta.mail.internet.MimeMessage;
// import lombok.RequiredArgsConstructor;
// import lombok.extern.slf4j.Slf4j;
// import org.springframework.mail.javamail.JavaMailSender;
// import org.springframework.mail.javamail.MimeMessageHelper;
// import org.springframework.scheduling.annotation.Async;
// import org.springframework.stereotype.Service;
// import org.thymeleaf.TemplateEngine;
// import org.thymeleaf.context.Context;

// import java.util.List;

// @Service
// @Slf4j
// @RequiredArgsConstructor
// public class EmailServiceImpl implements EmailService {

//     private final JavaMailSender mailSender;
//     private final TemplateEngine templateEngine;

//     @Override
//     @Async
//     public void sendActivationEmail(User user, String token) {
//         try {
//             MimeMessage mimeMessage = mailSender.createMimeMessage();
//             MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

//             Context context = new Context();
//             context.setVariable("name", user.getFirstName());
//             context.setVariable("token", token);

//             String htmlContent = templateEngine.process("activation-email", context);

//             helper.setTo(user.getEmail());
//             helper.setSubject("Activez votre compte OSHapp");
//             helper.setText(htmlContent, true);

//             mailSender.send(mimeMessage);
//             log.info("Activation email sent to {}", user.getEmail());
//         } catch (MessagingException e) {
//             log.error("Failed to send activation email to {}", user.getEmail(), e);
//         }
//     }

//     @Override
//     @Async
//     public void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template) {
//         if (recipients == null || recipients.isEmpty()) {
//             log.warn("No recipients for appointment notification with subject: {}", subject);
//             return;
//         }
//         for (User recipient : recipients) {
//             try {
//                 MimeMessage mimeMessage = mailSender.createMimeMessage();
//                 MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

//                 Context context = new Context();
//                 context.setVariable("recipientName", recipient.getFirstName());
//                 context.setVariable("appointment", appointment);

//                 String htmlContent = templateEngine.process(template, context);

//                 helper.setTo(recipient.getEmail());
//                 helper.setSubject(subject);
//                 helper.setText(htmlContent, true);

//                 mailSender.send(mimeMessage);
//                 log.info("Appointment notification sent to {} with subject: {}", recipient.getEmail(), subject);
//             } catch (MessagingException e) {
//                 log.error("Failed to send appointment notification to {} with subject: {}", recipient.getEmail(), subject, e);
//             }
//         }
//     }

//     @Override
//     @Async
//     public void sendObligatoryAppointmentNotification(User user, Appointment appointment) {
//         String subject = "Convocation à une visite médicale obligatoire";
//         String content = String.format(
//                 "Bonjour %s,\n\nVous êtes convoqué(e) pour une visite médicale obligatoire le %s à %s.\n\nCordialement,\nLe Service de Santé au Travail",
//                 user.getFirstName(),
//                 appointment.getProposedDate().toLocalDate(),
//                 appointment.getProposedDate().toLocalTime()
//         );
//         sendEmail(user.getEmail(), subject, content);
//     }

//     @Async
//     protected void sendEmail(String to, String subject, String text) {
//         try {
//             MimeMessage mimeMessage = mailSender.createMimeMessage();
//             MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");
//             helper.setText(text, true);
//             helper.setTo(to);
//             helper.setSubject(subject);
//             mailSender.send(mimeMessage);
//             log.info("Email sent to {} with subject: {}", to, subject);
//         } catch (MessagingException e) {
//             log.error("Failed to send email to {} with subject: {}", to, subject, e);
//         }
//     }
// }


// import com.oshapp.backend.model.Appointment;
// import com.oshapp.backend.model.User;
// import com.oshapp.backend.service.EmailService;
// import jakarta.mail.MessagingException;
// import jakarta.mail.internet.MimeMessage;
// import lombok.RequiredArgsConstructor;
// import lombok.extern.slf4j.Slf4j;
// import org.springframework.mail.javamail.JavaMailSender;
// import org.springframework.mail.javamail.MimeMessageHelper;
// import org.springframework.scheduling.annotation.Async;
// import org.springframework.stereotype.Service;
// import org.thymeleaf.TemplateEngine;
// import org.thymeleaf.context.Context;

// import java.util.List;

// @Service
// @Slf4j
// @RequiredArgsConstructor
// public class EmailServiceImpl implements EmailService {

//     private final JavaMailSender mailSender;
//     private final TemplateEngine templateEngine;

//     @Override
//     @Async
//     public void sendActivationEmail(User user, String token) {
//         try {
//             MimeMessage mimeMessage = mailSender.createMimeMessage();
//             MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

//             Context context = new Context();
//             context.setVariable("name", user.getFirstName());
//             context.setVariable("token", token);

//             String htmlContent = templateEngine.process("activation-email", context);

//             helper.setTo(user.getEmail());
//             helper.setSubject("Activez votre compte OSHapp");
//             helper.setText(htmlContent, true);

//             mailSender.send(mimeMessage);
//             log.info("Activation email sent to {}", user.getEmail());
//         } catch (MessagingException e) {
//             log.error("Failed to send activation email to {}", user.getEmail(), e);
//         }
//     }

//     @Override
//     @Async
//     public void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template) {
//         if (recipients == null || recipients.isEmpty()) {
//             log.warn("No recipients for appointment notification with subject: {}", subject);
//             return;
//         }
//         for (User recipient : recipients) {
//             try {
//                 MimeMessage mimeMessage = mailSender.createMimeMessage();
//                 MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

//                 Context context = new Context();
//                 context.setVariable("recipientName", recipient.getFirstName());
//                 context.setVariable("appointment", appointment);

//                 String htmlContent = templateEngine.process(template, context);

//                 helper.setTo(recipient.getEmail());
//                 helper.setSubject(subject);
//                 helper.setText(htmlContent, true);

//                 mailSender.send(mimeMessage);
//                 log.info("Appointment notification sent to {} with subject: {}", recipient.getEmail(), subject);
//             } catch (MessagingException e) {
//                 log.error("Failed to send appointment notification to {} with subject: {}", recipient.getEmail(), subject, e);
//             }
//         }
//     }

//     @Override
//     @Async
//     public void sendObligatoryAppointmentNotification(User user, Appointment appointment) {
//         String subject = "Convocation à une visite médicale obligatoire";
//         String content = String.format(
//                 "Bonjour %s,\n\nVous êtes convoqué(e) pour une visite médicale obligatoire le %s à %s.\n\nCordialement,\nLe Service de Santé au Travail",
//                 user.getFirstName(),
//                 appointment.getProposedDate().toLocalDate(),
//                 appointment.getProposedDate().toLocalTime()
//         );
//         sendEmail(user.getEmail(), subject, content);
//     }

//     @Async
//     protected void sendEmail(String to, String subject, String text) {
//         try {
//             MimeMessage mimeMessage = mailSender.createMimeMessage();
//             MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");
//             helper.setText(text, true);
//             helper.setTo(to);
//             helper.setSubject(subject);
//             mailSender.send(mimeMessage);
//             log.info("Email sent to {} with subject: {}", to, subject);
//         } catch (MessagingException e) {
//             log.error("Failed to send email to {} with subject: {}", to, subject, e);
//         }
//     }
// }


// // import com.oshapp.backend.model.Appointment;
// // import com.oshapp.backend.model.User;
// // import com.oshapp.backend.service.EmailService;
// // import jakarta.mail.MessagingException;
// // import jakarta.mail.internet.MimeMessage;
// // import lombok.RequiredArgsConstructor;
// // import lombok.extern.slf4j.Slf4j;
// // import org.springframework.mail.javamail.JavaMailSender;
// // import org.springframework.mail.javamail.MimeMessageHelper;
// // import org.springframework.scheduling.annotation.Async;
// // import org.springframework.stereotype.Service;
// // import org.thymeleaf.TemplateEngine;
// // import org.thymeleaf.context.Context;

// // import java.util.List;

// // @Service
// // @Slf4j
// // @RequiredArgsConstructor
// // public class EmailServiceImpl implements EmailService {

// //     private final JavaMailSender mailSender;
// //     private final TemplateEngine templateEngine;

// //     @Override
// //     @Async
// //     public void sendActivationEmail(User user, String token) {
// //         try {
// //             MimeMessage mimeMessage = mailSender.createMimeMessage();
// //             MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

// //             Context context = new Context();
// //             context.setVariable("name", user.getFirstName());
// //             context.setVariable("token", token);

// //             String htmlContent = templateEngine.process("activation-email", context);

// //             helper.setTo(user.getEmail());
// //             helper.setSubject("Activez votre compte OSHapp");
// //             helper.setText(htmlContent, true);

// //             mailSender.send(mimeMessage);
// //             log.info("Activation email sent to {}", user.getEmail());
// //         } catch (MessagingException e) {
// //             log.error("Failed to send activation email to {}", user.getEmail(), e);
// //         }
// //     }

// //     @Override
// //     @Async
// //     public void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template) {
// //         if (recipients == null || recipients.isEmpty()) {
// //             log.warn("No recipients for appointment notification with subject: {}", subject);
// //             return;
// //         }
// //         for (User recipient : recipients) {
// //             try {
// //                 MimeMessage mimeMessage = mailSender.createMimeMessage();
// //                 MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

// //                 Context context = new Context();
// //                 context.setVariable("recipientName", recipient.getFirstName());
// //                 context.setVariable("appointment", appointment);

// //                 String htmlContent = templateEngine.process(template, context);

// //                 helper.setTo(recipient.getEmail());
// //                 helper.setSubject(subject);
// //                 helper.setText(htmlContent, true);

// //                 mailSender.send(mimeMessage);
// //                 log.info("Appointment notification sent to {} with subject: {}", recipient.getEmail(), subject);
// //             } catch (MessagingException e) {
// //                 log.error("Failed to send appointment notification to {} with subject: {}", recipient.getEmail(), subject, e);
// //             }
// //         }
// //     }

// //     @Override
// //     @Async
// //     public void sendObligatoryAppointmentNotification(User user, Appointment appointment) {
// //         String subject = "Convocation à une visite médicale obligatoire";
// //         String content = String.format(
// //                 "Bonjour %s,\n\nVous êtes convoqué(e) pour une visite médicale obligatoire le %s à %s.\n\nCordialement,\nLe Service de Santé au Travail",
// //                 user.getFirstName(),
// //                 appointment.getProposedDate().toLocalDate(),
// //                 appointment.getProposedDate().toLocalTime()
// //         );
// //         sendEmail(user.getEmail(), subject, content);
// //     }

// //     @Async
// //     protected void sendEmail(String to, String subject, String text) {
// //         try {
// //             MimeMessage mimeMessage = mailSender.createMimeMessage();
// //             MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");
// //             helper.setText(text, true);
// //             helper.setTo(to);
// //             helper.setSubject(subject);
// //             mailSender.send(mimeMessage);
// //             log.info("Email sent to {} with subject: {}", to, subject);
// //             log.warn("No recipients for appointment notification {}. Skipping email.", appointment.getId());
// //             return;
// //         }

// //         for (User recipient : recipients) {
// //             if (recipient.getEmail() != null && !recipient.getEmail().isEmpty()) {
// //                 try {
// //                     MimeMessage message = mailSender.createMimeMessage();
// //                     MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

// //                     helper.setTo(recipient.getEmail());
// //                     helper.setSubject(subject);

// //                     String emailContent = buildEmailBody(template, recipient, appointment);
// //                     helper.setText(emailContent, true); // true indicates HTML

// //                     mailSender.send(message);
// //                     log.info("Email sent to {} for appointment {}", recipient.getEmail(), appointment.getId());

// //                 } catch (MessagingException e) {
// //                     log.error("Failed to send email to {} for appointment {}", recipient.getEmail(), appointment.getId(), e);
// //                 }
// //             } else {
// //                 log.warn("User with ID {} has no email address. Skipping email notification.", recipient.getId());
// //             }
// //         }
// //     }
// //     private String buildEmailBody(String template, User recipient, Appointment appointment) {
// //         String firstName = (recipient.getEmployee() != null) ? recipient.getEmployee().getFirstName() : recipient.getUsername();

// //         // This can be expanded to use a proper HTML template engine like Thymeleaf
// //         return String.format(template,
// //                 firstName,
// //                 appointment.getId(),
// //                 appointment.getStatus(),
// //                 appointment.getRequestedDateEmployee(),
// //                 appointment.getMotif(),
// //                 appointment.getNotes(),
// //                 appointment.getScheduledTime() != null ? appointment.getScheduledTime() : "N/A"
// //         );
// //     }
// //     @Async
// //     @Override
// //     public void sendActivationEmail(User user, String token) {
// //         try {
// //             MimeMessage mimeMessage = mailSender.createMimeMessage();
// //             MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, "utf-8");

// //             Context context = new Context();
// //             context.setVariable("name", user.getFirstName());
// //             context.setVariable("token", token);

// //             String htmlContent = templateEngine.process("activation-email", context);

// //             helper.setTo(user.getEmail());
// //             helper.setSubject("Activez votre compte OSHapp");
// //             helper.setText(htmlContent, true);

// //             mailSender.send(mimeMessage);
// //             log.info("Activation email sent to {}", user.getEmail());
// //         } catch (MessagingException e) {
// //             log.error("Failed to send activation email to {}", user.getEmail(), e);
// //             // Optionally, rethrow as a custom exception
// //         }
// //     }

// //     @Override
// //     public void sendObligatoryAppointmentNotification(User user, Appointment appointment) {
// //         String subject = "Convocation à une visite médicale obligatoire";
// //         String content = String.format(
// //             "<html><body><h2>Convocation visite médicale obligatoire</h2>" +
// //             "<p>Bonjour %s,</p>" +
// //             "<p>Vous êtes convoqué(e) à une visite médicale obligatoire.</p>" +
// //             "<p>Type: %s</p>" +
// //             "<p>Veuillez confirmer votre présence via l'application.</p>" +
// //             "<p>Cordialement,<br/>L'équipe OHSE Capital</p></body></html>",
// //             (user.getEmployee() != null ? user.getEmployee().getFirstName() : user.getUsername()), 
// //             appointment.getType() != null ? appointment.getType().toString() : "Visite médicale");

// //         try {
// //             MimeMessage mimeMessage = mailSender.createMimeMessage();
// //             MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, true);

// //             helper.setTo(user.getEmail());
// //             helper.setSubject(subject);
// //             helper.setText(content, true);

// //             mailSender.send(mimeMessage);
// //             log.info("Obligatory appointment notification sent to {}", user.getEmail());

// //         } catch (MessagingException e) {
// //             log.error("Failed to send obligatory appointment notification to {}: {}", user.getEmail(), e.getMessage());
// //         }
// //     }
// // }

