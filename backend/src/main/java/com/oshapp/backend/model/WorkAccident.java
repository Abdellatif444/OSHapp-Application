package com.oshapp.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "work_accidents")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class WorkAccident {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @Column(nullable = false)
    private LocalDateTime accidentDate;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column
    private AccidentSeverity severity;

    @Enumerated(EnumType.STRING)
    @Column
    private AccidentStatus status;

    @Column
    private String reportFilePath; // Path to the accident report in MinIO

    public enum AccidentStatus {
        REPORTED, INVESTIGATING, CLOSED
    }

    public enum AccidentSeverity {
        MINOR, MODERATE, SEVERE
    }
}
