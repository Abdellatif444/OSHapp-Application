package com.oshapp.backend.controller;

import com.oshapp.backend.dto.EmployeeCreationRequestDTO;
import com.oshapp.backend.dto.EmployeeProfileDTO;
import com.oshapp.backend.dto.EmployeeStatsDTO;
import com.oshapp.backend.dto.UserResponseDTO;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.security.UserPrincipal;
import com.oshapp.backend.service.EmployeeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.annotation.*;

import com.oshapp.backend.dto.MedicalFitnessDTO;
import com.oshapp.backend.repository.EmployeeRepository;
import com.oshapp.backend.repository.AppointmentRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository;
    private final AppointmentRepository appointmentRepository;

    @GetMapping
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasRole('ROLE_RH') or hasRole('ROLE_NURSE') or hasRole('ROLE_DOCTOR')")
    public ResponseEntity<List<EmployeeProfileDTO>> getAllEmployees() {
        List<Employee> employees = employeeService.findAll();
        List<EmployeeProfileDTO> employeeDTOs = employees.stream()
                .map(EmployeeProfileDTO::new)
                .collect(Collectors.toList());
        return ResponseEntity.ok(employeeDTOs);
    }

    @GetMapping("/for-medical-planning")
    @PreAuthorize("hasRole('ROLE_NURSE') or hasRole('ROLE_DOCTOR')")
    public ResponseEntity<List<EmployeeProfileDTO>> getEmployeesForMedicalPlanning() {
        List<Employee> employees = employeeService.findAll();
        List<EmployeeProfileDTO> employeeDTOs = employees.stream()
                .map(EmployeeProfileDTO::new)
                .collect(Collectors.toList());
        return ResponseEntity.ok(employeeDTOs);
    }

    @GetMapping("/subordinates")
    public ResponseEntity<List<EmployeeProfileDTO>> getSubordinates(Authentication authentication) {
        String managerEmail = authentication.getName();
        List<Employee> subordinates = employeeService.findSubordinatesByManagerEmail(managerEmail);
        List<EmployeeProfileDTO> subordinateDTOs = subordinates.stream()
                .map(EmployeeProfileDTO::new)
                .collect(Collectors.toList());
        return ResponseEntity.ok(subordinateDTOs);
    }

    @GetMapping("/profile")
    public ResponseEntity<UserResponseDTO> getCurrentEmployeeProfileRedirect(Authentication authentication) {
        return getCurrentEmployeeProfile(authentication);
    }

    @GetMapping("/profile/me")
    public ResponseEntity<UserResponseDTO> getCurrentEmployeeProfile(Authentication authentication) {
        if (authentication == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();

        UserResponseDTO userResponseDTO = new UserResponseDTO(userPrincipal, userPrincipal.getEmployee());

        return ResponseEntity.ok(userResponseDTO);
    }

    @GetMapping("/profile/status")
    @PreAuthorize("hasRole('ROLE_EMPLOYEE') or hasRole('ROLE_ADMIN') or hasRole('ROLE_RH') or hasRole('ROLE_NURSE') or hasRole('ROLE_DOCTOR')")
    public ResponseEntity<java.util.Map<String, Boolean>> checkProfileStatus(Authentication authentication) {
        if (authentication == null) {
            return ResponseEntity.status(401).build(); // Unauthorized
        }
        String userEmail = authentication.getName();
        boolean isComplete = employeeService.isProfileComplete(userEmail);
        return ResponseEntity.ok(java.util.Collections.singletonMap("isProfileComplete", isComplete));
    }

    @PutMapping("/profile")
    @PreAuthorize("hasRole('ROLE_EMPLOYEE') or hasRole('ROLE_ADMIN') or hasRole('ROLE_RH') or hasRole('ROLE_NURSE') or hasRole('ROLE_DOCTOR')")
    public ResponseEntity<EmployeeProfileDTO> updateProfile(@RequestBody EmployeeCreationRequestDTO employeeDetails) {
        Employee updatedEmployee = employeeService.updateEmployeeProfile(employeeDetails);
        return ResponseEntity.ok(new EmployeeProfileDTO(updatedEmployee));
    }

    @RequestMapping(value = "/create-complete", method = {RequestMethod.POST, RequestMethod.PUT})
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasRole('ROLE_RH')")
    public ResponseEntity<?> createCompleteEmployee(@RequestBody EmployeeCreationRequestDTO request) {
        try {
            Employee newEmployee = employeeService.createCompleteEmployee(request);
            // Returning the created employee's profile
            return ResponseEntity.ok(new EmployeeProfileDTO(newEmployee));
        } catch (Exception e) {
            // It's better to return a more specific error status
            return ResponseEntity.badRequest().body("Error creating employee: " + e.getMessage());
        }
    }

    @GetMapping("/stats")
    @PreAuthorize("hasRole('ROLE_EMPLOYEE')")
    public ResponseEntity<EmployeeStatsDTO> getEmployeeStats(Authentication authentication) {
        UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();
        Employee employee = userPrincipal.getEmployee();

        if (employee == null || employee.getUser() == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        long appointmentsCount = appointmentRepository.findByEmployeeUserId(employee.getUser().getId()).size();
        long visitsCount = appointmentRepository.findByEmployeeUserIdAndStatus(employee.getUser().getId(), com.oshapp.backend.model.enums.AppointmentStatus.COMPLETED).size();
        long documentsCount = 0; // TODO: Implement document count logic

        EmployeeStatsDTO stats = new EmployeeStatsDTO((int) appointmentsCount, (int) visitsCount, (int) documentsCount);
        return ResponseEntity.ok(stats);
    }

    @GetMapping("/medical-fitness/{employeeId}")
    @PreAuthorize("hasAnyRole('ROLE_EMPLOYEE', 'ROLE_ADMIN', 'ROLE_RH', 'ROLE_NURSE', 'ROLE_DOCTOR')")
    public ResponseEntity<MedicalFitnessDTO> getMedicalFitnessStatus(@PathVariable Long employeeId, Authentication authentication) {
        // TODO: Add authorization logic to ensure the authenticated user can view this employee's data.
        Employee employee = employeeRepository.findById(employeeId)
                .orElseThrow(() -> new UsernameNotFoundException("Employee not found for id: " + employeeId));

        List<com.oshapp.backend.model.Appointment> completedVisits = appointmentRepository.findByEmployeeUserIdAndStatus(employee.getUser().getId(), com.oshapp.backend.model.enums.AppointmentStatus.COMPLETED);

        if (completedVisits.isEmpty()) {
            return ResponseEntity.ok(new MedicalFitnessDTO("Inconnu", null, "N/A"));
        }

        // Find the most recent completed visit
        completedVisits.sort((a1, a2) -> a2.getScheduledTime().compareTo(a1.getScheduledTime()));
        com.oshapp.backend.model.Appointment lastVisit = completedVisits.get(0);

        String status = "Apt"; // Default status after a visit
        LocalDate nextVisitDate = lastVisit.getScheduledTime().toLocalDate().plusYears(1); // Standard annual visit
        String doctorName = (lastVisit.getDoctor() != null && lastVisit.getDoctor().getEmployee() != null) ? lastVisit.getDoctor().getEmployee().getFirstName() : "N/A";

        MedicalFitnessDTO fitnessStatus = new MedicalFitnessDTO(status, nextVisitDate, doctorName);
        return ResponseEntity.ok(fitnessStatus);
    }

    @GetMapping("/medical-fitness/history/{employeeId}")
    @PreAuthorize("hasAnyRole('ROLE_EMPLOYEE', 'ROLE_ADMIN', 'ROLE_RH', 'ROLE_NURSE', 'ROLE_DOCTOR')")
    public ResponseEntity<List<MedicalFitnessDTO>> getMedicalFitnessHistory(@PathVariable Long employeeId) {
        Employee employee = employeeRepository.findById(employeeId)
                .orElseThrow(() -> new UsernameNotFoundException("Employee not found for id: " + employeeId));

        List<com.oshapp.backend.model.Appointment> completedVisits = appointmentRepository.findByEmployeeUserIdAndStatus(employee.getUser().getId(), com.oshapp.backend.model.enums.AppointmentStatus.COMPLETED);

        if (completedVisits.isEmpty()) {
            return ResponseEntity.ok(java.util.Collections.emptyList());
        }

        // Sort by most recent first
        completedVisits.sort((a1, a2) -> a2.getScheduledTime().compareTo(a1.getScheduledTime()));

        List<MedicalFitnessDTO> history = completedVisits.stream().map(visit -> {
            String status = "Apt"; // Default status
            LocalDate nextVisitDate = visit.getScheduledTime().toLocalDate().plusYears(1);
            String doctorName = (visit.getDoctor() != null && visit.getDoctor().getEmployee() != null) ? visit.getDoctor().getEmployee().getFirstName() : "N/A";
            // You can add more logic here to determine status based on visit details
            return new MedicalFitnessDTO(status, nextVisitDate, doctorName);
        }).collect(Collectors.toList());

        return ResponseEntity.ok(history);
    }
}