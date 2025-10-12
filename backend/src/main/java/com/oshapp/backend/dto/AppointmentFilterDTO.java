package com.oshapp.backend.dto;

import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.model.enums.VisitMode;
import lombok.Data;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Getter
@Setter
public class AppointmentFilterDTO {
    // New multi-status filter list; preferred when provided
    private List<AppointmentStatus> statuses;
    private AppointmentStatus status;
    private AppointmentType type;
    private VisitMode visitMode;
    private Long employeeId;
    private LocalDateTime dateFrom;
    private LocalDateTime dateTo;
    private Integer page;
    private Integer size;
}
