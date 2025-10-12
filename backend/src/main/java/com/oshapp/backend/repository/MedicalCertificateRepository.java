package com.oshapp.backend.repository;

import com.oshapp.backend.model.MedicalCertificate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface MedicalCertificateRepository extends JpaRepository<MedicalCertificate, Long> {

    /**
     * Finds all medical certificates that are due to expire on or before the given date.
     *
     * @param expirationDate The date to compare against.
     * @return A list of medical certificates nearing expiration.
     */
    @Query("SELECT mc FROM MedicalCertificate mc WHERE mc.expirationDate <= :expirationDate")
    List<MedicalCertificate> findByExpirationDateBeforeOrEqual(@Param("expirationDate") LocalDate expirationDate);

    /**
     * Fetch all medical certificates for a given employee ID.
     */
    List<MedicalCertificate> findByEmployee_Id(Long employeeId);

}

