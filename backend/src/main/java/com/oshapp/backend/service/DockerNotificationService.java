package com.oshapp.backend.service;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import java.util.List;

public interface DockerNotificationService{
    public void sendAppointmentNotification(List<User> users, Appointment appointment);
}