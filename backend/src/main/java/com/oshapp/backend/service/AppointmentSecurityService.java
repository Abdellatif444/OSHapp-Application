package com.oshapp.backend.service;
import org.springframework.security.core.Authentication;

public interface AppointmentSecurityService {

    public boolean isEmployeeOnAppointment(Authentication authentication, Long appointmentId);
    public boolean canDeleteAppointment(Authentication authentication, Long appointmentId);
    public boolean canCommentOnAppointment(Authentication authentication, Long appointmentId);
} 