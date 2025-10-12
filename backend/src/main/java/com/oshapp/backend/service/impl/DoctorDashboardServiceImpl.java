package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.ActivityDTO;
import com.oshapp.backend.dto.AlertDTO;
import com.oshapp.backend.dto.DoctorDashboardDTO;
import com.oshapp.backend.dto.StatsDTO;
import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.repository.AppointmentRepository;
import com.oshapp.backend.repository.UserRepository;
import com.oshapp.backend.service.EmployeeService;
import com.oshapp.backend.service.DoctorDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DoctorDashboardServiceImpl implements DoctorDashboardService {

    private final AppointmentRepository appointmentRepository;
    private final UserRepository userRepository;
    private final EmployeeService employeeService;

    @Override
    public DoctorDashboardDTO getDashboardData() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        User doctor = userRepository.findByUsernameOrEmail(username, username)
                .orElseThrow(() -> new IllegalStateException("Doctor not found for username: " + username));

        Employee employee = employeeService.getEmployeeByUserId(doctor.getId())
                .orElseGet(() -> employeeService.createEmployeeFromUser(new Employee(doctor)));

        List<Appointment> doctorAppointments = appointmentRepository.findByDoctorId(employee.getId());

        long pendingCount = doctorAppointments.stream().filter(a -> a.getStatus() == AppointmentStatus.REQUESTED_EMPLOYEE).count();
        long proposedCount = doctorAppointments.stream().filter(a -> a.getStatus() == AppointmentStatus.PROPOSED_MEDECIN).count();
        long confirmedCount = doctorAppointments.stream().filter(a -> a.getStatus() == AppointmentStatus.CONFIRMED).count();
        long completedCount = doctorAppointments.stream().filter(a -> a.getStatus() == AppointmentStatus.COMPLETED).count();

        StatsDTO stats = new StatsDTO(pendingCount, proposedCount, confirmedCount, completedCount);

        List<AlertDTO> alerts = doctorAppointments.stream()
                .filter(a -> a.getStatus() == AppointmentStatus.REQUESTED_EMPLOYEE)
                .map(a -> new AlertDTO(
                        String.valueOf(a.getId()),
                        "Rendez-vous en attente",
                                                "Le rendez-vous pour " + a.getEmployee().getFirstName() + " attend votre validation.",
                        a.getCreatedAt().toString(),
                        "high",
                        "/appointments/" + a.getId()))
                .collect(Collectors.toList());

        List<ActivityDTO> activities = doctorAppointments.stream()
                .filter(a -> a.getUpdatedAt().isAfter(LocalDateTime.now().minusDays(7)))
                .filter(a -> a.getEmployee() != null) // Safely skip appointments with no employee
                .map(a -> new ActivityDTO(
                        String.valueOf(a.getId()),
                        "Mise à jour RDV: " + a.getStatus(),
                                                "Patient: " + a.getEmployee().getFirstName(),
                        a.getUpdatedAt().toString(),
                        "APPOINTMENT",
                        "/appointments/" + a.getId()))
                .collect(Collectors.toList());

        return new DoctorDashboardDTO(stats, alerts, activities, 0);
    }
}
