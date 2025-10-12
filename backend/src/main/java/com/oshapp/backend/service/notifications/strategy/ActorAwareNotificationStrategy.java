package com.oshapp.backend.service.notifications.strategy;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.service.notifications.NotificationActor;

/**
 * Extension of NotificationStrategy that supports actor context.
 * Used for consolidated scenarios where the same event can be triggered by different actors.
 */
public interface ActorAwareNotificationStrategy extends NotificationStrategy {
    
    /**
     * Send notification with actor context.
     * 
     * @param user The recipient user
     * @param appointment The appointment
     * @param extraMessage Optional extra message to override default
     * @param actor The actor who initiated this notification scenario (can be null)
     */
    void notify(User user, Appointment appointment, String extraMessage, NotificationActor actor);
}
