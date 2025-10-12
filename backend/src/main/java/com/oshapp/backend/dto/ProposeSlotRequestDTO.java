package com.oshapp.backend.dto;

import lombok.Data;

import java.time.LocalDateTime;
import com.oshapp.backend.model.enums.VisitMode;

@Data
public class ProposeSlotRequestDTO {
    private LocalDateTime proposedDate;
    private String comments;
    private VisitMode visitMode; // IN_PERSON or REMOTE
}
