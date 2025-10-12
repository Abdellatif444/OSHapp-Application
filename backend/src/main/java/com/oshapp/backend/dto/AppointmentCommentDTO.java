package com.oshapp.backend.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
public class AppointmentCommentDTO {
    private Long id;
    private String comment;
    private String authorName;
    private LocalDateTime createdAt;
}
