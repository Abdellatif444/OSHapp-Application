package com.oshapp.backend.service.impl;

import java.util.List;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.service.SmsService;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class SmsServiceImpl implements  SmsService{

    // In a real application, this would integrate with an SMS gateway like Twilio.
    public void sendAppointmentNotification(List<User> recipients, Appointment appointment, String messageTemplate) {
        log.info("--- SMS SIMULATION ---");
        for (User recipient : recipients) {
                        if (recipient.getEmployee() != null && recipient.getEmployee().getPhoneNumber() != null && !recipient.getEmployee().getPhoneNumber().isEmpty()) {
                                String message = String.format(messageTemplate, recipient.getEmployee().getFirstName(), appointment.getId(), appointment.getStatus());
                                log.info("Sending SMS to {}: {}", recipient.getEmployee().getPhoneNumber(), message);
            } else {
                log.warn("User {} has no phone number. Skipping SMS.", recipient.getId());
            }
        }
        log.info("----------------------");
    } 
}
