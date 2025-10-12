package com.oshapp.backend.mapper;

import com.oshapp.backend.dto.AppointmentCommentDTO;
import com.oshapp.backend.model.AppointmentComment;

import jakarta.annotation.Generated;
import org.mapstruct.Mapping;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2022-12-01T16:55:45+0200",
    comments = "version: 1.5.3.Final, compiler: Eclipse JDT (IDE) 3.23.0.v20221102-1452)"
)
public interface AppointmentCommentMapper {

    @Mapping(target = "authorName", expression = "java(toAuthorName(appointmentComment))")
    AppointmentCommentDTO toDto(AppointmentComment appointmentComment);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "appointment", ignore = true)
    @Mapping(target = "author", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    AppointmentComment toEntity(AppointmentCommentDTO appointmentCommentDTO);

    java.util.List<AppointmentCommentDTO> toDto(java.util.List<AppointmentComment> appointmentComments);

    java.util.List<AppointmentComment> toEntity(java.util.List<AppointmentCommentDTO> appointmentCommentDTOs);

    default String toAuthorName(AppointmentComment appointmentComment) {
        if (appointmentComment == null || appointmentComment.getAuthor() == null) {
            return null;
        }
        com.oshapp.backend.model.User author = appointmentComment.getAuthor();
        // Prefer Employee full name if available
        com.oshapp.backend.model.Employee emp = author.getEmployee();
        if (emp != null) {
            String fn = emp.getFirstName();
            String ln = emp.getLastName();
            String full = ((fn != null ? fn.trim() : "") + " " + (ln != null ? ln.trim() : "")).trim();
            if (!full.isEmpty()) {
                return full;
            }
        }
        // Then try User full name
        String ufn = author.getFirstName();
        String uln = author.getLastName();
        String ufull = ((ufn != null ? ufn.trim() : "") + " " + (uln != null ? uln.trim() : "")).trim();
        if (!ufull.isEmpty()) {
            return ufull;
        }
        // Finally fallback to username or email
        return author.getUsername() != null ? author.getUsername() : author.getEmail();
    }
}
