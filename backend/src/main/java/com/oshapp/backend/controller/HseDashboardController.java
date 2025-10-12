package com.oshapp.backend.controller;

import com.oshapp.backend.dto.HseDashboardDTO;
import com.oshapp.backend.service.HseDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/hse/dashboard")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ROLE_HSE')")
public class HseDashboardController {

    private final HseDashboardService hseDashboardService;

    @GetMapping
    public ResponseEntity<HseDashboardDTO> getDashboardData() {
        HseDashboardDTO dto = hseDashboardService.getDashboardData();
        return ResponseEntity.ok(dto);
    }
}
