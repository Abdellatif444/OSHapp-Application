package com.oshapp.backend.repository;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.enums.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import com.oshapp.backend.model.User ;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface AppointmentRepository extends JpaRepository<Appointment, Long> {
    
    @Query("SELECT a FROM Appointment a WHERE a.employee.user.id = :userId")
    Page<Appointment> findByEmployeeUserId(@Param("userId") Long userId, Pageable pageable);
    
    @Query("SELECT a FROM Appointment a WHERE a.employee.user.id = :userId")
    List<Appointment> findByEmployeeUserId(@Param("userId") Long userId);

    @Query("SELECT a FROM Appointment a JOIN FETCH a.employee e JOIN FETCH e.user WHERE e.user = :user") //LEFT JOIN FETCH a.comments
    Page<Appointment> findByEmployeeUser(@Param("user") User user, Pageable pageable);
    
    @Query("SELECT a FROM Appointment a JOIN FETCH a.employee e JOIN FETCH e.user WHERE e.user = :user AND a.status NOT IN :excluded")
    Page<Appointment> findByEmployeeUserExcludingStatuses(@Param("user") User user, @Param("excluded") List<AppointmentStatus> excluded, Pageable pageable);
    
    @Query("SELECT a FROM Appointment a WHERE a.employee.user.id = :userId AND a.status = :status")
    List<Appointment> findByEmployeeUserIdAndStatus(@Param("userId") Long userId, @Param("status") AppointmentStatus status);
    
    @Query("SELECT a FROM Appointment a WHERE a.employee.user.id = :userId AND a.scheduledTime >= :now ORDER BY a.scheduledTime ASC")
    List<Appointment> findUpcomingByEmployeeUserId(@Param("userId") Long userId, @Param("now") LocalDateTime now);
    
    @Query("SELECT a FROM Appointment a WHERE a.nurse.id = :userId OR a.doctor.id = :userId")
    Page<Appointment> findByMedicalStaff(@Param("userId") Long userId, Pageable pageable);
    
    @Query(value = "SELECT a FROM Appointment a WHERE " +
            "(:type IS NULL OR a.type = :type) AND " +
            "(:statuses IS NULL OR a.status IN :statuses) AND " +
            "(:visitMode IS NULL OR a.visitMode = :visitMode) AND " +
            "(:employeeId IS NULL OR a.employee.id = :employeeId) AND " +
            "(CAST(:dateFrom AS java.time.LocalDateTime) IS NULL OR a.scheduledTime >= :dateFrom) AND " +
            "(CAST(:dateTo AS java.time.LocalDateTime) IS NULL OR a.scheduledTime <= :dateTo)")
    Page<Appointment> findWithFilters(
            @Param("type") AppointmentType type,
            @Param("statuses") List<AppointmentStatus> statuses,
            @Param("visitMode") VisitMode visitMode,
            @Param("employeeId") Long employeeId,
            @Param("dateFrom") LocalDateTime dateFrom,
            @Param("dateTo") LocalDateTime dateTo,
            Pageable pageable);

    @Query("SELECT FUNCTION('date_part', 'year', a.scheduledTime) as year, FUNCTION('date_part', 'month', a.scheduledTime) as month, COUNT(a) as count " +
           "FROM Appointment a " +
           "WHERE a.scheduledTime IS NOT NULL " +
           "GROUP BY FUNCTION('date_part', 'year', a.scheduledTime), FUNCTION('date_part', 'month', a.scheduledTime) " +
           "ORDER BY FUNCTION('date_part', 'year', a.scheduledTime), FUNCTION('date_part', 'month', a.scheduledTime)")
    List<Object[]> countAppointmentsByMonth();

    // Nouvelles requêtes pour le workflow OSHapp complet
    
    @Query("SELECT a FROM Appointment a WHERE a.employee = :employee")
    List<Appointment> findByEmployee(@Param("employee") com.oshapp.backend.model.Employee employee);
    
    @Query("SELECT a FROM Appointment a WHERE a.nurse = :nurse OR a.status IN :statuses")
    List<Appointment> findByNurseOrStatusIn(@Param("nurse") com.oshapp.backend.model.User nurse, @Param("statuses") List<AppointmentStatus> statuses);
    
    @Query("SELECT a FROM Appointment a WHERE a.doctor = :doctor OR a.status IN :statuses")
    List<Appointment> findByDoctorOrStatusIn(@Param("doctor") com.oshapp.backend.model.User doctor, @Param("statuses") List<AppointmentStatus> statuses);
    
    @Query("SELECT COUNT(a) FROM Appointment a WHERE a.status = :status")
    long countByStatus(@Param("status") AppointmentStatus status);

    @Query("SELECT COUNT(a) FROM Appointment a WHERE a.type = :type AND a.status = :status")
    long countByTypeAndStatus(@Param("type") AppointmentType type, @Param("status") AppointmentStatus status);
    
    @Query("SELECT a FROM Appointment a WHERE a.status = :status")
    List<Appointment> findByStatus(@Param("status") AppointmentStatus status);
    
    @Query("SELECT a FROM Appointment a WHERE a.isObligatory = true")
    List<Appointment> findMandatoryAppointments();
    
    @Query("SELECT a FROM Appointment a WHERE a.employee.manager1.user = :manager OR a.employee.manager2.user = :manager")
    List<Appointment> findByManager(@Param("manager") com.oshapp.backend.model.User manager);
    
    @Query("SELECT a FROM Appointment a WHERE a.scheduledTime BETWEEN :startDate AND :endDate")
    List<Appointment> findByDateRange(
            @Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate
    );

    List<Appointment> findByEmployeeId(Long employeeId);

    List<Appointment> findByDoctorId(Long doctorId);

    List<Appointment> findByNurseId(Long nurseId);

    @Query("SELECT a FROM Appointment a WHERE a.nurse.id = :nurseId AND a.status = :status")
    List<Appointment> findByNurseIdAndStatus(@Param("nurseId") Long nurseId, @Param("status") AppointmentStatus status);

    @Query("SELECT a FROM Appointment a WHERE a.nurse.id = :nurseId AND a.status IN :statuses")
    List<Appointment> findByNurseIdAndStatusIn(@Param("nurseId") Long nurseId, @Param("statuses") List<AppointmentStatus> statuses);
    
    @Query("SELECT COUNT(a) FROM Appointment a WHERE a.nurse.id = :nurseId AND a.status IN :statuses")
    long countByNurseIdAndStatusIn(@Param("nurseId") Long nurseId, @Param("statuses") List<AppointmentStatus> statuses);

    @Query("SELECT COUNT(a) FROM Appointment a WHERE a.status IN :statuses")
    long countByStatusIn(@Param("statuses") List<AppointmentStatus> statuses);

    
    @Query("SELECT a FROM Appointment a WHERE a.status IN :statuses AND a.scheduledTime >= :now ORDER BY a.scheduledTime ASC")
    List<Appointment> findUpcomingByStatuses(@Param("statuses") List<AppointmentStatus> statuses, @Param("now") LocalDateTime now);

    @Query("SELECT a FROM Appointment a WHERE a.status = :status AND a.scheduledTime BETWEEN :start AND :end")
    List<Appointment> findByStatusAndScheduledTimeBetween(
            @Param("status") AppointmentStatus status,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end);

    List<Appointment> findByNurseIdAndStatusAndScheduledTimeBetween(
            @Param("nurseId") Long nurseId,
            @Param("status") AppointmentStatus status,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end
    );

    Page<Appointment> findByStatusIn(List<AppointmentStatus> statuses, Pageable pageable);
    
    List<Appointment> findByCreatedAtAfterOrderByCreatedAtDesc(LocalDateTime createdAfter);

    // Aggregate counts by appointment type for a set of statuses (e.g., pending-like entries)
    @Query("SELECT a.type as type, COUNT(a) as cnt FROM Appointment a WHERE a.status IN :statuses GROUP BY a.type")
    List<Object[]> countByTypeForStatuses(@Param("statuses") List<AppointmentStatus> statuses);
}