package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.*;
import com.oshapp.backend.exception.ResourceNotFoundException;
import com.oshapp.backend.mapper.AppointmentMapper;
import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.AppointmentComment;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.model.enums.RoleName;
import com.oshapp.backend.model.enums.VisitMode;
import com.oshapp.backend.repository.AppointmentRepository;
import com.oshapp.backend.repository.EmployeeRepository;
import com.oshapp.backend.repository.UserRepository;
import com.oshapp.backend.service.AppointmentService;
import com.oshapp.backend.service.MultiChannelNotificationService;
import com.oshapp.backend.service.notifications.NotificationActor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
public class AppointmentServiceImpl implements AppointmentService {

    private final AppointmentRepository appointmentRepository;
    private final AppointmentMapper appointmentMapper;
    private final UserRepository userRepository;
    private final EmployeeRepository employeeRepository;
    private final MultiChannelNotificationService multiChannelNotificationService;

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    private String formatDateTime(LocalDateTime dt) {
        return dt != null ? dt.format(FMT) : "";
    }
    
    private String getCurrentUserPhone(User user) {
        // Récupérer le numéro de téléphone depuis le profil utilisateur
        if (user != null && user.getPhoneNumber() != null && !user.getPhoneNumber().trim().isEmpty()) {
            return user.getPhoneNumber();
        }
        // Fallback: utiliser le téléphone du profil employé rattaché (s'il existe)
        try {
            if (user != null && user.getEmployee() != null && user.getEmployee().getPhoneNumber() != null
                && !user.getEmployee().getPhoneNumber().trim().isEmpty()) {
                return user.getEmployee().getPhoneNumber();
            }
        } catch (Exception e) {
            log.warn("Unable to resolve employee phone for user {}: {}", user != null ? user.getId() : null, e.getMessage());
        }
        // Fallback par défaut pour le service médical
        return "+212 6 XX XX XX XX";
    }

    // Préférer le numéro de l'infirmier(e) assigné(e) comme contact du service médical
    private String resolveMedicalServicePhone(Appointment appointment, User currentUser) {
        try {
            if (appointment != null && appointment.getNurse() != null) {
                String nursePhone = appointment.getNurse().getPhoneNumber();
                if (nursePhone != null && !nursePhone.trim().isEmpty()) {
                    return nursePhone;
                }
                // Essayer le numéro de téléphone de l'employé lié à l'infirmier(e)
                if (appointment.getNurse().getEmployee() != null) {
                    String nurseEmployeePhone = appointment.getNurse().getEmployee().getPhoneNumber();
                    if (nurseEmployeePhone != null && !nurseEmployeePhone.trim().isEmpty()) {
                        return nurseEmployeePhone;
                    }
                }
            }
        } catch (Exception e) {
            log.warn("Unable to resolve nurse phone for appointment {}: {}", 
                appointment != null ? appointment.getId() : null, e.getMessage());
        }
        // Si aucun(e) infirmier(e) avec téléphone n'est disponible, conserver la valeur existante ou utiliser le téléphone de l'utilisateur courant
        String existing = appointment != null ? appointment.getMedicalServicePhone() : null;
        if (existing != null && !existing.trim().isEmpty()) {
            return existing;
        }
        return getCurrentUserPhone(currentUser);
    }

    private boolean canSeePrivateInfo(User user, Appointment appointment) {
        if (user == null || user.getRoles() == null) return false;
        
        // Employé propriétaire du rendez-vous peut voir les consignes
        if (appointment.getEmployee() != null && 
            appointment.getEmployee().getUser() != null &&
            appointment.getEmployee().getUser().getId().equals(user.getId())) {
            return true;
        }
        
        // Personnel médical peut voir les consignes
        return user.getRoles().stream().anyMatch(r -> 
            r.getName() == RoleName.ROLE_NURSE || r.getName() == RoleName.ROLE_DOCTOR);
    }

    private User getCurrentUser() {
        String emailCurrentUser = SecurityContextHolder.getContext().getAuthentication().getName();
        return userRepository.findByUsernameOrEmail(emailCurrentUser, emailCurrentUser)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + emailCurrentUser));
    }

    private void applyPrivacyRules(AppointmentResponseDTO dto, Appointment appointment, User currentUser) {
        boolean canSeePrivate = canSeePrivateInfo(currentUser, appointment);
        
        // RH ne peut pas voir les consignes médicales et le numéro du service médical
        if (!canSeePrivate) {
            dto.setMedicalInstructions(null);
            dto.setMedicalServicePhone(null);
        }
    }
    
    private void applyPrivacyAndActionRules(AppointmentResponseDTO dto, Appointment appointment, User currentUser) {
        // Appliquer les règles de confidentialité
        applyPrivacyRules(dto, appointment, currentUser);
        
        // Déterminer les actions disponibles selon le rôle et le statut
        boolean isEmployee = appointment.getEmployee() != null 
            && appointment.getEmployee().getUser() != null 
            && appointment.getEmployee().getUser().getId().equals(currentUser.getId());
        
        boolean isMedicalStaff = currentUser.getRoles() != null && currentUser.getRoles().stream()
            .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE || r.getName() == RoleName.ROLE_DOCTOR);
        
        AppointmentStatus status = appointment.getStatus();
        
        // Employé peut confirmer/annuler ses visites médicales planifiées
        if (isEmployee) {
            if (status == AppointmentStatus.PLANNED_BY_MEDICAL_STAFF || status == AppointmentStatus.PROPOSED_MEDECIN) {
                dto.setCanConfirm(true);
                dto.setCanCancel(true);
            } else if (status == AppointmentStatus.CONFIRMED) {
                dto.setCanCancel(false);
            }
        }
        
        // Personnel médical peut proposer des créneaux et commenter
        if (isMedicalStaff) {
            if (status == AppointmentStatus.REQUESTED_EMPLOYEE) {
                dto.setCanConfirm(true);
                dto.setCanPropose(true);
            } else if (status == AppointmentStatus.OBLIGATORY || status == AppointmentStatus.PROPOSED_MEDECIN) {
                dto.setCanPropose(true);
            }
            dto.setCanComment(true);
        }
    }

    @Override
    public List<AppointmentResponseDTO> getAllAppointments() {
        User currentUser = getCurrentUser();
        List<Appointment> appointments = appointmentRepository.findAll();
        return appointments.stream()
                .map(appointment -> {
                    AppointmentResponseDTO dto = appointmentMapper.toDto(appointment);
                    applyPrivacyAndActionRules(dto, appointment, currentUser);
                    return dto;
                })
                .collect(java.util.stream.Collectors.toList());
    }

    @Override
    public AppointmentResponseDTO getAppointmentById(Long id) {
        Appointment appointment = appointmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found with id: " + id));
        AppointmentResponseDTO dto = appointmentMapper.toDto(appointment);
        applyPrivacyAndActionRules(dto, appointment, getCurrentUser());
        return dto;
    }

    @Override
    @Transactional
    public AppointmentResponseDTO planMedicalVisit(PlanMedicalVisitRequestDTO planRequest) {
        User currentUser = getCurrentUser();
        
        // Vérifier que l'utilisateur actuel est du personnel médical
        boolean hasMedicalRole = currentUser.getRoles() != null && currentUser.getRoles().stream()
                .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE || r.getName() == RoleName.ROLE_DOCTOR);
        
        if (!hasMedicalRole) {
            throw new IllegalStateException("Only medical staff can plan medical visits.");
        }
        
        // Récupérer l'employé
        Employee employee = employeeRepository.findById(planRequest.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Employee not found with id: " + planRequest.getEmployeeId()));
        
        // Récupérer automatiquement le numéro de téléphone du service médical
        String medicalServicePhone = getCurrentUserPhone(currentUser);
        
        // Créer le rendez-vous planifié par le service médical
        Appointment appointment = Appointment.builder()
                .employee(employee)
                .type(planRequest.getType())
                .status(AppointmentStatus.PLANNED_BY_MEDICAL_STAFF)
                .scheduledTime(planRequest.getScheduledDateTime())
                .visitMode(planRequest.getVisitMode())
                .medicalInstructions(planRequest.getMedicalInstructions())
                .medicalServicePhone(medicalServicePhone)
                .createdBy(currentUser)
                .updatedBy(currentUser)
                .build();
                
        // Assigner le personnel médical
        if (currentUser.getRoles().stream().anyMatch(r -> r.getName() == RoleName.ROLE_NURSE)) {
            appointment.setNurse(currentUser);
        }
        if (currentUser.getRoles().stream().anyMatch(r -> r.getName() == RoleName.ROLE_DOCTOR)) {
            appointment.setDoctor(currentUser);
        }
        // Préférer le téléphone de l'infirmier(e) assigné(e) si disponible
        appointment.setMedicalServicePhone(resolveMedicalServicePhone(appointment, currentUser));
        
        Appointment savedAppointment = appointmentRepository.save(appointment);
        
        // Notifier tous les acteurs avec le nouveau scénario
        try {
            Set<User> actorsToNotify = getAllActorsToNotify(savedAppointment);
            if (!actorsToNotify.isEmpty()) {
                log.info("Sending MEDICAL_VISIT_PLANNED notifications for appointment type: {} to {} users", 
                        savedAppointment.getType(), actorsToNotify.size());
                multiChannelNotificationService.notifyUsers(new ArrayList<>(actorsToNotify), savedAppointment, "MEDICAL_VISIT_PLANNED", null);
            }
        } catch (Exception e) {
            log.error("Error sending notifications for medical visit planning (type: {}): {}", 
                     savedAppointment.getType(), e.getMessage(), e);
            // Continue execution - don't fail the appointment creation due to notification issues
        }
        
        AppointmentResponseDTO dto = appointmentMapper.toDto(savedAppointment);
        applyPrivacyAndActionRules(dto, savedAppointment, currentUser);
        return dto;
    }

    @Override
    @Transactional
    public AppointmentResponseDTO employeeConfirmAppointment(Long appointmentId) {
        User currentUser = getCurrentUser();
        Appointment appointment = appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found with id: " + appointmentId));

        // Authorization Check: Ensure the current user is the employee for this appointment
        if (!appointment.getEmployee().getUser().getId().equals(currentUser.getId())) {
            throw new IllegalStateException("You are not authorized to confirm this appointment.");
        }

        AppointmentStatus currentStatus = appointment.getStatus();
        if (currentStatus != AppointmentStatus.PROPOSED_MEDECIN && currentStatus != AppointmentStatus.PLANNED_BY_MEDICAL_STAFF) {
            throw new IllegalStateException("Appointment cannot be confirmed from its current state: " + currentStatus);
        }

        appointment.setStatus(AppointmentStatus.CONFIRMED);
        appointment.setUpdatedBy(currentUser);
        
        // Set final appointment date
        if (currentStatus == AppointmentStatus.PROPOSED_MEDECIN) {
            appointment.setScheduledTime(appointment.getProposedDate());
            // Keep proposedDate for historical tracking - don't set to null
        }
        
        Appointment updatedAppointment = appointmentRepository.save(appointment);

        // Determine recipients: if obligatory and confirmed by employee, notify only RH and medical staff
        Set<User> recipientsConfirm = new HashSet<>();
        if (updatedAppointment.isObligatory()) {
            try {
                // RH users
                Set<User> rhUsers = userRepository.findByRoles_Name(RoleName.ROLE_RH);
                if (rhUsers != null) recipientsConfirm.addAll(rhUsers);
            } catch (Exception ignored) {}
            try {
                // All nurses and doctors
                Set<User> nurses = userRepository.findByRoles_Name(RoleName.ROLE_NURSE);
                if (nurses != null) recipientsConfirm.addAll(nurses);
                Set<User> doctors = userRepository.findByRoles_Name(RoleName.ROLE_DOCTOR);
                if (doctors != null) recipientsConfirm.addAll(doctors);
            } catch (Exception ignored) {}
        } else {
            recipientsConfirm = getAllActorsToNotify(updatedAppointment);
        }

        // Use medical visit specific scenario if appointment was planned by medical staff
        String notificationScenario = (currentStatus == AppointmentStatus.PROPOSED_MEDECIN || currentStatus == AppointmentStatus.PLANNED_BY_MEDICAL_STAFF)
            ? "MEDICAL_VISIT_CONFIRMED_BY_EMPLOYEE" 
            : "APPOINTMENT_CONFIRMED";
        multiChannelNotificationService.notifyUsers(new ArrayList<>(recipientsConfirm), updatedAppointment, notificationScenario, null);

        AppointmentResponseDTO dto = appointmentMapper.toDto(updatedAppointment);
        applyPrivacyAndActionRules(dto, updatedAppointment, currentUser);
        return dto;
    }

    @Override
    @Transactional
    public AppointmentResponseDTO cancelAppointment(Long id, String reason) {
        User currentUser = getCurrentUser();
        Appointment appointment = appointmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found with id: " + id));

        AppointmentStatus previousStatus = appointment.getStatus();
        appointment.setStatus(AppointmentStatus.CANCELLED);
        appointment.setCancellationReason(reason);
        appointment.setUpdatedBy(currentUser);

        Appointment cancelledAppointment = appointmentRepository.save(appointment);
        
        // Use medical visit specific scenario if appointment was planned/proposed by medical staff (based on previous status)
        String notificationScenario = (previousStatus == AppointmentStatus.PLANNED_BY_MEDICAL_STAFF 
            || previousStatus == AppointmentStatus.PROPOSED_MEDECIN 
            || appointment.getMedicalInstructions() != null)
            ? "MEDICAL_VISIT_CANCELLED" 
            : "APPOINTMENT_CANCELLED";
        
        // Determine recipients: if obligatory and cancelled by employee, notify only RH and medical staff
        Set<User> recipientsCancel = new HashSet<>();
        boolean isCancelledByEmployee = false;
        try {
            isCancelledByEmployee = cancelledAppointment.getEmployee() != null &&
                cancelledAppointment.getEmployee().getUser() != null &&
                currentUser.getId() != null &&
                currentUser.getId().equals(cancelledAppointment.getEmployee().getUser().getId());
        } catch (Exception ignored) {}

        if (cancelledAppointment.isObligatory() && isCancelledByEmployee) {
            try {
                // RH users
                Set<User> rhUsers = userRepository.findByRoles_Name(RoleName.ROLE_RH);
                if (rhUsers != null) recipientsCancel.addAll(rhUsers);
            } catch (Exception ignored) {}
            try {
                // All nurses and doctors
                Set<User> nurses = userRepository.findByRoles_Name(RoleName.ROLE_NURSE);
                if (nurses != null) recipientsCancel.addAll(nurses);
                Set<User> doctors = userRepository.findByRoles_Name(RoleName.ROLE_DOCTOR);
                if (doctors != null) recipientsCancel.addAll(doctors);
            } catch (Exception ignored) {}
        } else {
            recipientsCancel = getAllActorsToNotify(cancelledAppointment);
        }

        log.info("Cancellation scenario: {} for previous status: {}, notifying {} users", 
                notificationScenario, previousStatus, recipientsCancel.size());
        
        multiChannelNotificationService.notifyUsers(new ArrayList<>(recipientsCancel), cancelledAppointment, notificationScenario, null);
        
        AppointmentResponseDTO dto = appointmentMapper.toDto(cancelledAppointment);
        applyPrivacyAndActionRules(dto, cancelledAppointment, currentUser);
        return dto;
    }

    private Set<User> getAllActorsToNotify(Appointment appointment) {
        Set<User> users = new HashSet<>();
        Employee employee = appointment.getEmployee();

        // 1. Add the employee
        if (employee != null && employee.getUser() != null) {
            log.info("Adding employee to notification list: {} (email: {})", 
                    employee.getUser().getUsername(), employee.getUser().getEmail());
            users.add(employee.getUser());
        } else {
            log.warn("Employee or employee.user is null for appointment {}", appointment.getId());
        }

        // 2. Add assigned nurse and doctor
        if (appointment.getNurse() != null) {
            users.add(appointment.getNurse());
        }
        if (appointment.getDoctor() != null) {
            users.add(appointment.getDoctor());
        }

        // 3. Add managers N+1 and N+2
        if (employee != null && employee.getManager1() != null && employee.getManager1().getUser() != null) {
            users.add(employee.getManager1().getUser());
        }
        if (employee != null && employee.getManager2() != null && employee.getManager2().getUser() != null) {
            users.add(employee.getManager2().getUser());
        }

        // 4. Add all nurses and all doctors globally
        Set<User> nurses = userRepository.findByRoles_Name(RoleName.ROLE_NURSE);
        if (nurses != null) {
            users.addAll(nurses);
        }
        Set<User> doctors = userRepository.findByRoles_Name(RoleName.ROLE_DOCTOR);
        if (doctors != null) {
            users.addAll(doctors);
        }

        // 5. Add all HR users globally
        Set<User> rhUsers = userRepository.findByRoles_Name(RoleName.ROLE_RH);
        if (rhUsers != null) {
            users.addAll(rhUsers);
        }

        return users;
    }

    // Méthodes simplifiées pour l'exemple - vous devrez implémenter toutes les autres méthodes de l'interface
    @Override
    @Transactional
    public AppointmentResponseDTO createAppointment(AppointmentRequestDTO appointmentRequestDTO) {
        User currentUser = getCurrentUser();
        Employee employee = employeeRepository.findByUser(currentUser).orElseGet(() -> {
            Employee newEmployee = Employee.builder()
                    .user(currentUser)
                    .profileCompleted(false)
                    .build();
            return employeeRepository.save(newEmployee);
        });

        Appointment appointment = appointmentMapper.toEntity(appointmentRequestDTO);
        appointment.setEmployee(employee);
        appointment.setStatus(AppointmentStatus.REQUESTED_EMPLOYEE);
        appointment.setType(appointmentRequestDTO.getType() != null ? appointmentRequestDTO.getType() : AppointmentType.SPONTANEOUS);
        appointment.setVisitMode(appointmentRequestDTO.getVisitMode());
        appointment.setCreatedBy(currentUser);
        appointment.setUpdatedBy(currentUser);
        appointment.setRequestedDateEmployee(appointmentRequestDTO.getRequestedDateEmployee());
        appointment.setMotif(appointmentRequestDTO.getMotif());
        appointment.setNotes(appointmentRequestDTO.getNotes());
    
        Appointment savedAppointment = appointmentRepository.save(appointment);

        Set<User> actorsToNotify = getAllActorsToNotify(savedAppointment);
        if (!actorsToNotify.isEmpty()) {
            multiChannelNotificationService.notifyUsers(new ArrayList<>(actorsToNotify), savedAppointment, "APPOINTMENT_REQUESTED", null);
        }

        AppointmentResponseDTO dto = appointmentMapper.toDto(savedAppointment);
        applyPrivacyAndActionRules(dto, savedAppointment, currentUser);
        return dto;
    }

    @Override
    @Transactional
    public AppointmentResponseDTO updateAppointment(Long id, AppointmentRequestDTO appointmentRequestDTO) {
        User currentUser = getCurrentUser();
        Appointment appointment = appointmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found with id: " + id));

        appointmentMapper.updateEntityFromDto(appointmentRequestDTO, appointment);
        appointment.setUpdatedBy(currentUser);

        Appointment updatedAppointment = appointmentRepository.save(appointment);
        AppointmentResponseDTO dto = appointmentMapper.toDto(updatedAppointment);
        applyPrivacyAndActionRules(dto, updatedAppointment, currentUser);
        return dto;
    }

    @Override
    @Transactional
    public AppointmentResponseDTO updateAppointmentStatus(Long id, AppointmentStatus status) {
        User currentUser = getCurrentUser();
        Appointment appointment = appointmentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found with id: " + id));

        appointment.setStatus(status);
        appointment.setUpdatedBy(currentUser);

        Appointment updatedAppointment = appointmentRepository.save(appointment);
        AppointmentResponseDTO dto = appointmentMapper.toDto(updatedAppointment);
        applyPrivacyAndActionRules(dto, updatedAppointment, currentUser);
        return dto;
    }

    @Override
    @Transactional
    public void deleteAppointment(Long id) {
        if (!appointmentRepository.existsById(id)) {
            throw new ResourceNotFoundException("Appointment not found with id: " + id);
        }
        appointmentRepository.deleteById(id);
    }

    @Override
    @Transactional
    public List<AppointmentResponseDTO> createObligatoryAppointments(AppointmentRequestDTO requestDTO) {
        Employee employee = employeeRepository.findById(requestDTO.getEmployeeId())
                .orElseThrow(() -> new ResourceNotFoundException("Employee not found for obligatory appointment."));

        Appointment appointment = appointmentMapper.toEntity(requestDTO);
        appointment.setEmployee(employee);
        appointment.setObligatory(true);
        appointment.setStatus(AppointmentStatus.OBLIGATORY); 
        appointment.setCreatedBy(getCurrentUser());
        appointment.setUpdatedBy(getCurrentUser());

        Appointment savedAppointment = appointmentRepository.save(appointment);
        AppointmentResponseDTO dto = appointmentMapper.toDto(savedAppointment);
        applyPrivacyAndActionRules(dto, savedAppointment, getCurrentUser());
        
        // For obligatory visits initiated by RH, notify only the medical service (all nurses and doctors)
        Set<User> medicalRecipients = new HashSet<>();
        try {
            Set<User> nurses = userRepository.findByRoles_Name(RoleName.ROLE_NURSE);
            if (nurses != null) medicalRecipients.addAll(nurses);
        } catch (Exception ignored) {}
        try {
            Set<User> doctors = userRepository.findByRoles_Name(RoleName.ROLE_DOCTOR);
            if (doctors != null) medicalRecipients.addAll(doctors);
        } catch (Exception ignored) {}

        if (!medicalRecipients.isEmpty()) {
            multiChannelNotificationService.notifyUsers(
                    new ArrayList<>(medicalRecipients),
                    savedAppointment,
                    "APPOINTMENT_REQUESTED",
                    "Une visite médicale obligatoire a été programmée."
            );
        }

        return List.of(dto);
    }

    @Override
    @Transactional
    public List<AppointmentResponseDTO> getAppointmentsByEmployeeId(Long employeeId) {
        User currentUser = getCurrentUser();
        List<Appointment> appointments = appointmentRepository.findByEmployeeId(employeeId);
        return appointments.stream()
                .map(appointment -> {
                    AppointmentResponseDTO dto = appointmentMapper.toDto(appointment);
                    applyPrivacyAndActionRules(dto, appointment, currentUser);
                    return dto;
                })
                .collect(java.util.stream.Collectors.toList());
    }

    @Override
    public Page<AppointmentResponseDTO> findAppointmentsWithFilters(AppointmentType type, List<AppointmentStatus> statuses, VisitMode visitMode, Long employeeId, LocalDateTime dateFrom, LocalDateTime dateTo, Pageable pageable) {
        User currentUser = getCurrentUser();
        // Normalize: default to all statuses when none provided to avoid JPQL IN () or null issues
        List<AppointmentStatus> effectiveStatuses = (statuses != null && !statuses.isEmpty())
                ? statuses
                : java.util.Arrays.asList(AppointmentStatus.values());
        return appointmentRepository.findWithFilters(type, effectiveStatuses, visitMode, employeeId, dateFrom, dateTo, pageable)
                .map(appointment -> {
                    AppointmentResponseDTO dto = appointmentMapper.toDto(appointment);
                    applyPrivacyAndActionRules(dto, appointment, currentUser);
                    return dto;
                });
    }

    @Override
    public Page<AppointmentResponseDTO> findAppointmentsForCurrentUser(String username, Pageable pageable) {
        User user = userRepository.findByUsernameOrEmail(username, username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with email: " + username));
        // If the current user is only an EMPLOYEE (not medical staff/admin/RH),
        // hide HR-initiated obligatory visits until a slot is proposed (status changes off OBLIGATORY)
        boolean hasEmployeeRole = user.getRoles() != null && user.getRoles().stream()
                .anyMatch(r -> r.getName() == RoleName.ROLE_EMPLOYEE);
        boolean isPrivileged = user.getRoles() != null && user.getRoles().stream().anyMatch(r ->
                r.getName() == RoleName.ROLE_NURSE ||
                r.getName() == RoleName.ROLE_DOCTOR ||
                r.getName() == RoleName.ROLE_RH ||
                r.getName() == RoleName.ROLE_ADMIN);

        Page<Appointment> appointments;
        if (hasEmployeeRole && !isPrivileged) {
            appointments = appointmentRepository.findByEmployeeUserExcludingStatuses(
                    user, java.util.List.of(AppointmentStatus.OBLIGATORY), pageable);
        } else {
            appointments = appointmentRepository.findByEmployeeUser(user, pageable);
        }
        return appointments.map(appointment -> {
            AppointmentResponseDTO dto = appointmentMapper.toDto(appointment);
            applyPrivacyAndActionRules(dto, appointment, user);
            return dto;
        });
    }

    @Override
    public AppointmentResponseDTO confirmAppointment(Long appointmentId) {
        return confirmAppointment(appointmentId, null);
    }

    @Override
    @Transactional
    public AppointmentResponseDTO confirmAppointment(Long appointmentId, String visitMode) {
        User currentUser = getCurrentUser();
        Appointment appointment = appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found with id: " + appointmentId));

        // Determine if current user is employee or medical staff
        boolean isEmployee = appointment.getEmployee() != null 
            && appointment.getEmployee().getUser() != null 
            && appointment.getEmployee().getUser().getId().equals(currentUser.getId());
        
        boolean isMedicalStaff = currentUser.getRoles() != null && currentUser.getRoles().stream()
            .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE || r.getName() == RoleName.ROLE_DOCTOR);

        AppointmentStatus currentStatus = appointment.getStatus();

        // Employee can confirm PROPOSED_MEDECIN or PLANNED_BY_MEDICAL_STAFF appointments
        if (isEmployee && (currentStatus == AppointmentStatus.PROPOSED_MEDECIN || currentStatus == AppointmentStatus.PLANNED_BY_MEDICAL_STAFF)) {
            return employeeConfirmAppointment(appointmentId);
        }
        
        // Medical staff can confirm REQUESTED_EMPLOYEE appointments
        if (isMedicalStaff && currentStatus == AppointmentStatus.REQUESTED_EMPLOYEE) {
            return medicalStaffConfirmAppointmentWithMode(appointmentId, visitMode);
        }

        throw new IllegalStateException("You are not authorized to confirm this appointment.");
    }

    @Transactional
    public AppointmentResponseDTO medicalStaffConfirmAppointmentWithMode(Long appointmentId, String visitMode) {
        User currentUser = getCurrentUser();
        Appointment appointment = appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found with id: " + appointmentId));

        // Authorization Check: Ensure the current user is medical staff
        boolean isMedicalStaff = currentUser.getRoles() != null && currentUser.getRoles().stream()
            .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE || r.getName() == RoleName.ROLE_DOCTOR);
        
        if (!isMedicalStaff) {
            throw new IllegalStateException("You are not authorized to confirm this appointment.");
        }

        AppointmentStatus currentStatus = appointment.getStatus();
        if (currentStatus != AppointmentStatus.REQUESTED_EMPLOYEE) {
            throw new IllegalStateException("Appointment cannot be confirmed from its current state: " + currentStatus);
        }

        // Set status to CONFIRMED when medical staff confirms employee request
        appointment.setStatus(AppointmentStatus.CONFIRMED);
        appointment.setUpdatedBy(currentUser);
        
        // Ensure the confirming medical staff is assigned to the appointment for proper nurse/doctor scoping
        boolean isNurseRole = currentUser.getRoles() != null && currentUser.getRoles().stream()
            .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE);
        boolean isDoctorRole = currentUser.getRoles() != null && currentUser.getRoles().stream()
            .anyMatch(r -> r.getName() == RoleName.ROLE_DOCTOR);
        if (isNurseRole && appointment.getNurse() == null) {
            appointment.setNurse(currentUser);
        }
        if (isDoctorRole && appointment.getDoctor() == null) {
            appointment.setDoctor(currentUser);
        }
        
        // Set visit mode if provided
        if (visitMode != null && !visitMode.trim().isEmpty()) {
            try {
                VisitMode mode = VisitMode.valueOf(visitMode.toUpperCase());
                appointment.setVisitMode(mode);
            } catch (IllegalArgumentException e) {
                log.warn("Invalid visit mode provided: {}", visitMode);
            }
        }
        
        // Set scheduled time to the requested date from employee
        if (appointment.getRequestedDateEmployee() != null) {
            appointment.setScheduledTime(appointment.getRequestedDateEmployee());
        }
        // Mettre à jour le contact du service médical en privilégiant le numéro de l'infirmier(e)
        appointment.setMedicalServicePhone(resolveMedicalServicePhone(appointment, currentUser));
        
        Appointment updatedAppointment = appointmentRepository.save(appointment);

        Set<User> actorsToNotify = getAllActorsToNotify(updatedAppointment);

        // Notify about medical staff confirmation - use RH scenario for RH recipients
        List<User> rhRecipients = new ArrayList<>();
        List<User> otherRecipients = new ArrayList<>();
        
        for (User user : actorsToNotify) {
            boolean isRH = user.getRoles() != null && user.getRoles().stream()
                .anyMatch(r -> r.getName() == RoleName.ROLE_RH);
            if (isRH) {
                rhRecipients.add(user);
            } else {
                otherRecipients.add(user);
            }
        }
        
        // Send RH-specific notifications (privacy-filtered)
        if (!rhRecipients.isEmpty()) {
            multiChannelNotificationService.notifyUsers(rhRecipients, updatedAppointment, "APPOINTMENT_CONFIRMED_RH", null, NotificationActor.RH);
        }
        
        // Send regular notifications to other recipients
        if (!otherRecipients.isEmpty()) {
            multiChannelNotificationService.notifyUsers(otherRecipients, updatedAppointment, "APPOINTMENT_CONFIRMED", null, NotificationActor.MEDICAL_STAFF);
        }

        AppointmentResponseDTO dto = appointmentMapper.toDto(updatedAppointment);
        applyPrivacyAndActionRules(dto, updatedAppointment, currentUser);
        return dto;
    }

    @Override
    @Transactional
    public AppointmentResponseDTO proposeAppointmentSlot(Long appointmentId, ProposeSlotRequestDTO proposeSlotRequestDTO) {
        User currentUser = getCurrentUser();
        Appointment appointment = appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found with id: " + appointmentId));

        // Ensure the current user is medical staff (nurse or doctor)
        boolean isNurseRole = currentUser.getRoles() != null && currentUser.getRoles().stream()
            .anyMatch(r -> r.getName() == RoleName.ROLE_NURSE);
        boolean isDoctorRole = currentUser.getRoles() != null && currentUser.getRoles().stream()
            .anyMatch(r -> r.getName() == RoleName.ROLE_DOCTOR);
        boolean isMedicalStaff = isNurseRole || isDoctorRole;
        if (!isMedicalStaff) {
            throw new IllegalStateException("Only medical staff can propose an appointment slot.");
        }

        // Allow proposal from REQUESTED_EMPLOYEE, OBLIGATORY, or when already proposed (update proposal)
        AppointmentStatus currentStatus = appointment.getStatus();
        if (currentStatus != AppointmentStatus.REQUESTED_EMPLOYEE
            && currentStatus != AppointmentStatus.PROPOSED_MEDECIN
            && currentStatus != AppointmentStatus.OBLIGATORY) {
            throw new IllegalStateException("Appointment cannot be proposed from its current state: " + currentStatus);
        }

        // Assign the proposing medical staff to the appointment if not already assigned
        if (isNurseRole && appointment.getNurse() == null) {
            appointment.setNurse(currentUser);
        }
        if (isDoctorRole && appointment.getDoctor() == null) {
            appointment.setDoctor(currentUser);
        }

        // Set proposed slot and optional visit mode
        if (proposeSlotRequestDTO.getProposedDate() == null) {
            throw new IllegalArgumentException("Proposed date is required");
        }
        appointment.setProposedDate(proposeSlotRequestDTO.getProposedDate());
        if (proposeSlotRequestDTO.getVisitMode() != null) {
            appointment.setVisitMode(proposeSlotRequestDTO.getVisitMode());
        }

        // Mettre à jour le contact du service médical pour refléter le numéro de l'infirmier(e) si présent
        appointment.setMedicalServicePhone(resolveMedicalServicePhone(appointment, currentUser));

        // Persist an optional justification comment
        if (proposeSlotRequestDTO.getComments() != null && !proposeSlotRequestDTO.getComments().isBlank()) {
            AppointmentComment comment = new AppointmentComment();
            comment.setAppointment(appointment);
            comment.setAuthor(currentUser);
            comment.setComment(proposeSlotRequestDTO.getComments().trim());
            appointment.getComments().add(comment);
        }

        // Move to proposed status and update audit
        appointment.setStatus(AppointmentStatus.PROPOSED_MEDECIN);
        appointment.setUpdatedBy(currentUser);

        Appointment updatedAppointment = appointmentRepository.save(appointment);

        // Notify actors about the proposal (actor-aware: MEDICAL_STAFF)
        // For obligatory visits: only RH and the employee should be notified (no medical staff/managers)
        // For others: keep notifying all actors
        Set<User> recipients = new HashSet<>();
        if (updatedAppointment.isObligatory()) {
            // Employee
            try {
                if (updatedAppointment.getEmployee() != null && updatedAppointment.getEmployee().getUser() != null) {
                    recipients.add(updatedAppointment.getEmployee().getUser());
                }
            } catch (Exception ignored) {}
            // All RH users
            try {
                Set<User> rhUsers = userRepository.findByRoles_Name(RoleName.ROLE_RH);
                if (rhUsers != null) recipients.addAll(rhUsers);
            } catch (Exception ignored) {}
            // Include the proposing medical staff (actor) so they see the actor-aware message
            try {
                if (currentUser != null) {
                    recipients.add(currentUser);
                }
            } catch (Exception ignored) {}
        } else {
            recipients = getAllActorsToNotify(updatedAppointment);
        }

        if (recipients != null && !recipients.isEmpty()) {
            multiChannelNotificationService.notifyUsers(new ArrayList<>(recipients), updatedAppointment, "APPOINTMENT_SLOT_PROPOSED", null, NotificationActor.MEDICAL_STAFF);
        }

        AppointmentResponseDTO dto = appointmentMapper.toDto(updatedAppointment);
        applyPrivacyAndActionRules(dto, updatedAppointment, currentUser);
        return dto;
    }

    @Override
    @Transactional
    public AppointmentResponseDTO acceptProposedSlot(Long appointmentId) {
        // Implementation simplifiée - implémentez selon vos besoins
        throw new UnsupportedOperationException("Not implemented in this simplified version");
    }

    @Override
    @Transactional
    public AppointmentResponseDTO addComment(Long appointmentId, AppointmentCommentRequestDTO commentRequest) {
        // Implementation simplifiée - implémentez selon vos besoins
        throw new UnsupportedOperationException("Not implemented in this simplified version");
    }

    @Override
    public Page<AppointmentResponseDTO> getAppointmentHistory(Pageable pageable) {
        List<AppointmentStatus> historyStatuses = List.of(AppointmentStatus.COMPLETED, AppointmentStatus.CANCELLED);
        Page<Appointment> appointments = appointmentRepository.findByStatusIn(historyStatuses, pageable);
        User currentUser = getCurrentUser();
        
        return appointments.map(appointment -> {
            AppointmentResponseDTO dto = appointmentMapper.toDto(appointment);
            applyPrivacyAndActionRules(dto, appointment, currentUser);
            return dto;
        });
    }

    @Override
    public void deleteAllAppointments() {
        appointmentRepository.deleteAll();
    }
}
