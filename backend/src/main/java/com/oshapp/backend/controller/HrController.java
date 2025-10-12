package com.oshapp.backend.controller;

import com.oshapp.backend.dto.MandatoryVisitRequestDTO;
import com.oshapp.backend.dto.MedicalCertificateDTO;
import com.oshapp.backend.dto.UploadedMedicalCertificateDTO;
import com.oshapp.backend.dto.WorkAccidentDTO;
import com.oshapp.backend.service.HrService;
import com.oshapp.backend.model.MedicalCertificate;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/hr")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ROLE_RH')")
public class HrController {

    private final HrService hrService;

    @GetMapping("/medical-certificates")
    public ResponseEntity<List<MedicalCertificateDTO>> getMedicalCertificates() {
        return ResponseEntity.ok(hrService.getAllMedicalCertificates());
    }

    @GetMapping("/medical-certificates/uploads")
    public ResponseEntity<List<UploadedMedicalCertificateDTO>> getUploadedMedicalCertificates() {
        return ResponseEntity.ok(hrService.getAllUploadedMedicalCertificates());
    }

    @GetMapping("/work-accidents")
    public ResponseEntity<List<WorkAccidentDTO>> getWorkAccidents() {
        return ResponseEntity.ok(hrService.getAllWorkAccidents());
    }

    @PostMapping("/mandatory-visits")
    public ResponseEntity<Void> requestMandatoryVisits(@RequestBody MandatoryVisitRequestDTO request) {
                List<Long> employeeIdsAsLong = request.getEmployeeIds().stream().map(Integer::longValue).toList();
        hrService.requestMandatoryVisits(employeeIdsAsLong, request.getVisitType());
        return ResponseEntity.ok().build();
    }

    @PostMapping(path = "/medical-certificates/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MedicalCertificate> uploadMedicalCertificate(
            @RequestParam("employeeId") Long employeeId,
            @RequestParam(value = "certificateType", required = false) String certificateType,
            @RequestParam(value = "issueDate", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate issueDate,
            @RequestPart("file") MultipartFile file
    ) {
        MedicalCertificate saved = hrService.uploadMedicalCertificate(employeeId, certificateType, issueDate, file);
        return ResponseEntity.ok(saved);
    }
}

