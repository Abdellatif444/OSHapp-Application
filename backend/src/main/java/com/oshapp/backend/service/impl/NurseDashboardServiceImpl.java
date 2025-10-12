package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.*;
import com.oshapp.backend.mapper.AppointmentMapper;
import com.oshapp.backend.mapper.NotificationMapper;
import com.oshapp.backend.model.Notification;
import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.repository.AppointmentRepository;
import com.oshapp.backend.repository.EmployeeRepository;
import com.oshapp.backend.repository.NotificationRepository;
import com.oshapp.backend.security.UserPrincipal;
import com.oshapp.backend.service.NurseDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class NurseDashboardServiceImpl implements NurseDashboardService {

    private final EmployeeRepository employeeRepository;
    private final AppointmentRepository appointmentRepository;
    private final NotificationRepository notificationRepository;
    private final AppointmentMapper appointmentMapper;
    private final NotificationMapper notificationMapper;

    @Override
    @Transactional(readOnly = true)
    public NurseDashboardDTO getDashboardData() {
        UserPrincipal currentUser = (UserPrincipal) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

                EmployeeProfileDTO employeeProfileDTO = employeeRepository.findByUserId(currentUser.getId())
                .map(EmployeeProfileDTO::new)
                .orElseThrow(() -> new RuntimeException("Employee not found for user"));

        // Count all appointments for nurse dashboard - include unassigned pending requests
        // Pending should include both employee-requested and HR-initiated obligatory visits
        List<AppointmentStatus> pendingStatuses = List.of(AppointmentStatus.REQUESTED_EMPLOYEE, AppointmentStatus.OBLIGATORY);
        long pendingCount = appointmentRepository.countByStatusIn(pendingStatuses);
        long proposedCount = appointmentRepository.countByNurseIdAndStatusIn(currentUser.getId(), List.of(AppointmentStatus.PROPOSED_MEDECIN));
        long confirmedCount = appointmentRepository.countByNurseIdAndStatusIn(currentUser.getId(), List.of(AppointmentStatus.CONFIRMED));
        long completedCount = appointmentRepository.countByNurseIdAndStatusIn(currentUser.getId(), List.of(AppointmentStatus.COMPLETED));

        StatsDTO statsDTO = new StatsDTO(pendingCount, proposedCount, confirmedCount, completedCount);

        List<AppointmentResponseDTO> pendingAppointments = appointmentRepository
                .findByStatusIn(pendingStatuses, org.springframework.data.domain.Pageable.unpaged())
                .getContent()
                .stream()
                .map(appointmentMapper::toDto)
                .collect(Collectors.toList());

        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = LocalDate.now().atTime(23, 59, 59);
        List<AppointmentResponseDTO> todayAppointments = appointmentRepository.findByNurseIdAndStatusAndScheduledTimeBetween(currentUser.getId(), AppointmentStatus.CONFIRMED, startOfDay, endOfDay).stream()
                .map(appointmentMapper::toDto)
                .collect(Collectors.toList());

        List<Notification> notifications = notificationRepository.findByUserId(currentUser.getId());
        int unreadNotifications = (int) notifications.stream().filter(n -> !n.isRead()).count();
        List<NotificationResponseDTO> notificationDTOs = notifications.stream()
                .map(notificationMapper::toDto)
                .collect(Collectors.toList());

        // Compute visit-type distribution for incoming entries: pending + proposed (awaiting employee reply)
        List<AppointmentStatus> entryStatuses = List.of(
                AppointmentStatus.REQUESTED_EMPLOYEE,
                AppointmentStatus.OBLIGATORY,
                AppointmentStatus.PROPOSED_MEDECIN
        );
        List<Object[]> typeRows = appointmentRepository.countByTypeForStatuses(entryStatuses);
        Map<String, Long> visitTypeCounts = new HashMap<>();
        // Initialize known keys to 0 for frontend stability
        visitTypeCounts.put("reprise", 0L);
        visitTypeCounts.put("embauche", 0L);
        visitTypeCounts.put("spontane", 0L);
        visitTypeCounts.put("periodique", 0L);
        visitTypeCounts.put("surveillance", 0L);
        visitTypeCounts.put("appel_medecin", 0L);
        for (Object[] row : typeRows) {
            if (row == null || row.length < 2) continue;
            AppointmentType type = (AppointmentType) row[0];
            Long cnt = (Long) row[1];
            String key = mapTypeKey(type);
            if (key != null) {
                visitTypeCounts.put(key, cnt);
            }
        }

        return new NurseDashboardDTO(
                employeeProfileDTO,
                statsDTO,
                pendingAppointments,
                todayAppointments,
                unreadNotifications,
                notificationDTOs,
                visitTypeCounts
        );
    }

    private String mapTypeKey(AppointmentType type) {
        if (type == null) return null;
        switch (type) {
            case RETURN_TO_WORK:
                return "reprise";
            case PRE_RECRUITMENT:
                return "embauche";
            case SPONTANEOUS:
                return "spontane";
            case PERIODIC:
                return "periodique";
            case SURVEILLANCE_PARTICULIERE:
                return "surveillance";
            case MEDICAL_CALL:
                return "appel_medecin";
            case OTHER:
            default:
                return null; // ignore for now
        }
    }
}
