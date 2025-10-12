package com.oshapp.backend.service.impl;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import com.oshapp.backend.dto.NotificationResponseDTO;
import com.oshapp.backend.exception.ResourceNotFoundException;
import com.oshapp.backend.exception.UnauthorizedException;
import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.Notification;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.NotificationType;
import com.oshapp.backend.repository.NotificationRepository;
import com.oshapp.backend.service.NotificationService;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional
public class NotificationServiceImpl implements NotificationService{

    private final NotificationRepository notificationRepository;

    private String clamp(String s, int max) {
        if (s == null) return null;
        return s.length() <= max ? s : s.substring(0, Math.max(0, max - 3)) + "...";
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendAppointmentNotification(User user, Appointment appointment) {
        Notification notification = new Notification();
        notification.setUser(user);
        notification.setTitle(clamp("Nouveau rendez-vous", 255));
        notification.setMessage(clamp("Un nouveau rendez-vous a été créé.", 255));
        notification.setType(NotificationType.APPOINTMENT);
        notification.setRead(false);
        notification.setRelatedEntityType("APPOINTMENT");
        notification.setRelatedEntityId(appointment.getId());
        notification.setActionUrl(clamp("/appointment_action?id=" + appointment.getId() + "&action=view", 255));
        notification.setCreatedAt(LocalDateTime.now());
        try {
            notificationRepository.save(notification);
        } catch (Exception ex) {
            // Do not propagate to business transaction
            org.slf4j.LoggerFactory.getLogger(NotificationServiceImpl.class)
                .error("Failed to save appointment notification: {}", ex.getMessage());
        }
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendAppointmentStatusNotification(User user, Appointment appointment) {
        Notification notification = new Notification();
        notification.setUser(user);
        notification.setTitle(clamp("Statut mis à jour", 255));
        notification.setMessage(clamp("Statut mis à jour.", 255));
        notification.setType(NotificationType.APPOINTMENT);
        notification.setRead(false);
        notification.setRelatedEntityType("APPOINTMENT");
        notification.setRelatedEntityId(appointment.getId());
        notification.setActionUrl(clamp("/appointment_action?id=" + appointment.getId() + "&action=view", 255));
        notification.setCreatedAt(LocalDateTime.now());
        try {
            notificationRepository.save(notification);
        } catch (Exception ex) {
            org.slf4j.LoggerFactory.getLogger(NotificationServiceImpl.class)
                .error("Failed to save status notification: {}", ex.getMessage());
        }
    }

    @Override
    public void sendGeneralNotification(User user, String title, String message, NotificationType type) {
        // Delegate to the overload without deep-link info
        sendGeneralNotification(user, title, message, type, null, null, null);
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void sendGeneralNotification(User user, String title, String message, NotificationType type,
                                        String actionUrl, String relatedEntityType, Long relatedEntityId) {
        
        // Si c'est une notification liée à un rendez-vous, vérifier s'il existe déjà une notification pour ce rendez-vous
        if ("APPOINTMENT".equals(relatedEntityType) && relatedEntityId != null) {
            List<Notification> existingNotifications = notificationRepository.findByUserAndRelatedEntityTypeAndRelatedEntityId(
                    user, relatedEntityType, relatedEntityId);
            
            if (!existingNotifications.isEmpty()) {
                // Mettre à jour la notification existante la plus récente pour garantir le dynamisme
                Notification existingNotification = existingNotifications.get(0);
                existingNotification.setTitle(clamp(title, 255));
                existingNotification.setMessage(clamp(message, 255));
                existingNotification.setActionUrl(clamp(actionUrl, 255));
                existingNotification.setRead(false); // Marquer comme non lue pour attirer l'attention
                existingNotification.setCreatedAt(LocalDateTime.now()); // Mettre à jour la date pour le tri
                try {
                    notificationRepository.save(existingNotification);
                } catch (Exception ex) {
                    org.slf4j.LoggerFactory.getLogger(NotificationServiceImpl.class)
                        .error("Failed to update existing notification: {}", ex.getMessage());
                }
                return;
            }
        }
        
        // Créer une nouvelle notification si aucune n'existe pour ce rendez-vous
        Notification notification = new Notification();
        notification.setUser(user);
        notification.setTitle(clamp(title, 255));
        notification.setMessage(clamp(message, 255));
        notification.setType(type);
        notification.setRead(false);
        notification.setRelatedEntityType(relatedEntityType);
        notification.setRelatedEntityId(relatedEntityId);
        notification.setActionUrl(clamp(actionUrl, 255));
        notification.setCreatedAt(LocalDateTime.now());
        try {
            notificationRepository.save(notification);
        } catch (Exception ex) {
            org.slf4j.LoggerFactory.getLogger(NotificationServiceImpl.class)
                .error("Failed to save general notification: {}", ex.getMessage());
        }
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void createNotification(String title, User user, String message) {
        Notification notification = new Notification();
        notification.setTitle(clamp(title, 255));
        notification.setUser(user);
        notification.setMessage(clamp(message, 255));
        notification.setType(NotificationType.INFO);
        notification.setRead(false);
        notification.setCreatedAt(LocalDateTime.now());
        try {
            notificationRepository.save(notification);
        } catch (Exception ex) {
            org.slf4j.LoggerFactory.getLogger(NotificationServiceImpl.class)
                .error("Failed to save info notification: {}", ex.getMessage());
        }
    }

    @Override
    public Page<NotificationResponseDTO> getUserNotifications(User user, Pageable pageable) {
        return notificationRepository.findByUserOrderByCreatedAtDesc(user, pageable).map(this::mapToResponseDTO);
    }

    @Override
    public List<NotificationResponseDTO> getUnreadNotifications(User user) {
        return notificationRepository.findByUserAndReadFalseOrderByCreatedAtDesc(user).stream().map(this::mapToResponseDTO).collect(Collectors.toList());
    }

    @Override
    public Long getUnreadCount(User user) {
        return notificationRepository.countByUserAndReadFalse(user);
    }

    @Override
    public void markAsRead(Long notificationId, User user) {
        Notification notification = notificationRepository.findById(notificationId).orElseThrow(() -> new ResourceNotFoundException("Notification not found"));
        if (!notification.getUser().getId().equals(user.getId())) {
            throw new UnauthorizedException("You can only mark your own notifications as read");
        }
        notification.setRead(true);
        notificationRepository.save(notification);
    }

    @Override
    public void markAllAsRead(User user) {
        List<Notification> unreadNotifications = notificationRepository.findByUserAndReadFalseOrderByCreatedAtDesc(user);
        unreadNotifications.forEach(n -> n.setRead(true));
        notificationRepository.saveAll(unreadNotifications);
    }

    @Override
    public void deleteNotification(Long notificationId, User user) {
        Notification notification = notificationRepository.findById(notificationId).orElseThrow(() -> new ResourceNotFoundException("Notification not found"));
        if (!notification.getUser().getId().equals(user.getId())) {
            throw new UnauthorizedException("You can only delete your own notifications");
        }
        notificationRepository.delete(notification);
    }

    private NotificationResponseDTO mapToResponseDTO(Notification notification) {
        NotificationResponseDTO dto = new NotificationResponseDTO();
        dto.setId(notification.getId());
        dto.setTitle(notification.getTitle());
        dto.setMessage(notification.getMessage());
        dto.setType(notification.getType());
        dto.setRead(notification.isRead());
        dto.setRelatedEntityType(notification.getRelatedEntityType());
        dto.setRelatedEntityId(notification.getRelatedEntityId());
        dto.setActionUrl(notification.getActionUrl());
        dto.setCreatedAt(notification.getCreatedAt());
        return dto;
    }

    @Override
    public void deleteAllNotifications() {
        notificationRepository.deleteAll();
    }
}
