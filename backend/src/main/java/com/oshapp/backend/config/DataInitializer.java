package com.oshapp.backend.config;

import com.oshapp.backend.model.enums.RoleName;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.Role;
import com.oshapp.backend.model.User;
import com.oshapp.backend.repository.EmployeeRepository;
import com.oshapp.backend.repository.RoleRepository;
import com.oshapp.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final EmployeeRepository employeeRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(String... args) {
        log.info("Checking if initial data needs to be created...");
        if (userRepository.count() == 0) {
            log.info("No users found. Creating initial data set.");
            // Create Roles
            Role adminRole = getOrCreateRole(RoleName.ROLE_ADMIN);
            Role doctorRole = getOrCreateRole(RoleName.ROLE_DOCTOR);
            Role nurseRole = getOrCreateRole(RoleName.ROLE_NURSE);
            Role hrRole = getOrCreateRole(RoleName.ROLE_RH);
            Role employeeRole = getOrCreateRole(RoleName.ROLE_EMPLOYEE);
            Role hseRole = getOrCreateRole(RoleName.ROLE_HSE);

            // Create users with their associated employee profiles
            createUserWithEmployeeProfile("admin@oshapp.com", "admin12345678", "Admin", "User", Set.of(adminRole));
            createUserWithEmployeeProfile("abdelatifgourri11@gmail.com", "Abdellatif12345678@", "Doctor", "User", Set.of(doctorRole));
            createUserWithEmployeeProfile("gourriabde@gmail.com", "Gourri12345678@", "Nurse", "User", Set.of(nurseRole));
            createUserWithEmployeeProfile("avdjdcsb@gmail.com", "Abcd12345678@", "RH", "User", Set.of(hrRole));
            createUserWithEmployeeProfile("salarie@oshapp.com", "salarie123", "Salarie", "Test", Set.of(employeeRole));
            createUserWithEmployeeProfile("hse@oshapp.com", "hse12345678", "HSE", "User", Set.of(hseRole));
            createUserWithEmployeeProfile("gourri.abdellatif@gmail.com", "Abdellatif12345678@", "Abdellatif", "User", Set.of(employeeRole));
            log.info("Initial data creation complete.");
        } else {
            log.info("Database already contains data. Skipping data initialization.");
        }
    }

    private Role getOrCreateRole(RoleName roleName) {
        return roleRepository.findByName(roleName).orElseGet(() -> {
            log.info("Creating new role: {}", roleName);
            Role newRole = new Role(roleName);
            return roleRepository.save(newRole);
        });
    }

    private void createUserWithEmployeeProfile(String email, String password, String firstName, String lastName, Set<Role> roles) {
        // Check if user already exists to prevent unique constraint violation
        if (userRepository.findByEmail(email).isPresent()) {
            log.warn("User with email {} already exists. Skipping creation.", email);
            return;
        }

        // If user does not exist, create the user and their employee profile
        log.info("Creating user and employee profile for: {}", email);
        User newUser = new User();
        newUser.setUsername(email);
        newUser.setEmail(email);
        newUser.setPassword(passwordEncoder.encode(password));
        newUser.setRoles(roles);
        newUser.setActive(true);
        
        // Vérifier si c'est un compte admin pour l'activer automatiquement
        boolean isAdmin = roles.stream().anyMatch(role -> role.getName() == RoleName.ROLE_ADMIN);
        
        if (isAdmin) {
            // Les comptes admin sont activés directement
            newUser.setEnabled(true);
            log.info("Admin account created and enabled: {}", email);
        } else {
            // Les autres comptes nécessitent une activation
            newUser.setEnabled(false);
            log.info("Non-admin account created, activation required: {}", email);
        }
        
        User savedUser = userRepository.save(newUser);

        Employee employee = new Employee();
        employee.setUser(savedUser);
        employee.setFirstName(firstName);
        employee.setLastName(lastName);
        employee.setProfileCompleted(false);
        employeeRepository.save(employee);
    }
}
