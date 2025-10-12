package com.oshapp.backend.service;

import com.oshapp.backend.dto.EmployeeCreationRequestDTO;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.User;

import java.util.List;
import java.util.Optional;

public interface EmployeeService {
    

    Optional<Employee> getEmployeeByUserId(Long id);

    List<Employee> findSubordinatesByManagerEmail(String managerEmail);

    Employee updateEmployeeProfile(EmployeeCreationRequestDTO employeeDetails);

    /**
     * Admin-only helper: update or create the employee profile for the specified userId.
     * This method should not rely on the authenticated user context and is intended to be
     * called from admin endpoints.
     */
    Employee updateEmployeeProfileByUserId(Long userId, EmployeeCreationRequestDTO employeeDetails);

    boolean isProfileComplete(String email);

    Employee createCompleteEmployee(EmployeeCreationRequestDTO request);

    void createEmployeeProfileIfNotFound(User user);

    List<Employee> findAll();

    Employee createEmployeeFromUser(Employee employee);

    /**
     * Admin-only: Update N+1 and N+2 managers for a given employee.
     * Any of manager1Id/manager2Id can be null to clear the assignment.
     */
    Employee updateEmployeeManagers(Long employeeId, Long manager1Id, Long manager2Id);
}
