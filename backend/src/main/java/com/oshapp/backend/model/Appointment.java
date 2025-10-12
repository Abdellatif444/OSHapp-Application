package com.oshapp.backend.model;

import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.model.enums.Priority;
import com.oshapp.backend.model.enums.VisitMode;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;

import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.ToString;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import org.hibernate.annotations.NotFound;
import org.hibernate.annotations.NotFoundAction;
import java.time.LocalDateTime;


import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "appointments")
@Getter
@Setter
@ToString(exclude = {"employee", "nurse", "doctor", "comments", "createdBy", "updatedBy"})
@EqualsAndHashCode(exclude = {"employee", "nurse", "doctor", "comments", "createdBy", "updatedBy"})
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Appointment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "nurse_id")
    @NotFound(action = NotFoundAction.IGNORE)
    private User nurse;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "doctor_id")
    @NotFound(action = NotFoundAction.IGNORE)
    private User doctor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AppointmentType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AppointmentStatus status;

    @Enumerated(EnumType.STRING)
    private VisitMode visitMode;

    private LocalDateTime requestedDateEmployee;

    private String motif;

    private String notes; 

    // Nouveau scénario: planification par service médical
    private String medicalInstructions; // Consignes/remarques du service médical
    
    private String medicalServicePhone; // Numéro de téléphone du service médical

    private LocalDateTime proposedDate;

    private LocalDateTime scheduledTime;

    private String reason;

    private boolean isObligatory;

    @Enumerated(EnumType.STRING)
    private Priority priority;

    private boolean flexibleSchedule;

    @OneToMany(mappedBy = "appointment", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<AppointmentComment> comments = new ArrayList<>();

    private boolean isUrgent;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "appointment_preferred_time_slots", joinColumns = @JoinColumn(name = "appointment_id"))
    @Column(name = "time_slot")
    private List<String> preferredTimeSlots;

    private String cancellationReason;

    private String rescheduleReason;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by")
    @NotFound(action = NotFoundAction.IGNORE)
    private User createdBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "updated_by")
    @NotFound(action = NotFoundAction.IGNORE)
    private User updatedBy;

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "appointment_notification_channels", joinColumns = @JoinColumn(name = "appointment_id"))
    @Column(name = "channel")
    private List<String> notificationChannels;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "appointment_proposed_date_slots", joinColumns = @JoinColumn(name = "appointment_id"))
    @Column(name = "proposed_date_slot")
    private List<LocalDateTime> proposedDateSlots;

    // Ensure comments is never null at access time
    public List<AppointmentComment> getComments() {
        if (this.comments == null) {
            this.comments = new ArrayList<>();
        }
        return this.comments;
    }

    // Normalize null assignments to an empty list to keep invariant
    public void setComments(List<AppointmentComment> comments) {
        this.comments = (comments != null) ? comments : new ArrayList<>();
    }

}
