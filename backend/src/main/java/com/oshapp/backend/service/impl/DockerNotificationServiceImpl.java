package com.oshapp.backend.service.impl;

import lombok.extern.slf4j.Slf4j;

import java.util.List;

import org.springframework.stereotype.Service;
import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;

import com.oshapp.backend.service.DockerNotificationService;
@Service
@Slf4j
public class DockerNotificationServiceImpl implements DockerNotificationService {

    public void sendAppointmentNotification(List<User> users, Appointment appointment) {
        log.info("--- DOCKER NOTIFICATION ---");
        log.info("Sending notification for Appointment ID: {}", appointment.getId());
        log.info("Status: {}", appointment.getStatus());
                users.forEach(user -> {
            String recipientName = (user.getEmployee() != null && user.getEmployee().getFirstName() != null)
                    ? user.getEmployee().getFirstName()
                    : user.getUsername();
            log.info("Recipient: {} ({})", recipientName, user.getEmail());
        });
        log.info("---------------------------");
    }
}