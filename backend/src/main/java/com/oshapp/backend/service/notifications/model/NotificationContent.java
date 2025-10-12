package com.oshapp.backend.service.notifications.model;

import com.oshapp.backend.model.enums.NotificationType;
import lombok.Builder;
import lombok.Getter;

import java.util.Map;

@Getter
@Builder
public class NotificationContent {
    private final String title;
    private final String message;
    @Builder.Default
    private final NotificationType notificationType = NotificationType.APPOINTMENT;

    private final String cta1Url;
    private final String cta1Label;

    private final String cta2Url;
    private final String cta2Label;

    private final String emailTemplate;
    private final String emailSubject;

    private final Map<String, Object> extraContext;
}
