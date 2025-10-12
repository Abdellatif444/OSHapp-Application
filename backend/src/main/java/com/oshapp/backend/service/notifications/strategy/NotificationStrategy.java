package com.oshapp.backend.service.notifications.strategy;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.service.notifications.NotificationScenario;

public interface NotificationStrategy {
    boolean supports(NotificationScenario scenario);
    void notify(User user, Appointment appointment, String extraMessage);
}
