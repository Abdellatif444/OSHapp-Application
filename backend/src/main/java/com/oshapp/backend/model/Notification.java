package com.oshapp.backend.model;

import com.oshapp.backend.model.enums.*;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String title;
    private String message;
    private java.time.LocalDateTime createdAt;
    private boolean read;
    @Enumerated(EnumType.STRING)
    private NotificationType type;
    private String relatedEntityType;
    private Long relatedEntityId;
    private String actionUrl;
    @ManyToOne
    @JoinColumn(name = "user_id")
    private User user;

    public String getActionUrl() {
        return actionUrl;
    }

    public void setActionUrl(String actionUrl) {
        this.actionUrl = actionUrl;
    }
} 