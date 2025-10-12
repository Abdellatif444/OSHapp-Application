package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.ActivityDTO;
import com.oshapp.backend.dto.AlertDTO;
import com.oshapp.backend.model.MedicalCertificate;
import com.oshapp.backend.model.WorkAccident;
import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.repository.*;
import com.oshapp.backend.service.StatisticsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class StatisticsServiceImpl implements StatisticsService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AppointmentRepository appointmentRepository;

    @Autowired
    private EmployeeRepository employeeRepository;

    @Autowired
    private MedicalCertificateRepository medicalCertificateRepository;

    @Autowired
    private WorkAccidentRepository workAccidentRepository;

    @Override
    public Map<String, Object> getAdminDashboardStatistics() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("userRoleDistribution", getUserRoleDistribution());
        stats.put("monthlyAppointmentActivity", getMonthlyAppointmentActivity());
        return stats;
    }

    @Override
    public Map<String, Object> getRhDashboardStatistics() {
        Map<String, Object> stats = new HashMap<>();
        LocalDate thirtyDaysFromNow = LocalDate.now().plusDays(30);

        stats.put("totalEmployees", employeeRepository.count());
        stats.put("pendingRequests", appointmentRepository.countByStatus(AppointmentStatus.REQUESTED_EMPLOYEE));
        stats.put("returnToWorkVisits", appointmentRepository.countByTypeAndStatus(AppointmentType.RETURN_TO_WORK, AppointmentStatus.CONFIRMED));
        stats.put("expiringCertificates", medicalCertificateRepository.findByExpirationDateBeforeOrEqual(thirtyDaysFromNow).size());
        stats.put("recentAccidents", workAccidentRepository.findByAccidentDateAfterOrderByAccidentDateDesc(LocalDateTime.now().minusDays(30)).size());
        return stats;
    }

    @Override
    public List<AlertDTO> getRhDashboardAlerts() {
        List<AlertDTO> alerts = new ArrayList<>();
        LocalDate thirtyDaysFromNow = LocalDate.now().plusDays(30);
        
        // 1. Add expiring medical certificates alerts
        List<MedicalCertificate> expiringCertificates = medicalCertificateRepository.findByExpirationDateBeforeOrEqual(thirtyDaysFromNow);
        alerts.addAll(expiringCertificates.stream()
                .map(cert -> new AlertDTO(
                        cert.getId().toString(),
                        "Certificat arrivant à expiration",
                        String.format("Le certificat de %s %s expire le %s.",
                                cert.getEmployee().getFirstName(),
                                cert.getEmployee().getLastName(),
                                cert.getExpirationDate().format(DateTimeFormatter.ISO_LOCAL_DATE)),
                        cert.getExpirationDate().format(DateTimeFormatter.ISO_LOCAL_DATE),
                        "WARNING",
                        String.format("/employees/%d/certificates", cert.getEmployee().getId())))
                .collect(Collectors.toList()));

        // 2. Add recent appointment requests for RH supervision
        LocalDateTime sevenDaysAgo = LocalDateTime.now().minusDays(7);
        appointmentRepository.findByCreatedAtAfterOrderByCreatedAtDesc(sevenDaysAgo).forEach(appointment -> {
            if (appointment.getStatus() == AppointmentStatus.REQUESTED_EMPLOYEE) {
                String employeeName = String.format("%s %s", 
                    appointment.getEmployee().getFirstName(), 
                    appointment.getEmployee().getLastName());
                String employeeEmail = appointment.getEmployee().getUser() != null ? 
                    appointment.getEmployee().getUser().getEmail() : null;
                
                // Format detailed message like nurse notifications
                StringBuilder description = new StringBuilder();
                description.append(String.format("Nouvelle demande de rendez-vous : [%s", employeeName));
                if (employeeEmail != null) {
                    description.append(String.format(" (%s)", employeeEmail));
                }
                description.append("]");
                
                // Add appointment date if available
                if (appointment.getRequestedDateEmployee() != null) {
                    description.append(String.format(", le %s", 
                        appointment.getRequestedDateEmployee().format(DateTimeFormatter.ofPattern("dd/MM/yyyy 'à' HH:mm"))));
                } else if (appointment.getScheduledTime() != null) {
                    description.append(String.format(", le %s", 
                        appointment.getScheduledTime().format(DateTimeFormatter.ofPattern("dd/MM/yyyy 'à' HH:mm"))));
                }
                
                // For RH notifications, do not display motif and notes (privacy/confidentiality)

                alerts.add(new AlertDTO(
                    appointment.getId().toString(),
                    "Nouvelle demande de rendez-vous",
                    description.toString(),
                    appointment.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                    "INFO",
                    String.format("/appointments/%d", appointment.getId())
                ));
            }
        });

        return alerts;
    }

    @Override
    public List<ActivityDTO> getRhDashboardActivities() {
        List<ActivityDTO> activities = new ArrayList<>();
        LocalDateTime sevenDaysAgo = LocalDateTime.now().minusDays(7);

        // Fetch recent accidents
        List<WorkAccident> recentAccidents = workAccidentRepository.findByAccidentDateAfterOrderByAccidentDateDesc(sevenDaysAgo);
        activities.addAll(recentAccidents.stream()
                .map(acc -> new ActivityDTO(
                        acc.getId().toString(),
                        "Accident de travail déclaré",
                        String.format("Un accident de type '%s' pour %s %s.",
                                acc.getSeverity(),
                                acc.getEmployee().getFirstName(),
                                acc.getEmployee().getLastName()),
                        acc.getAccidentDate().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                        "ACCIDENT_REPORTED",
                        String.format("/accidents/%d", acc.getId())))
                .toList());

        // Fetch new employees
        LocalDate sevenDaysAgoDate = LocalDate.now().minusDays(7);
        employeeRepository.findByHireDateAfterOrderByHireDateDesc(sevenDaysAgoDate).forEach(emp -> {
            activities.add(new ActivityDTO(
                    emp.getId().toString(),
                    "Nouvel employé",
                    String.format("%s %s a rejoint l'entreprise.", emp.getFirstName(), emp.getLastName()),
                    emp.getHireDate().format(DateTimeFormatter.ISO_LOCAL_DATE),
                    "NEW_EMPLOYEE",
                    String.format("/employees/%d", emp.getId())
            ));
        });

        return activities;
    }

    private Map<String, Long> getUserRoleDistribution() {
        List<Object[]> rawData = userRepository.countUsersByRoleRaw();
        Map<String, Long> distribution = new HashMap<>();
        for (Object[] row : rawData) {
            String roleName = ((Enum<?>) row[0]).name();
            Long count = (Long) row[1];
            distribution.put(roleName, count);
        }
        return distribution;
    }

    private List<Map<String, Object>> getMonthlyAppointmentActivity() {
        List<Object[]> rawData = appointmentRepository.countAppointmentsByMonth();
        List<Map<String, Object>> activity = new java.util.ArrayList<>();
        for (Object[] row : rawData) {
            Map<String, Object> monthData = new HashMap<>();
            monthData.put("year", row[0]);
            monthData.put("month", row[1]);
            monthData.put("count", row[2]);
            activity.add(monthData);
        }
        return activity;
    }
}
