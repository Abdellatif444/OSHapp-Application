package com.oshapp.backend.repository;

import com.oshapp.backend.model.SickLeaveCertificate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SickLeaveCertificateRepository extends JpaRepository<SickLeaveCertificate, Long> {
    List<SickLeaveCertificate> findByEmployeeId(Long employeeId);
}
