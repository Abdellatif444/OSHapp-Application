package com.oshapp.backend.service.impl;

import com.oshapp.backend.service.FileStorageService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Service
public class FileStorageServiceImpl implements FileStorageService {

    private static final String BASE_DIR = "uploads/medical-certificates";
    private static final String LOGO_DIR = "uploads/company-logos";

    @Override
    public String storeMedicalCertificate(MultipartFile file, Long employeeId) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new IOException("Empty file");
        }
        // Basic content type/extension check
        String contentType = file.getContentType();
        String originalFilename = StringUtils.cleanPath(file.getOriginalFilename() == null ? "file.pdf" : file.getOriginalFilename());
        if (contentType != null && !contentType.toLowerCase().contains("pdf") && !originalFilename.toLowerCase().endsWith(".pdf")) {
            throw new IOException("Only PDF files are allowed");
        }

        Path employeeDir = Paths.get(BASE_DIR, String.valueOf(employeeId)).toAbsolutePath().normalize();
        Files.createDirectories(employeeDir);

        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        String safeName = originalFilename.replaceAll("[^a-zA-Z0-9._-]", "_");
        String unique = UUID.randomUUID().toString().substring(0, 8);
        String filename = timestamp + "_" + unique + "_" + safeName;

        Path target = employeeDir.resolve(filename);
        Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);

        // Return a relative path to be stored in DB
        Path relative = Paths.get(BASE_DIR, String.valueOf(employeeId), filename).normalize();
        return relative.toString().replace('\\', '/');
    }

    @Override
    public String storeCompanyLogo(MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new IOException("Empty file");
        }

        // Validate image content type/extension
        final String contentType = file.getContentType();
        String originalFilename = StringUtils.cleanPath(file.getOriginalFilename() == null ? "logo.png" : file.getOriginalFilename());
        final String lowerName = originalFilename.toLowerCase();
        final boolean looksImage = contentType != null ? contentType.toLowerCase().startsWith("image/") : (lowerName.endsWith(".png") || lowerName.endsWith(".jpg") || lowerName.endsWith(".jpeg"));
        if (!looksImage) {
            throw new IOException("Only image files (PNG/JPG) are allowed");
        }

        // Enforce reasonable size limit (5 MB)
        final long maxSize = 5L * 1024 * 1024;
        if (file.getSize() > maxSize) {
            throw new IOException("File too large (max 5MB)");
        }

        Path logosDir = Paths.get(LOGO_DIR).toAbsolutePath().normalize();
        Files.createDirectories(logosDir);

        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        String safeName = originalFilename.replaceAll("[^a-zA-Z0-9._-]", "_");
        String unique = UUID.randomUUID().toString().substring(0, 8);
        String filename = timestamp + "_" + unique + "_" + safeName;

        Path target = logosDir.resolve(filename);
        Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);

        Path relative = Paths.get(LOGO_DIR, filename).normalize();
        return relative.toString().replace('\\', '/');
    }
}
