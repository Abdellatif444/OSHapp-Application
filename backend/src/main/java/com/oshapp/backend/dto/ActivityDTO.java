package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ActivityDTO {
    private String id;
    private String title;
    private String description;
    private String timestamp;
    private String type; // e.g., 'NEW_EMPLOYEE', 'ACCIDENT_REPORT'
    private String link; // e.g., '/employee/456'
}
