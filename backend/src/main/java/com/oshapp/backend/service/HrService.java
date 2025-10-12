package com.oshapp.backend.service;

import com.oshapp.backend.dto.MedicalCertificateDTO;
import com.oshapp.backend.dto.UploadedMedicalCertificateDTO;
import com.oshapp.backend.dto.WorkAccidentDTO;
import com.oshapp.backend.model.MedicalCertificate;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;

import java.util.List;

public interface HrService {

    List<MedicalCertificateDTO> getAllMedicalCertificates();
    List<UploadedMedicalCertificateDTO> getAllUploadedMedicalCertificates();
    /**
     * Returns uploaded medical certificates for a specific employee.
     */
    List<UploadedMedicalCertificateDTO> getUploadedMedicalCertificatesForEmployee(Long employeeId);
    List<WorkAccidentDTO> getAllWorkAccidents();
    void requestMandatoryVisits(List<Long> employeeIds, String visitType);

    /**
     * Stores the uploaded certificate PDF and persists a {@code MedicalCertificate} entity linked to the employee.
     *
     * @param employeeId     the target employee id
     * @param certificateType type/category of the certificate (free text or enum token)
     * @param issueDate       issuance date (LocalDate)
     * @param file            PDF file to upload
     */
    MedicalCertificate uploadMedicalCertificate(Long employeeId, String certificateType, LocalDate issueDate, MultipartFile file);
}
