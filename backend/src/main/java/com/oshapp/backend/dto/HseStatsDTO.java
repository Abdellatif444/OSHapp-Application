package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class HseStatsDTO {
    private long totalIncidents;
    private long totalAccidents;
    private long riskAnalyses;    // Using INVESTIGATING accidents as proxy for analyses in progress
    private long completedTasks;  // Using CLOSED accidents as proxy for completed tasks
}
