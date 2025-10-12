package com.oshapp.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = "medical_certificates")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class MedicalCertificate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "employee_id", nullable = false)
    private Employee employee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "doctor_id")
    private User doctor; // Assuming doctors are Users

    @Column(nullable = false)
    private String certificateType; // e.g., "APTITUDE", "INAPTITUDE_TEMPORARY", "INAPTITUDE_PERMANENT"

    @Column(nullable = false)
    private LocalDate issueDate;

    @Column
    private LocalDate expirationDate;

    @Column(columnDefinition = "TEXT")
    private String comments;

    @Column
    private String filePath; // Path to the document in MinIO
}
