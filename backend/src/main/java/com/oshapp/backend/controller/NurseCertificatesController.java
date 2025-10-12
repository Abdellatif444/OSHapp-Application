package com.oshapp.backend.controller;

import com.oshapp.backend.dto.UploadedMedicalCertificateDTO;
import com.oshapp.backend.service.HrService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/nurse")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ROLE_NURSE')")
public class NurseCertificatesController {

    private final HrService hrService;

    /**
     * Returns uploaded medical certificates for a specific employee. Accessible to nurses.
     */
    @GetMapping("/medical-certificates/uploads")
    public ResponseEntity<List<UploadedMedicalCertificateDTO>> getUploadedMedicalCertificatesForEmployee(
            @RequestParam("employeeId") Long employeeId
    ) {
        return ResponseEntity.ok(hrService.getUploadedMedicalCertificatesForEmployee(employeeId));
    }
}
