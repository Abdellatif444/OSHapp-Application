package com.oshapp.backend.controller;

import com.oshapp.backend.dto.UserResponseDTO;
import com.oshapp.backend.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import com.oshapp.backend.security.UserPrincipal;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;


@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    public ResponseEntity<UserResponseDTO> getMyProfile(Authentication authentication) {
        UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();
        // The employee data is still needed for the full profile. Fetch it separately.
        // This assumes that if a user exists, their corresponding employee record should also be accessible.
        UserResponseDTO userResponseDTO = userService.createDtoFromPrincipal(userPrincipal);
        return ResponseEntity.ok(userResponseDTO);
    }
}
