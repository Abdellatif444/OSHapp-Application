package com.oshapp.backend.dto;

import com.oshapp.backend.model.WorkAccident;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class WorkAccidentDTO {
    private Long id;
    private String employeeName;
    private LocalDateTime accidentDate;
    private String description;
    private String severity;
    private String status;
    private String reportFilePath;

    public WorkAccidentDTO(WorkAccident accident) {
        this.id = accident.getId();
        this.employeeName = accident.getEmployee().getFirstName() + " " + accident.getEmployee().getLastName();
        this.accidentDate = accident.getAccidentDate();
        this.description = accident.getDescription();
        this.severity = accident.getSeverity() != null ? accident.getSeverity().name() : null;
        this.status = accident.getStatus() != null ? accident.getStatus().name() : null;
        this.reportFilePath = accident.getReportFilePath();
    }
}
