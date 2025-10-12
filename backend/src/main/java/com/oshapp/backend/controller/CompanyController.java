package com.oshapp.backend.controller;

import com.oshapp.backend.model.Company;
import com.oshapp.backend.service.CompanyService;
import com.oshapp.backend.service.FileStorageService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@RestController
@RequestMapping("/api/v1/company-profile")
public class CompanyController {

    @Autowired
    private CompanyService companyService;
    
    @Autowired
    private FileStorageService fileStorageService;

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'HR')")
    public ResponseEntity<Company> getCompanyProfile() {
        return companyService.getCompanyProfile()
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Company> updateCompanyProfile(@RequestBody Company companyDetails) {
        try {
            Company updatedCompany = companyService.updateCompanyProfile(companyDetails);
            return ResponseEntity.ok(updatedCompany);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @PostMapping(value = "/logo", consumes = {"multipart/form-data"})
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Company> uploadCompanyLogo(@RequestParam("file") MultipartFile file) {
        try {
            String storedPath = fileStorageService.storeCompanyLogo(file);
            Company updated = companyService.updateCompanyLogo(storedPath);
            return ResponseEntity.ok(updated);
        } catch (IOException e) {
            return ResponseEntity.badRequest().build();
        }
    }
}


