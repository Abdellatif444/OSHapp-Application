package com.oshapp.backend.service.notifications.policy;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.RoleName;
import org.springframework.stereotype.Component;

@Component
public class NotificationVisibilityPolicy {

    public boolean isRh(User user) {
        try {
            return user != null && user.getRoles() != null && user.getRoles().stream().anyMatch(r -> r.getName() == RoleName.ROLE_RH);
        } catch (Exception e) {
            return false;
        }
    }

    public boolean isManagerForAppointment(User user, Appointment appointment) {
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

    public boolean isMedicalStaff(User user) {
        try {
            return user != null && user.getRoles() != null && user.getRoles().stream()
                    .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE || r.getName() == RoleName.ROLE_DOCTOR);
        } catch (Exception e) {
            return false;
        }
    }

    public boolean shouldHideEmailCta(User user, Appointment appointment) {
        return isRh(user) || isManagerForAppointment(user, appointment);
    }

    public boolean canSeeMotif(User user, Appointment appointment) {
        // RH and managers cannot see medical motif.
        return !isRh(user) && !isManagerForAppointment(user, appointment);
    }

    public boolean canSeeNotes(User user, Appointment appointment) {
        // Same as motif for now; keep a separate method for future rule divergence.
        return !isRh(user) && !isManagerForAppointment(user, appointment);
    }

    public boolean canSeeCancellationReason(User user, Appointment appointment) {
        // Employee and medical staff can see the reason; RH/managers cannot.
        boolean isEmployeeRecipient = appointment != null && appointment.getEmployee() != null && appointment.getEmployee().getUser() != null
                && user != null && appointment.getEmployee().getUser().getId() != null
                && appointment.getEmployee().getUser().getId().equals(user.getId());
        return isEmployeeRecipient || isMedicalStaff(user);
    }
}
