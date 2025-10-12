package com.oshapp.backend.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class RescheduleRequestDTO {
    private LocalDateTime newDate;
    private String reason;
}
