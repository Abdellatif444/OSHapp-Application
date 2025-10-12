package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class MedicalFitnessDTO {
    private String status;
    private LocalDate nextVisitDate;
    private String doctorName;
}
