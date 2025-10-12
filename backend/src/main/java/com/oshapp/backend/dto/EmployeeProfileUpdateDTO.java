package com.oshapp.backend.dto;

import lombok.Data;

import java.time.LocalDate;
import com.oshapp.backend.model.enums.Gender;

@Data
public class EmployeeProfileUpdateDTO {
    private String firstName;
    private String lastName;
    private String address;
    private String phoneNumber;
    private LocalDate dateOfBirth;
    private String placeOfBirth;
    private String nationality;
    private String cin;
    private String cnss;
    private String position;
    private String department;
    private LocalDate hireDate;
    private Long manager1Id;
    private Long manager2Id;
    private Gender gender;
}
