package com.oshapp.backend.service;

import com.oshapp.backend.dto.AppointmentCommentRequestDTO;
import com.oshapp.backend.dto.AppointmentRequestDTO;
import com.oshapp.backend.dto.AppointmentResponseDTO;
import com.oshapp.backend.dto.PlanMedicalVisitRequestDTO;

import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.model.enums.VisitMode;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import com.oshapp.backend.dto.ProposeSlotRequestDTO;

import java.time.LocalDateTime;
import java.util.List;

public interface AppointmentService {

    List<AppointmentResponseDTO> getAllAppointments();

    AppointmentResponseDTO getAppointmentById(Long id);

    AppointmentResponseDTO createAppointment(AppointmentRequestDTO appointmentRequestDTO);

    AppointmentResponseDTO updateAppointment(Long id, AppointmentRequestDTO appointmentRequestDTO);

    AppointmentResponseDTO cancelAppointment(Long id, String reason);

    AppointmentResponseDTO updateAppointmentStatus(Long id, AppointmentStatus status);

    void deleteAppointment(Long id);

    List<AppointmentResponseDTO> createObligatoryAppointments(AppointmentRequestDTO requestDTO);

    List<AppointmentResponseDTO> getAppointmentsByEmployeeId(Long employeeId);

    Page<AppointmentResponseDTO> findAppointmentsWithFilters(AppointmentType type, List<AppointmentStatus> statuses, VisitMode visitMode, Long employeeId, LocalDateTime dateFrom, LocalDateTime dateTo, Pageable pageable);

    Page<AppointmentResponseDTO> findAppointmentsForCurrentUser(String username, Pageable pageable);

    AppointmentResponseDTO confirmAppointment(Long appointmentId);
    
    AppointmentResponseDTO confirmAppointment(Long appointmentId, String visitMode);

    AppointmentResponseDTO proposeAppointmentSlot(Long appointmentId, ProposeSlotRequestDTO proposeSlotRequestDTO);

    AppointmentResponseDTO acceptProposedSlot(Long appointmentId);

    AppointmentResponseDTO addComment(Long appointmentId, AppointmentCommentRequestDTO commentRequest);

    Page<AppointmentResponseDTO> getAppointmentHistory(Pageable pageable);

    AppointmentResponseDTO employeeConfirmAppointment(Long appointmentId);

    AppointmentResponseDTO planMedicalVisit(PlanMedicalVisitRequestDTO planRequest);

    void deleteAllAppointments();

    void resendNotifications(Long appointmentId, String scenario);
}
