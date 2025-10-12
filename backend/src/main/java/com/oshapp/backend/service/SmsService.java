package com.oshapp.backend.service;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;


import java.util.List;

public interface SmsService {
    // In a real application, this would integrate with an SMS gateway like Twilio.
    void sendAppointmentNotification(List<User> recipients, Appointment appointment, String messageTemplate);
}
 