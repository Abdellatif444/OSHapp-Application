package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.ActivityDTO;
import com.oshapp.backend.dto.AlertDTO;
import com.oshapp.backend.dto.HseDashboardDTO;
import com.oshapp.backend.dto.HseStatsDTO;
import com.oshapp.backend.model.WorkAccident;
import com.oshapp.backend.repository.WorkAccidentRepository;
import com.oshapp.backend.service.HseDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class HseDashboardServiceImpl implements HseDashboardService {

    private final WorkAccidentRepository workAccidentRepository;

    @Override
    public HseDashboardDTO getDashboardData() {
        // Load all accidents for stats
        List<WorkAccident> allAccidents = workAccidentRepository.findAll();

        long totalAccidents = allAccidents.size();
        long totalIncidents = allAccidents.stream()
                .filter(a -> a.getStatus() == WorkAccident.AccidentStatus.REPORTED)
                .count();
        long riskAnalyses = allAccidents.stream()
                .filter(a -> a.getStatus() == WorkAccident.AccidentStatus.INVESTIGATING)
                .count();
        long completedTasks = allAccidents.stream()
                .filter(a -> a.getStatus() == WorkAccident.AccidentStatus.CLOSED)
                .count();

        HseStatsDTO stats = new HseStatsDTO(totalIncidents, totalAccidents, riskAnalyses, completedTasks);

        // Recent alerts for last 30 days, prioritize by severity
        LocalDateTime thirtyDaysAgo = LocalDateTime.now().minusDays(30);
        List<WorkAccident> recentAccidents = workAccidentRepository
                .findByAccidentDateAfterOrderByAccidentDateDesc(thirtyDaysAgo);

        List<AlertDTO> alerts = recentAccidents.stream()
                .map(acc -> new AlertDTO(
                        String.valueOf(acc.getId()),
                        "Accident de travail déclaré",
                        String.format("Sévérité: %s - %s", 
                                acc.getSeverity() != null ? acc.getSeverity().name() : "UNKNOWN",
                                acc.getDescription() != null ? acc.getDescription() : ""),
                        acc.getAccidentDate().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                        mapSeverity(acc.getSeverity()),
                        String.format("/accidents/%d", acc.getId())
                ))
                .collect(Collectors.toList());

        // Activities for last 30 days
        List<ActivityDTO> activities = recentAccidents.stream()
                .map(acc -> new ActivityDTO(
                        String.valueOf(acc.getId()),
                        "Accident déclaré",
                        String.format("Employé: %s %s - Sévérité: %s",
                                acc.getEmployee() != null ? acc.getEmployee().getFirstName() : "",
                                acc.getEmployee() != null ? acc.getEmployee().getLastName() : "",
                                acc.getSeverity() != null ? acc.getSeverity().name() : "UNKNOWN"),
                        acc.getAccidentDate().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                        "ACCIDENT",
                        String.format("/accidents/%d", acc.getId())
                ))
                .collect(Collectors.toList());

        return new HseDashboardDTO(stats, alerts, activities);
    }

    private String mapSeverity(WorkAccident.AccidentSeverity severity) {
        if (severity == null) return "INFO";
        return switch (severity) {
            case SEVERE -> "DANGER";
            case MODERATE -> "WARNING";
            case MINOR -> "INFO";
        };
    }
}
