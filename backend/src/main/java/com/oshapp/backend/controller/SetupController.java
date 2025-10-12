package com.oshapp.backend.controller;

import com.oshapp.backend.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Set;
import org.springframework.context.annotation.Profile;

@Profile("dev")
@RestController
@RequestMapping("/api/v1/setup")
@RequiredArgsConstructor
public class SetupController {

    private final UserService userService;

    @PostMapping("/create-test-users")
    public ResponseEntity<String> setupTestUsers() {
        try {
            if (userService.findByEmail("admin@oshapp.com").isEmpty()) {
                userService.createUser("admin@oshapp.com", "admin12345678", Set.of("ROLE_ADMIN"), true);
            }
            if (userService.findByEmail("rh@oshapp.com").isEmpty()) {
                userService.createUser("rh@oshapp.com", "rh12345678", Set.of("ROLE_RH"), true);
            }
            if (userService.findByEmail("salarie@oshapp.com").isEmpty()) {
                userService.createUser("salarie@oshapp.com", "salarie12345678", Set.of("ROLE_EMPLOYEE"), true);
            }
            return ResponseEntity.ok("Test users created or already exist.");
        } catch (Exception e) {
            return ResponseEntity.status(500).body("Error setting up test users: " + e.getMessage());
        }
    }
}
