package com.oshapp.backend.model;

import com.oshapp.backend.model.enums.AppointmentStatus;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Embeddable
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WorkflowStep {

    @Enumerated(EnumType.STRING)
    private AppointmentStatus status;

    private LocalDateTime timestamp;

    private Long actorId;

    private String actorRole;

    private String comments;
}
