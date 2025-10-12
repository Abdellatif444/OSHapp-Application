package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.MedicalCertificateDTO;
import com.oshapp.backend.dto.UploadedMedicalCertificateDTO;
import com.oshapp.backend.dto.WorkAccidentDTO;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.MedicalCertificate;
import com.oshapp.backend.repository.EmployeeRepository;
import com.oshapp.backend.repository.SickLeaveCertificateRepository;
import com.oshapp.backend.repository.MedicalCertificateRepository;
import com.oshapp.backend.repository.WorkAccidentRepository;
import com.oshapp.backend.service.HrService;
import com.oshapp.backend.service.FileStorageService;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class HrServiceImpl implements HrService {

    private final SickLeaveCertificateRepository sickLeaveCertificateRepository;
    private final WorkAccidentRepository workAccidentRepository;
    private final EmployeeRepository employeeRepository;
    private final MedicalCertificateRepository medicalCertificateRepository;
    private final FileStorageService fileStorageService;

    public List<MedicalCertificateDTO> getAllMedicalCertificates() {
        return sickLeaveCertificateRepository.findAll().stream()
                .map(MedicalCertificateDTO::new)
                .collect(Collectors.toList());
    }

    public List<UploadedMedicalCertificateDTO> getAllUploadedMedicalCertificates() {
        return medicalCertificateRepository.findAll().stream()
                .map(UploadedMedicalCertificateDTO::new)
                .collect(Collectors.toList());
    }

    @Override
    public List<UploadedMedicalCertificateDTO> getUploadedMedicalCertificatesForEmployee(Long employeeId) {
        if (employeeId == null) {
            throw new IllegalArgumentException("employeeId is required");
        }
        return medicalCertificateRepository.findByEmployee_Id(employeeId).stream()
                .map(UploadedMedicalCertificateDTO::new)
                .collect(Collectors.toList());
    }

    public List<WorkAccidentDTO> getAllWorkAccidents() {
        return workAccidentRepository.findAll().stream()
                .map(WorkAccidentDTO::new)
                .collect(Collectors.toList());
    }

    public void requestMandatoryVisits(List<Long> employeeIds, String visitType) {
        // This is a simplified implementation.
        // A real implementation would involve creating appointments, sending notifications, etc.
        System.out.println("Requesting mandatory visits of type " + visitType + " for employees: " + employeeIds);
    }

    @Override
    @Transactional
    public MedicalCertificate uploadMedicalCertificate(Long employeeId, String certificateType, LocalDate issueDate, MultipartFile file) {
        try {
            if (employeeId == null) {
                throw new IllegalArgumentException("employeeId is required");
            }
            if (file == null || file.isEmpty()) {
                throw new IllegalArgumentException("A non-empty PDF file is required");
            }

            // 1) Persist file to storage and get relative path
            final String storedPath = fileStorageService.storeMedicalCertificate(file, employeeId);

            // 2) Load employee
            final Employee employee = employeeRepository.findById(employeeId)
                    .orElseThrow(() -> new IllegalArgumentException("Employee not found: " + employeeId));

            // 3) Create and persist MedicalCertificate entity
            final MedicalCertificate mc = new MedicalCertificate();
            mc.setEmployee(employee);
            mc.setCertificateType(certificateType != null ? certificateType : "UNKNOWN");
            mc.setIssueDate(issueDate != null ? issueDate : LocalDate.now());
            mc.setFilePath(storedPath);

            return medicalCertificateRepository.save(mc);
        } catch (RuntimeException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new RuntimeException("Failed to upload medical certificate: " + ex.getMessage(), ex);
        }
    }
}
