package com.oshapp.backend.dto;

import com.oshapp.backend.model.Employee;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import com.oshapp.backend.model.enums.Gender;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.Collections;

@Data
@NoArgsConstructor
public class EmployeeProfileDTO {

    private Long id;
    private String firstName;
    private String lastName;
    private String email;
    private String position;
    private String department;
    private String phoneNumber;
    private LocalDate hireDate;
    private boolean profileCompleted;
    private Gender gender;

    private String address;
    private String employeeId;
    private String city;
    private String zipCode;
    private String country;
    private LocalDate birthDate;
    private String birthPlace;
    private String nationality;
    private String cin;
    private String cnss;
    private boolean enabled;
    private Set<String> roles;

    public EmployeeProfileDTO(Employee employee, boolean enabled) {
        this(employee);
        this.enabled = enabled;
    }

    public EmployeeProfileDTO(Employee employee) {
        this.id = employee.getId();
        this.firstName = employee.getFirstName();
        this.lastName = employee.getLastName();
        if (employee.getUser() != null) {
            this.email = employee.getUser().getEmail();
            if (employee.getUser().getRoles() != null) {
                this.roles = employee.getUser().getRoles().stream()
                        .map(role -> role.getName().name())
                        .collect(Collectors.toSet());
            } else {
                this.roles = Collections.emptySet();
            }
        } else {
            this.roles = Collections.emptySet();
        }
        this.position = employee.getPosition();
        this.department = employee.getDepartment();
        this.phoneNumber = employee.getPhoneNumber();
        this.hireDate = employee.getHireDate();
        this.profileCompleted = employee.isProfileCompleted();
        this.gender = employee.getGender();

        // Map new fields
        this.address = employee.getAddress();
        this.employeeId = employee.getEmployeeId();
        this.city = employee.getCity();
        this.zipCode = employee.getZipCode();
        this.country = employee.getCountry();
        this.birthDate = employee.getBirthDate();
        this.birthPlace = employee.getBirthPlace();
        this.nationality = employee.getNationality();
        this.cin = employee.getCin();
        this.cnss = employee.getCnss();
    }
}
