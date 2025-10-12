package com.oshapp.backend.service.security;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.repository.AppointmentRepository;
import com.oshapp.backend.repository.UserRepository;
import com.oshapp.backend.service.AppointmentSecurityService;
import com.oshapp.backend.model.enums.AppointmentStatus;

import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

@Service("appointmentSecurityService")
@RequiredArgsConstructor
public class AppointmentSecurityServiceImpl implements AppointmentSecurityService {

    private final AppointmentRepository appointmentRepository;
    private final UserRepository userRepository;

    public boolean isEmployeeOnAppointment(Authentication authentication, Long appointmentId) {
        String username = authentication.getName();
        User user = userRepository.findByUsernameOrEmail(username, username).orElse(null);
        if (user == null) {
            return false;
        }

        Appointment appointment = appointmentRepository.findById(appointmentId).orElse(null);
        if (appointment == null || appointment.getEmployee() == null || appointment.getEmployee().getUser() == null) {
            return false;
        }

        return appointment.getEmployee().getUser().getId().equals(user.getId());
    }

    public boolean canCommentOnAppointment(Authentication authentication, Long appointmentId) {
        String username = authentication.getName();
        User user = userRepository.findByUsernameOrEmail(username, username).orElse(null);
        if (user == null) {
            return false;
        }

        // Check for roles that can always comment
        if (authentication.getAuthorities().stream().anyMatch(a -> 
                a.getAuthority().equals("ROLE_ADMIN") ||
                a.getAuthority().equals("ROLE_RH") ||
                a.getAuthority().equals("ROLE_NURSE") ||
                a.getAuthority().equals("ROLE_DOCTOR"))) {
            return true;
        }

        Appointment appointment = appointmentRepository.findById(appointmentId).orElse(null);
        if (appointment == null || appointment.getEmployee() == null) {
            return false;
        }

        // Check if the user is the employee on the appointment
        if (appointment.getEmployee().getUser() != null && appointment.getEmployee().getUser().getId().equals(user.getId())) {
            return true;
        }

        // Check if the user is the N+1 manager
        if (appointment.getEmployee().getManager1() != null && appointment.getEmployee().getManager1().getUser() != null && appointment.getEmployee().getManager1().getUser().getId().equals(user.getId())) {
            return true;
        }

        // Check if the user is the N+2 manager
        if (appointment.getEmployee().getManager2() != null && appointment.getEmployee().getManager2().getUser() != null && appointment.getEmployee().getManager2().getUser().getId().equals(user.getId())) {
            return true;
        }

        return false;
    }

    // Allow an employee to delete their own CANCELLED appointment
    public boolean canDeleteAppointment(Authentication authentication, Long appointmentId) {
        String username = authentication.getName();
        User user = userRepository.findByUsernameOrEmail(username, username).orElse(null);
        if (user == null) {
            return false;
        }

        Appointment appointment = appointmentRepository.findById(appointmentId).orElse(null);
        if (appointment == null) {
            return false;
        }

        // Only allow deletion when status is CANCELLED
        if (appointment.getStatus() != AppointmentStatus.CANCELLED) {
            return false;
        }

        // Employee who owns the appointment can delete
        return appointment.getEmployee() != null
                && appointment.getEmployee().getUser() != null
                && appointment.getEmployee().getUser().getId().equals(user.getId());
    }
}
