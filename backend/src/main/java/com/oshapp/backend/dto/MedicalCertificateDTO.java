package com.oshapp.backend.dto;

import com.oshapp.backend.model.SickLeaveCertificate;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
public class MedicalCertificateDTO {
    private Long id;
    private String employeeName;
    private LocalDate startDate;
    private LocalDate endDate;
    private String reason;
    private String status;

        public MedicalCertificateDTO(SickLeaveCertificate certificate) {
        this.id = certificate.getId();
        this.employeeName = certificate.getEmployee().getFirstName() + " " + certificate.getEmployee().getLastName();
        this.startDate = certificate.getStartDate();
        this.endDate = certificate.getEndDate();
        this.reason = certificate.getReason();
                this.status = certificate.getStatus() != null ? certificate.getStatus().name() : null;
    }
}
