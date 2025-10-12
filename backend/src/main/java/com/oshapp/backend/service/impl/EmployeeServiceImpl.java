package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.EmployeeCreationRequestDTO;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.User;
import com.oshapp.backend.repository.EmployeeRepository;
import com.oshapp.backend.repository.UserRepository;
import com.oshapp.backend.service.EmployeeService;
import com.oshapp.backend.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeServiceImpl implements EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final UserRepository userRepository;

    @Override
    public Optional<Employee> getEmployeeByUserId(Long id) {
        return employeeRepository.findByUserId(id);
    }

    @Override
    public List<Employee> findSubordinatesByManagerEmail(String managerEmail) {
        return employeeRepository.findSubordinatesByManagerEmail(managerEmail);
    }

    @Override
    @Transactional
    public Employee updateEmployeeProfile(EmployeeCreationRequestDTO employeeDetails) {
        String currentUserEmail = SecurityContextHolder.getContext().getAuthentication().getName();
        User user = userRepository.findByEmail(currentUserEmail)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + currentUserEmail));

        Employee employee = employeeRepository.findByUserId(user.getId()).orElse(null);
        if (employee == null) {
            // Create a new profile for users who do not yet have one (e.g., new doctors / nurses)
            employee = new Employee();
            employee.setUser(user);
        }

        employee.setFirstName(employeeDetails.getFirstName());
        employee.setLastName(employeeDetails.getLastName());
        employee.setPosition(employeeDetails.getPosition());
        employee.setDepartment(employeeDetails.getDepartment());
        employee.setHireDate(employeeDetails.getHireDate());
        employee.setCin(employeeDetails.getCin());
        employee.setCnss(employeeDetails.getCnss());
        employee.setPhoneNumber(employeeDetails.getPhoneNumber());
        employee.setAddress(employeeDetails.getAddress());
        employee.setNationality(employeeDetails.getNationality());
        employee.setGender(employeeDetails.getGender());

        // Handle renamed and new fields
        employee.setBirthDate(employeeDetails.getDateOfBirth());
        employee.setBirthPlace(employeeDetails.getPlaceOfBirth());
        employee.setCity(employeeDetails.getCity());
        employee.setZipCode(employeeDetails.getZipCode());
        employee.setCountry(employeeDetails.getCountry());

        if (employeeDetails.getManager1Id() != null) {
            employeeRepository.findById(employeeDetails.getManager1Id()).ifPresent(employee::setManager1);
        } else {
            employee.setManager1(null);
        }
        if (employeeDetails.getManager2Id() != null) {
            employeeRepository.findById(employeeDetails.getManager2Id()).ifPresent(employee::setManager2);
        } else {
            employee.setManager2(null);
        }

        employee.setProfileCompleted(true);

        return employeeRepository.save(employee);
    }

    @Override
    @Transactional
    public Employee updateEmployeeProfileByUserId(Long userId, EmployeeCreationRequestDTO employeeDetails) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

        Employee employee = employeeRepository.findByUserId(user.getId()).orElse(null);
        if (employee == null) {
            employee = new Employee();
            employee.setUser(user);
        }

        employee.setFirstName(employeeDetails.getFirstName());
        employee.setLastName(employeeDetails.getLastName());
        employee.setPosition(employeeDetails.getPosition());
        employee.setDepartment(employeeDetails.getDepartment());
        employee.setHireDate(employeeDetails.getHireDate());
        employee.setCin(employeeDetails.getCin());
        employee.setCnss(employeeDetails.getCnss());
        employee.setPhoneNumber(employeeDetails.getPhoneNumber());
        employee.setAddress(employeeDetails.getAddress());
        employee.setNationality(employeeDetails.getNationality());
        employee.setGender(employeeDetails.getGender());

        // Additional fields
        employee.setBirthDate(employeeDetails.getDateOfBirth());
        employee.setBirthPlace(employeeDetails.getPlaceOfBirth());
        employee.setCity(employeeDetails.getCity());
        employee.setZipCode(employeeDetails.getZipCode());
        employee.setCountry(employeeDetails.getCountry());

        if (employeeDetails.getManager1Id() != null) {
            employeeRepository.findById(employeeDetails.getManager1Id()).ifPresent(employee::setManager1);
        } else {
            employee.setManager1(null);
        }
        if (employeeDetails.getManager2Id() != null) {
            employeeRepository.findById(employeeDetails.getManager2Id()).ifPresent(employee::setManager2);
        } else {
            employee.setManager2(null);
        }

        employee.setProfileCompleted(true);

        return employeeRepository.save(employee);
    }

    @Override
    public Employee createCompleteEmployee(EmployeeCreationRequestDTO request) {
        User user = userRepository.findById(request.getUserId())
                .orElseThrow(() -> new RuntimeException("User not found"));

        Employee employee = new Employee();
        employee.setUser(user);
        employee.setFirstName(request.getFirstName());
        employee.setLastName(request.getLastName());
        employee.setPosition(request.getPosition());
        employee.setDepartment(request.getDepartment());
        employee.setHireDate(request.getHireDate());
        employee.setCin(request.getCin());
        employee.setCnss(request.getCnss());
        employee.setPhoneNumber(request.getPhoneNumber());
        employee.setGender(request.getGender());
        if (request.getDateOfBirth() != null) {
            employee.setBirthDate(request.getDateOfBirth());
        }
        employee.setBirthPlace(request.getPlaceOfBirth());
        employee.setAddress(request.getAddress());
        employee.setNationality(request.getNationality());
        employee.setProfileCompleted(true);

        if (request.getManager1Id() != null) {
            Employee manager1 = employeeRepository.findById(request.getManager1Id()).orElse(null);
            employee.setManager1(manager1);
        }

        if (request.getManager2Id() != null) {
            Employee manager2 = employeeRepository.findById(request.getManager2Id()).orElse(null);
            employee.setManager2(manager2);
        }

        return employeeRepository.save(employee);
    }

    @Override
    public void createEmployeeProfileIfNotFound(User user) {
        if (employeeRepository.findByUserId(user.getId()).isEmpty()) {
            Employee employee = Employee.builder()
                    .user(user)
                    .profileCompleted(false)
                    .build();
            employeeRepository.save(employee);
        }
    }

    @Override
    public boolean isProfileComplete(String email) {
        Employee employee = employeeRepository.findByUserEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("Employee not found for email: " + email));
        return employee.isProfileCompleted();
    }

    @Override
    public List<Employee> findAll() {
        return employeeRepository.findAll();
    }

    @Override
    @Transactional
    public Employee createEmployeeFromUser(Employee employee) {
        return employeeRepository.save(employee);
    }

    @Override
    @Transactional
    public Employee updateEmployeeManagers(Long employeeId, Long manager1Id, Long manager2Id) {
        Employee employee = employeeRepository.findById(employeeId)
                .orElseThrow(() -> new ResourceNotFoundException("Employee not found with id: " + employeeId));

        if (manager1Id != null) {
            Employee m1 = employeeRepository.findById(manager1Id)
                    .orElseThrow(() -> new ResourceNotFoundException("Manager1 not found with id: " + manager1Id));
            employee.setManager1(m1);
        } else {
            employee.setManager1(null);
        }

        if (manager2Id != null) {
            Employee m2 = employeeRepository.findById(manager2Id)
                    .orElseThrow(() -> new ResourceNotFoundException("Manager2 not found with id: " + manager2Id));
            employee.setManager2(m2);
        } else {
            employee.setManager2(null);
        }

        return employeeRepository.save(employee);
    }
}

