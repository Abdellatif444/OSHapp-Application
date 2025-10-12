package com.oshapp.backend.mapper;

import com.oshapp.backend.dto.EmployeeSummaryDTO;
import com.oshapp.backend.model.Employee;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface EmployeeMapper {

    @Mapping(target = "id", source = "employee.id")
    @Mapping(target = "fullName", source = "user.username")
    @Mapping(target = "email", source = "user.email")
    EmployeeSummaryDTO toSummaryDto(Employee employee);

}
