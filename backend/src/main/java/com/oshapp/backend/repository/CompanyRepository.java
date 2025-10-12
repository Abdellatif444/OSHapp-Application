package com.oshapp.backend.repository;

import com.oshapp.backend.model.Company;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CompanyRepository extends JpaRepository<Company, Long> {

    /**
     * Finds the first company entry in the database.
     * Since there should only be one company profile, this is a convenient way to retrieve it.
     * @return an Optional containing the Company if found, otherwise empty.
     */
    default Optional<Company> findFirst() {
        return findAll().stream().findFirst();
    }
}
