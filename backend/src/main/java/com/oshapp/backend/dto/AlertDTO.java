package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class AlertDTO {
    private String id;
    private String title;
    private String description;
    private String date;
    private String severity; // e.g., 'WARNING', 'DANGER', 'INFO'
    private String link; // e.g., '/employee/123/certificates'
}
