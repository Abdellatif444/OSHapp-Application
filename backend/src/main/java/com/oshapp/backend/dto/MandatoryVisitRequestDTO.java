package com.oshapp.backend.dto;

import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
public class MandatoryVisitRequestDTO {
    private List<Integer> employeeIds;
    private String visitType;
}
