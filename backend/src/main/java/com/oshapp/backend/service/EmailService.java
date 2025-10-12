package com.oshapp.backend.service;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;

import java.util.List;
import java.util.Map;


public interface EmailService {

    void sendActivationEmail(User user, String token);

    // Password reset email with 6-digit code
    void sendPasswordResetEmail(User user, String token);

    void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template);
    
    // Overload with optional CTA link support
    void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template,
                                     String actionUrl, String actionLabel);
    // Overload with two CTAs (primary + secondary)
    void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template,
                                     String actionUrl, String actionLabel,
                                     String secondaryActionUrl, String secondaryActionLabel);
    // Overload with two CTAs and extra template variables
    void sendAppointmentNotification(List<User> recipients, Appointment appointment, String subject, String template,
                                     String actionUrl, String actionLabel,
                                     String secondaryActionUrl, String secondaryActionLabel,
                                     Map<String, Object> extraContext);
    void sendObligatoryAppointmentNotification(User user, Appointment appointment);
    
    // Send a simple (raw) email with the given subject and HTML/text content
    void sendSimpleEmail(String to, String subject, String text);
        
}