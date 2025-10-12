package com.oshapp.backend.service.notifications;

/**
 * Represents the actor who initiated a notification scenario.
 * This allows us to consolidate similar scenarios (e.g., confirmations) 
 * while preserving context about who performed the action.
 */
public enum NotificationActor {
    EMPLOYEE,
    MEDICAL_STAFF, 
    RH,
    SYSTEM
}
