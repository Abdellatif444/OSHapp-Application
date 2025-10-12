package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.User;
import com.oshapp.backend.security.UserPrincipal;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Set;
import java.util.stream.Collectors;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserResponseDTO {

    public UserResponseDTO(UserPrincipal userPrincipal, Employee employee) {
        this.id = userPrincipal.getId();
        this.username = userPrincipal.getUsername();
        this.email = userPrincipal.getEmail();
        this.roles = userPrincipal.getAuthorities().stream()
                .map(auth -> auth.getAuthority())
                .collect(Collectors.toSet());
        this.enabled = userPrincipal.isEnabled();
        this.active = userPrincipal.isEnabled(); // Assuming active is the same as enabled for now
        if (employee != null) {
            this.employee = new EmployeeProfileDTO(employee, userPrincipal.isEnabled());
        }
    }
    private Long id;
    private String username;
    private String email;
    private Set<String> roles;
    private EmployeeProfileDTO employee;
    private boolean active;
    private boolean enabled;
    private Long n1;
    private Long n2;
}