package com.oshapp.backend.controller;

import com.oshapp.backend.payload.request.ActivationRequest;
import com.oshapp.backend.payload.request.ResendActivationRequest;
import com.oshapp.backend.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/account")
@RequiredArgsConstructor
public class AccountController {

    private final UserService userService;

    @PostMapping("/activate")
    public ResponseEntity<?> activateAccount(@Valid @RequestBody ActivationRequest request) {
        userService.activateAccount(request.getToken());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/resend-activation")
    public ResponseEntity<?> resendActivationCode(@Valid @RequestBody ResendActivationRequest request) {
        userService.resendActivationCode(request.getEmail());
        return ResponseEntity.ok().build();
    }
}