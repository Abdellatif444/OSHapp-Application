package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class HseDashboardDTO {
    private HseStatsDTO stats;
    private List<AlertDTO> alerts;
    private List<ActivityDTO> activities;
}
