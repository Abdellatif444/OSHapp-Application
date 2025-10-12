package com.oshapp.backend.repository;

import com.oshapp.backend.model.WorkAccident;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface WorkAccidentRepository extends JpaRepository<WorkAccident, Long> {

    /**
     * Finds all work accidents that occurred after a given date, ordered by the most recent first.
     *
     * @param date The date to compare against.
     * @return A list of recent work accidents.
     */
    List<WorkAccident> findByAccidentDateAfterOrderByAccidentDateDesc(LocalDateTime date);

    List<WorkAccident> findByEmployeeId(Long employeeId);
}
