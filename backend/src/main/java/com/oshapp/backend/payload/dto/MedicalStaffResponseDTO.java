package com.oshapp.backend.payload.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class MedicalStaffResponseDTO {

    private boolean confirm;

    private LocalDateTime proposedDate;

    private String reason;
}
