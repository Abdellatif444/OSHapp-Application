package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class StatsDTO {
    private long pendingAppointments;
    private long proposedAppointments;
    private long confirmedAppointments;
    private long completedConsultations;
}
