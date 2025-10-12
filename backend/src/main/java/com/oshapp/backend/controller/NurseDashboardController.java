package com.oshapp.backend.controller;

import com.oshapp.backend.dto.NurseDashboardDTO;
import com.oshapp.backend.service.NurseDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/nurse/dashboard")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ROLE_NURSE')")
public class NurseDashboardController {

    private final NurseDashboardService nurseDashboardService;

    @GetMapping
    public ResponseEntity<NurseDashboardDTO> getDashboardData() {
        NurseDashboardDTO dashboardData = nurseDashboardService.getDashboardData();
        return ResponseEntity.ok(dashboardData);
    }
}
