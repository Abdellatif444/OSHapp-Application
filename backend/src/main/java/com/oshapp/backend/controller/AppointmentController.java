package com.oshapp.backend.controller;

import com.oshapp.backend.dto.*;

import com.oshapp.backend.model.enums.*;
import com.oshapp.backend.service.AppointmentService;
import com.oshapp.backend.service.UserService;
import lombok.RequiredArgsConstructor;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import com.oshapp.backend.dto.AppointmentCommentRequestDTO;
import com.oshapp.backend.dto.ProposeSlotRequestDTO;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;


import org.springframework.web.bind.annotation.*;


import java.util.List;


/**
 * AppointmentController
 */

@RestController
@RequestMapping("/api/v1/appointments")
@RequiredArgsConstructor
@CrossOrigin(origins = "*", maxAge = 3600)
@Tag(name = "Appointments", description = "API for appointment management")
public class AppointmentController {

    private static final Logger logger = LoggerFactory.getLogger(AppointmentController.class);

    private final AppointmentService appointmentService;
    @SuppressWarnings("unused")
    private final UserService userService;

    @GetMapping("/employee/{employeeId}")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH', 'NURSE', 'DOCTOR') or #employeeId == @userService.findEmployeeIdByEmail(authentication.name)")
    @Operation(summary = "Get appointments for a specific employee", description = "Retrieves a list of appointments for a given employee ID. Accessible by medical staff, HR, admins, or the employee themselves.")
    public ResponseEntity<List<AppointmentResponseDTO>> getAppointmentsForEmployee(@PathVariable Long employeeId, Authentication authentication) {
        List<AppointmentResponseDTO> appointments = appointmentService.getAppointmentsByEmployeeId(employeeId);
        return ResponseEntity.ok(appointments);
    }


    @GetMapping
    @PreAuthorize("hasRole('ADMIN') or hasRole('RH') or hasRole('NURSE') or hasRole('DOCTOR')")
    public ResponseEntity<List<AppointmentResponseDTO>> getAllAppointments() {
        return ResponseEntity.ok(appointmentService.getAllAppointments());
    }

    @GetMapping("/history")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH', 'NURSE', 'DOCTOR')")
    @Operation(summary = "Get appointment history", description = "Retrieves a paginated list of completed and cancelled appointments.")
    public ResponseEntity<Page<AppointmentResponseDTO>> getAppointmentHistory(Pageable pageable) {
        Page<AppointmentResponseDTO> history = appointmentService.getAppointmentHistory(pageable);
        return ResponseEntity.ok(history);
    }

    @PostMapping("/filter")
    @PreAuthorize("hasRole('ADMIN') or hasRole('RH') or hasRole('NURSE') or hasRole('DOCTOR')")
    @Operation(summary = "Filter appointments with pagination", description = "Retrieves a paginated list of appointments based on filter criteria sent in the request body.")
    public ResponseEntity<Page<AppointmentResponseDTO>> filterAppointments(
        @RequestBody AppointmentFilterDTO filter,
        Pageable pageable) {
        logger.info("--- ✅✅✅ NOUVEAU CODE EXÉCUTÉ : Entrée dans POST /filter ✅✅✅ ---");
        List<AppointmentStatus> statuses = filter.getStatuses();
        if (statuses == null || statuses.isEmpty()) {
            if (filter.getStatus() != null) {
                statuses = java.util.Collections.singletonList(filter.getStatus());
            } else {
                statuses = java.util.Arrays.asList(AppointmentStatus.values());
            }
        }
        logger.info("/filter -> type={}, statuses={}, visitMode={}, employeeId={}, dateFrom={}, dateTo={}",
            filter.getType(), statuses, filter.getVisitMode(), filter.getEmployeeId(), filter.getDateFrom(), filter.getDateTo());
        Page<AppointmentResponseDTO> appointments = appointmentService.findAppointmentsWithFilters(
            filter.getType(),
            statuses,
            filter.getVisitMode(),
            filter.getEmployeeId(), 
            filter.getDateFrom(), 
            filter.getDateTo(), 
            pageable);
        return ResponseEntity.ok(appointments);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH', 'NURSE', 'DOCTOR', 'EMPLOYEE')")
    public ResponseEntity<AppointmentResponseDTO> getAppointmentById(@PathVariable Long id) {
        return ResponseEntity.ok(appointmentService.getAppointmentById(id));
    }

    @PostMapping("/Rendez-vous-spontanee")
    @PreAuthorize("hasAnyRole('EMPLOYEE', 'DOCTOR', 'NURSE', 'RH')")
    public ResponseEntity<AppointmentResponseDTO> createAppointment(@RequestBody AppointmentRequestDTO appointmentRequestDTO) {
        AppointmentResponseDTO createdAppointment = appointmentService.createAppointment(appointmentRequestDTO);
        return new ResponseEntity<>(createdAppointment, HttpStatus.CREATED);
    }

    @PostMapping("/{id}/propose-slot")
    @PreAuthorize("hasAnyRole('NURSE', 'DOCTOR')")
    @Operation(summary = "Propose a new slot for an appointment", description = "Allows a nurse or doctor to propose an alternative time for an appointment.")
    public ResponseEntity<AppointmentResponseDTO> proposeAppointmentSlot(@PathVariable Long id, @RequestBody ProposeSlotRequestDTO proposeSlotRequestDTO) {
        AppointmentResponseDTO updatedAppointment = appointmentService.proposeAppointmentSlot(id, proposeSlotRequestDTO);
        return ResponseEntity.ok(updatedAppointment);
    }

    @PostMapping("/{id}/confirm")
    @PreAuthorize("hasAnyRole('NURSE', 'DOCTOR', 'EMPLOYEE')")
    @Operation(summary = "Confirm an appointment", description = "Allows an employee to confirm a proposed slot, or a nurse/doctor to confirm an initial request.")
    public ResponseEntity<AppointmentResponseDTO> confirmAppointment(
            @PathVariable Long id,
            @RequestParam(value = "visitMode", required = false) String visitMode) {
        AppointmentResponseDTO confirmedAppointment = appointmentService.confirmAppointment(id, visitMode);
        return ResponseEntity.ok(confirmedAppointment);
    }

    @PutMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH', 'NURSE', 'DOCTOR', 'EMPLOYEE')")
    public ResponseEntity<AppointmentResponseDTO> updateAppointmentStatus(@PathVariable Long id, @RequestParam("status") String status) {
        AppointmentStatus newStatus = AppointmentStatus.valueOf(status.toUpperCase());
        return ResponseEntity.ok(appointmentService.updateAppointmentStatus(id, newStatus));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or @appointmentSecurityService.canDeleteAppointment(authentication, #id)")
    public ResponseEntity<Void> deleteAppointment(@PathVariable Long id) {
        appointmentService.deleteAppointment(id);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Cancel an appointment", description = "Allows a user to cancel an appointment by providing a reason.")
    @ApiResponse(responseCode = "200", description = "Appointment cancelled successfully")
    @ApiResponse(responseCode = "404", description = "Appointment not found")
    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('EMPLOYEE', 'RH', 'NURSE', 'DOCTOR')")
    public ResponseEntity<AppointmentResponseDTO> cancelAppointment(@PathVariable Long id, @RequestBody CancelRequestDTO request) {
        AppointmentResponseDTO updatedAppointment = appointmentService.cancelAppointment(id, request.getReason());
        return ResponseEntity.ok(updatedAppointment);
    }




    @PostMapping("/{id}/comments")
    @PreAuthorize("@appointmentSecurityService.canCommentOnAppointment(authentication, #id)")
    public ResponseEntity<AppointmentResponseDTO> addCommentToAppointment(@PathVariable Long id, @RequestBody AppointmentCommentRequestDTO commentRequest) {
        return ResponseEntity.ok(appointmentService.addComment(id, commentRequest));
    }

    @PostMapping("/obligatory")
    @PreAuthorize("hasAnyRole('ADMIN', 'RH')")
    public ResponseEntity<List<AppointmentResponseDTO>> createObligatoryAppointments(@RequestBody AppointmentRequestDTO requestDTO) {
        List<AppointmentResponseDTO> createdAppointments = appointmentService.createObligatoryAppointments(requestDTO);
        return new ResponseEntity<>(createdAppointments, HttpStatus.CREATED);
    }

    @GetMapping("/my-appointments")
    @PreAuthorize("hasAnyRole('EMPLOYEE', 'DOCTOR', 'NURSE')")
    @Operation(summary = "Get my appointments", description = "Retrieves a paginated list of appointments for the currently authenticated user based on their role.")
    public ResponseEntity<Page<AppointmentResponseDTO>> getMyAppointments(
            @AuthenticationPrincipal UserDetails userDetails,
            Pageable pageable) {
        Page<AppointmentResponseDTO> appointments = appointmentService.findAppointmentsForCurrentUser(userDetails.getUsername(), pageable);
        return ResponseEntity.ok(appointments);
    }

    @PostMapping("/plan-medical-visit")
    @PreAuthorize("hasRole('NURSE') or hasRole('DOCTOR')")
    @Operation(summary = "Plan medical visit", description = "Medical staff plans a visit for an employee")
    @ApiResponse(responseCode = "201", description = "Medical visit planned successfully")
    public ResponseEntity<AppointmentResponseDTO> planMedicalVisit(@Valid @RequestBody PlanMedicalVisitRequestDTO planRequest) {
        logger.info("Medical staff planning visit for employee ID: {}", planRequest.getEmployeeId());
        AppointmentResponseDTO response = appointmentService.planMedicalVisit(planRequest);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @DeleteMapping("/reset-all")
    @Operation(summary = "Reset all appointments", description = "Delete all appointments for testing purposes.")
    public ResponseEntity<Void> resetAllAppointments() {
        appointmentService.deleteAllAppointments();
        logger.info("All appointments deleted for testing");
        return ResponseEntity.noContent().build();
    }

}
