package com.oshapp.backend.service;

import com.oshapp.backend.dto.NotificationResponseDTO;
import com.oshapp.backend.model.Appointment;

import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.NotificationType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;


public interface NotificationService {

    void sendAppointmentNotification(User user, Appointment appointment);
    void sendAppointmentStatusNotification(User user, Appointment appointment);
    void sendGeneralNotification(User user, String title, String message, NotificationType type);
    void sendGeneralNotification(User user, String title, String message, NotificationType type,
                                  String actionUrl, String relatedEntityType, Long relatedEntityId);
    void createNotification(String title, User user, String message);
    Page<NotificationResponseDTO> getUserNotifications(User user, Pageable pageable);
    List<NotificationResponseDTO> getUnreadNotifications(User user);
    Long getUnreadCount(User user);
    void markAsRead(Long notificationId, User user);
    void markAllAsRead(User user);
    void deleteNotification(Long notificationId, User user);
    void deleteAllNotifications();
} 