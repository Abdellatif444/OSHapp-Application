package com.oshapp.backend.controller;

import com.oshapp.backend.dto.DoctorDashboardDTO;
import com.oshapp.backend.service.DoctorDashboardService;
import com.oshapp.backend.security.UserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/doctor/dashboard")
@RequiredArgsConstructor
public class DoctorDashboardController {

    private final DoctorDashboardService doctorDashboardService;

    @GetMapping
    @PreAuthorize("hasRole('ROLE_DOCTOR')")
    public ResponseEntity<DoctorDashboardDTO> getDoctorDashboardData(@AuthenticationPrincipal UserPrincipal userPrincipal) {
        DoctorDashboardDTO dto = doctorDashboardService.getDashboardData();
        return ResponseEntity.ok(dto);
    }
}
