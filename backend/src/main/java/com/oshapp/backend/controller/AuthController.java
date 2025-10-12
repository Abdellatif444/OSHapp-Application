package com.oshapp.backend.controller;

import com.oshapp.backend.dto.EmployeeProfileDTO;
import com.oshapp.backend.dto.LoginRequest;
import com.oshapp.backend.dto.LoginResponseDTO;
import com.oshapp.backend.dto.GoogleLoginRequest;
import com.oshapp.backend.dto.ForgotPasswordRequest;
import com.oshapp.backend.dto.ResetPasswordRequest;
import com.oshapp.backend.dto.UserResponseDTO;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.RoleName;
import com.oshapp.backend.repository.UserRepository;
import com.oshapp.backend.service.UserService;
import com.oshapp.backend.service.EmployeeService;
import com.oshapp.backend.exception.InvalidTokenException;
import com.oshapp.backend.security.JwtTokenProvider;
import com.oshapp.backend.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.Set;
import java.util.UUID;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.jackson2.JacksonFactory;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider jwtTokenProvider;
    private final UserRepository userRepository;
    private final UserService userService;
    private final EmployeeService employeeService;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.google.clientId:}")
    private String googleClientId;

    @PostMapping("/login")
    public ResponseEntity<?> authenticateUser(@RequestBody LoginRequest loginRequest) {
        // Pré-vérification de l'activation pour éviter un 401 dû à DisabledException
        User user = userRepository.findByEmail(loginRequest.getEmail()).orElse(null);
        if (user != null && !user.isEnabled()) {
            boolean isAdmin = user.getRoles().stream()
                    .anyMatch(role -> role.getName() == RoleName.ROLE_ADMIN);
            if (!isAdmin) {
                userService.createAndSendActivationToken(user);
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(Map.of("error", "ACCOUNT_NOT_ACTIVATED"));
            }
        }

        Authentication authentication;
        try {
            authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(loginRequest.getEmail(), loginRequest.getPassword()));
        } catch (DisabledException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "ACCOUNT_NOT_ACTIVATED"));
        } catch (BadCredentialsException ex) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "UNAUTHORIZED"));
        } catch (AuthenticationException ex) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "UNAUTHORIZED"));
        }

        SecurityContextHolder.getContext().setAuthentication(authentication);

        UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();
        String jwt = jwtTokenProvider.generateToken(authentication);
        UserResponseDTO userResponseDTO = userService.createDtoFromPrincipal(userPrincipal);

        return ResponseEntity.ok(new LoginResponseDTO(jwt, userResponseDTO));
    }

    @PostMapping("/google")
    public ResponseEntity<?> authenticateWithGoogle(@RequestBody GoogleLoginRequest request) {
        try {
            if (request == null || request.getIdToken() == null || request.getIdToken().isBlank()) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(Map.of("error", "INVALID_ID_TOKEN"));
            }

            if (googleClientId == null || googleClientId.isBlank()) {
                return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                        .body(Map.of("error", "GOOGLE_CLIENT_ID_NOT_CONFIGURED"));
            }

            GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(
                    new NetHttpTransport(), JacksonFactory.getDefaultInstance())
                    .setAudience(java.util.Collections.singletonList(googleClientId))
                    .build();

            GoogleIdToken idToken = verifier.verify(request.getIdToken());
            if (idToken == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("error", "UNAUTHORIZED"));
            }

            GoogleIdToken.Payload payload = idToken.getPayload();
            String email = payload.getEmail();
            if (email == null || email.isBlank()) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("error", "UNAUTHORIZED"));
            }

            Boolean emailVerified = (Boolean) payload.get("email_verified");
            if (emailVerified != null && !emailVerified) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("error", "UNAUTHORIZED"));
            }

            User user = userRepository.findByEmail(email).orElse(null);
            if (user == null) {
                // Auto-provision a new enabled EMPLOYEE account for first-time Google users
                User newUser = new User();
                newUser.setUsername(email);
                newUser.setEmail(email);
                newUser.setPassword(passwordEncoder.encode(UUID.randomUUID().toString()));
                newUser.setActive(true);
                newUser.setEnabled(true);
                // Assign EMPLOYEE role
                newUser.setRoles(userService.findRolesByNames(Set.of("ROLE_EMPLOYEE")));
                // Optional: capture names from Google payload
                String givenName = (String) payload.get("given_name");
                String familyName = (String) payload.get("family_name");
                if (givenName != null && !givenName.isBlank()) newUser.setFirstName(givenName);
                if (familyName != null && !familyName.isBlank()) newUser.setLastName(familyName);

                user = userService.save(newUser);
                try {
                    employeeService.createEmployeeProfileIfNotFound(user);
                } catch (Exception ignored) { }
            }

            if (!user.isEnabled()) {
                boolean isAdmin = user.getRoles().stream()
                        .anyMatch(role -> role.getName() == RoleName.ROLE_ADMIN);
                if (!isAdmin) {
                    userService.createAndSendActivationToken(user);
                    return ResponseEntity.status(HttpStatus.FORBIDDEN)
                            .body(Map.of("error", "ACCOUNT_NOT_ACTIVATED"));
                }
            }

            UserPrincipal userPrincipal = UserPrincipal.create(user);
            Authentication authentication = new UsernamePasswordAuthenticationToken(
                    userPrincipal, null, userPrincipal.getAuthorities());
            SecurityContextHolder.getContext().setAuthentication(authentication);

            String jwt = jwtTokenProvider.generateToken(authentication);
            UserResponseDTO userResponseDTO = userService.createDtoFromPrincipal(userPrincipal);
            return ResponseEntity.ok(new LoginResponseDTO(jwt, userResponseDTO));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "UNAUTHORIZED"));
        }
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody ForgotPasswordRequest request) {
        if (request == null || request.getEmail() == null || request.getEmail().isBlank()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "INVALID_REQUEST"));
        }
        // Do not reveal whether the email exists
        userService.requestPasswordReset(request.getEmail());
        return ResponseEntity.ok(Map.of("status", "OK"));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@RequestBody ResetPasswordRequest request) {
        if (request == null || request.getToken() == null || request.getToken().isBlank()
                || request.getNewPassword() == null || request.getNewPassword().isBlank()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "INVALID_REQUEST"));
        }
        try {
            userService.resetPassword(request.getToken(), request.getNewPassword());
            return ResponseEntity.ok(Map.of("status", "OK"));
        } catch (InvalidTokenException ex) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "INVALID_OR_EXPIRED_TOKEN"));
        }
    }
}
