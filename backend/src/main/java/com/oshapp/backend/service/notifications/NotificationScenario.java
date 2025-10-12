package com.oshapp.backend.service.notifications;

/**
 * Essential notification scenarios matching the exact medical appointment workflow.
 * Covers: request → propose/confirm → employee response → final status
 */
public enum NotificationScenario {
    // Core 4-step workflow
    APPOINTMENT_REQUESTED,           // 1. Employee creates request
    APPOINTMENT_SLOT_PROPOSED,       // 2. Medical staff proposes new slot  
    APPOINTMENT_CONFIRMED,           // 3. Confirmed (by medical staff or employee)
    APPOINTMENT_CANCELLED,           // 4. Cancelled (by employee)
    MEDICAL_VISIT_PLANNED,           // 5. Medical staff plans visit (nouveau scénario)
    MEDICAL_VISIT_CONFIRMED_BY_EMPLOYEE,  // 6. Employee confirms medical visit
    MEDICAL_VISIT_CANCELLED;         // 7. Employee cancels medical visit

    /**
     * Convert legacy string scenario to modern enum value.
     * Maps all legacy scenarios to the 4 core scenarios.
     */
    public static NotificationScenario fromString(String value) {
        if (value == null) return null;
        String key = value.trim().toUpperCase();
        
        // Map all legacy scenarios to core scenarios
        switch (key) {
            // Request scenarios
            case "APPOINTMENT_REQUESTED":
            case "CREATION":
                return APPOINTMENT_REQUESTED;
                
            // Proposal scenarios  
            case "APPOINTMENT_SLOT_PROPOSED":
                return APPOINTMENT_SLOT_PROPOSED;
                
            // Confirmation scenarios (all variations map to single CONFIRMED)
            case "APPOINTMENT_CONFIRMED":
                return APPOINTMENT_CONFIRMED;
                
            // Cancellation scenarios
            case "APPOINTMENT_CANCELLED":
                return APPOINTMENT_CANCELLED;
                
            // Medical visit planning scenarios
            case "MEDICAL_VISIT_PLANNED":
                return MEDICAL_VISIT_PLANNED;
                
            case "MEDICAL_VISIT_CONFIRMED_BY_EMPLOYEE":
                return MEDICAL_VISIT_CONFIRMED_BY_EMPLOYEE;
                
            case "MEDICAL_VISIT_CANCELLED":
                return MEDICAL_VISIT_CANCELLED;
                
            // Fallback to direct enum lookup
            default:
                try {
                    return NotificationScenario.valueOf(key);
                } catch (IllegalArgumentException ex) {
                    // Unknown scenario - default to CONFIRMED for safety
                    return APPOINTMENT_CONFIRMED;
                }
        }
    }

    /**
     * Extract actor context from scenario string.
     * Used internally to preserve actor information for notification strategies.
     */
    public static NotificationActor extractActor(String scenario) {
        if (scenario == null) return null;
        String key = scenario.trim().toUpperCase();
        
        // Extract actor from legacy scenario names for backward compatibility
        if (key.contains("_BY_EMPLOYEE") || key.contains("PROPOSAL_ACCEPTED")) {
            return NotificationActor.EMPLOYEE;
        }
        if (key.contains("_RH") || key.contains("RH_")) {
            return NotificationActor.RH;
        }
        if (key.contains("MEDICAL_STAFF") || key.contains("OBLIGATORY")||key.contains("SLOT_PROPOSED")||key.contains("MEDICAL_VISIT_PLANNED")) {
            return NotificationActor.MEDICAL_STAFF;
        }
        if (key.equals("CREATION")) {
            return NotificationActor.SYSTEM;
        }
        
        return null; // Actor will be determined from context
    }
}
