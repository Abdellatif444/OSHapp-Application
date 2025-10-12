package com.oshapp.backend.repository;

import com.oshapp.backend.model.AppointmentComment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AppointmentCommentRepository extends JpaRepository<AppointmentComment, Long> {
    List<AppointmentComment> findByAppointmentId(Long appointmentId);
}
