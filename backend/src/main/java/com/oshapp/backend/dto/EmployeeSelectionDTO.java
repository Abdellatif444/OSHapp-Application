package com.oshapp.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO for employee selection in medical visit planning
 * Contains minimal info needed for dropdown selection
 */
@Data
@NoArgsConstructor  
@AllArgsConstructor
public class EmployeeSelectionDTO {
    private Long id;
    private String firstName;
    private String lastName;
    private String email;
    
    // Computed property for display
    public String getDisplayName() {
        if (firstName != null && lastName != null && !firstName.isBlank() && !lastName.isBlank()) {
            return firstName + " " + lastName + " – " + email;
        }
        return email;
    }
}
