package com.oshapp.backend.dto;

import com.oshapp.backend.model.MedicalCertificate;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
public class UploadedMedicalCertificateDTO {
    private Long id;
    private Long employeeId;
    private String employeeName;
    private String certificateType;
    private LocalDate issueDate;
    private LocalDate expirationDate;
    private String filePath;
    private String doctorName;
    private String comments;

    public UploadedMedicalCertificateDTO(MedicalCertificate mc) {
        this.id = mc.getId();
        this.employeeId = mc.getEmployee() != null ? mc.getEmployee().getId() : null;
        this.employeeName = mc.getEmployee() != null
                ? (mc.getEmployee().getFirstName() + " " + mc.getEmployee().getLastName())
                : null;
        this.certificateType = mc.getCertificateType();
        this.issueDate = mc.getIssueDate();
        this.expirationDate = mc.getExpirationDate();
        this.filePath = mc.getFilePath();
        // Avoid accessing lazy-loaded association outside of a transaction
        this.doctorName = null; // TODO: expose doctor info via a dedicated projection if needed
        this.comments = mc.getComments();
    }
}
