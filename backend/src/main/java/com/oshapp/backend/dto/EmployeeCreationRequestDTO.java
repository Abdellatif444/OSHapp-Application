package com.oshapp.backend.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;
import com.oshapp.backend.model.enums.Gender;

@Getter
@Setter
public class EmployeeCreationRequestDTO {
    private Long userId;
    private String firstName;
    private String lastName;
    private String email;
    private String position;
    private String department;
    private LocalDate hireDate;
    private LocalDate dateOfBirth;
    private Long manager1Id;
    private Long manager2Id;
    private String cin;
    private String cnss;
    private String phoneNumber;
    private String placeOfBirth;
    private String address;
    private String nationality;
    private String city;
    private String zipCode;
    private String country;
    private Gender gender;
    //private LocalDate dateOfBirth;
}
