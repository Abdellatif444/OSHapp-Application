package com.oshapp.backend.service;

import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

public interface FileStorageService {
    String storeMedicalCertificate(MultipartFile file, Long employeeId) throws IOException;
    String storeCompanyLogo(MultipartFile file) throws IOException;
}

