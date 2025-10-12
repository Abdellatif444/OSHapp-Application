package com.oshapp.backend.controller;

import com.oshapp.backend.dto.UserCreationRequestDTO;
import com.oshapp.backend.dto.UserResponseDTO;
import com.oshapp.backend.dto.UserUpdateRequestDTO;
import com.oshapp.backend.dto.RoleDTO;
import com.oshapp.backend.dto.EmployeeManagersUpdateDTO;
import com.oshapp.backend.dto.EmployeeProfileDTO;
import com.oshapp.backend.dto.EmployeeCreationRequestDTO;
import com.oshapp.backend.service.RoleService;
import com.oshapp.backend.exception.ResourceNotFoundException;
import com.oshapp.backend.model.Role;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.UserService;
import com.oshapp.backend.service.EmployeeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Set;
import com.oshapp.backend.dto.AdminDashboardData;
import com.oshapp.backend.service.AdminDashboardService;
import com.oshapp.backend.service.StatisticsService;

import java.util.stream.Collectors;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminController {

    private final UserService userService;
    private final NotificationService notificationService;
    private final RoleService roleService;
    private final AdminDashboardService adminDashboardService;
    private final StatisticsService statisticsService;
    private final EmployeeService employeeService;



    @PostMapping("/users")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH')")
    public ResponseEntity<UserResponseDTO> createUser(@RequestBody UserCreationRequestDTO request) {
        try {
            User user = userService.createUser(request.getEmail(), request.getPassword(), request.getRoles(), true);

            try {
                userService.findUsersByRoleName("ROLE_RH").forEach(rh ->
                        notificationService.createNotification(
                                "Un nouveau compte utilisateur a été créé par l'admin : " + user.getEmail(),
                                rh,
                                "CREATION_COMPTE"
                        )
                );
            } catch (Exception e) {
                System.err.println("Erreur lors de la notification RH: " + e.getMessage());
            }

            return ResponseEntity.ok(convertToDto(user));
        } catch (DataIntegrityViolationException ex) {
            // Contrainte d'unicité violée (email déjà utilisé)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email déjà utilisé", ex);
        } catch (Exception e) {
            System.err.println("Erreur lors de la création d'utilisateur: " + e.getMessage());
            e.printStackTrace();
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Erreur lors de la création de l'utilisateur", e);
        }
    }

    @GetMapping("/users")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH')")
    public ResponseEntity<List<UserResponseDTO>> getAllUsers() {
        List<UserResponseDTO> userDTOs = userService.findAll().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
        return ResponseEntity.ok(userDTOs);
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<UserResponseDTO> getUserById(@PathVariable Long id) {
        User user = userService.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur non trouvé avec l'id: " + id));
        return ResponseEntity.ok(convertToDto(user));
    }

    @PutMapping("/users/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH')")
    public ResponseEntity<UserResponseDTO> updateUser(@PathVariable Long id, @RequestBody UserUpdateRequestDTO request) {
        User user = userService.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur non trouvé avec l'id: " + id));

        if (request.getEmail() != null) {
            user.setEmail(request.getEmail());
        }
        if (request.getRoles() != null && !request.getRoles().isEmpty()) {
            Set<Role> roles = userService.findRolesByNames(request.getRoles());
            user.setRoles(roles);
        }

        if (request.getPassword() != null && !request.getPassword().isEmpty()) {
            userService.updatePassword(user, request.getPassword());
        } else {
            userService.save(user);
        }

                if(request.getActive() != null && request.getActive() != user.isActive()) {
            user.setActive(request.getActive());
            userService.save(user);
        }

        return ResponseEntity.ok(convertToDto(user));
    }

    @DeleteMapping("/users/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH')")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        User user = userService.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur non trouvé avec l'id: " + id));
        try {
            userService.delete(user);
        } catch (DataIntegrityViolationException ex) {
            String message = "Impossible de supprimer l'utilisateur: il est encore référencé par des rendez-vous. " +
                    "Veuillez d'abord réaffecter ou libérer ces rendez-vous, ou désactiver le compte.";
            throw new ResponseStatusException(HttpStatus.CONFLICT, message, ex);
        }
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/dashboard")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<AdminDashboardData> getDashboardData() {
        AdminDashboardData dashboardData = adminDashboardService.getDashboardData();
        return ResponseEntity.ok(dashboardData);
    }

    // Alias endpoint for admin statistics to maintain compatibility with older frontend paths
    // Maps to: GET /api/v1/admin/statistics
    // Delegates to the same statistics service used by StatisticsController (/api/v1/statistics/admin)
    @GetMapping("/statistics")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, Object>> getAdminStatisticsAlias() {
        Map<String, Object> stats = statisticsService.getAdminDashboardStatistics();
        return ResponseEntity.ok(stats);
    }

    private UserResponseDTO convertToDto(User user) {
        UserResponseDTO dto = new UserResponseDTO();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setEmail(user.getEmail());
        dto.setRoles(user.getRoles().stream()
                .map(role -> role.getName().name())
                .collect(Collectors.toSet()));
        dto.setEnabled(user.isEnabled());
        dto.setActive(user.isActive());

        if (user.getEmployee() != null) {
            Employee emp = user.getEmployee();
            dto.setEmployee(new EmployeeProfileDTO(emp, user.isEnabled()));
            if (emp.getManager1() != null) {
                dto.setN1(emp.getManager1().getId());
            }
            if (emp.getManager2() != null) {
                dto.setN2(emp.getManager2().getId());
            }
        }

        return dto;
    }

    // --- Role Management Endpoints ---

    @GetMapping("/roles")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<RoleDTO>> getAllRoles() {
        List<RoleDTO> roles = roleService.findAll().stream()
                .map(role -> new RoleDTO(role.getId(), role.getName().name()))
                .collect(Collectors.toList());
        return ResponseEntity.ok(roles);
    }

    @PostMapping("/roles")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<RoleDTO> createRole(@RequestBody RoleDTO roleDTO) {
        Role newRole = roleService.createRole(roleDTO.getName());
        return ResponseEntity.ok(new RoleDTO(newRole.getId(), newRole.getName().name()));
    }

    @PutMapping("/roles/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<RoleDTO> updateRole(@PathVariable Integer id, @RequestBody RoleDTO roleDTO) {
        Role updatedRole = roleService.updateRole(id, roleDTO.getName());
        return ResponseEntity.ok(new RoleDTO(updatedRole.getId(), updatedRole.getName().name()));
    }

    @DeleteMapping("/roles/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> deleteRole(@PathVariable Integer id) {
        roleService.deleteRole(id);
        return ResponseEntity.noContent().build();
    }

    // --- Employee Manager Assignment (Admin) ---
    @PutMapping("/employees/{id}/managers")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH')")
    public ResponseEntity<Employee> updateEmployeeManagers(
            @PathVariable("id") Long employeeId,
            @RequestBody EmployeeManagersUpdateDTO request
    ) {
        Employee updated = employeeService.updateEmployeeManagers(employeeId, request.getManager1Id(), request.getManager2Id());
        return ResponseEntity.ok(updated);
    }

    // --- Employee profile update by userId (Admin) ---
    @PutMapping("/users/{id}/employee-profile")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH')")
    public ResponseEntity<EmployeeProfileDTO> updateEmployeeProfileByUser(
            @PathVariable("id") Long userId,
            @RequestBody EmployeeCreationRequestDTO request
    ) {
        Employee updated = employeeService.updateEmployeeProfileByUserId(userId, request);
        return ResponseEntity.ok(new EmployeeProfileDTO(updated));
    }

}