package com.oshapp.backend.mapper;

import com.oshapp.backend.dto.NotificationResponseDTO;
import com.oshapp.backend.model.Notification;


import jakarta.annotation.Generated;

import org.mapstruct.Mapping;
import org.mapstruct.Mapper;

/**
 * Mapper for the entity {@link Notification} and its DTO {@link NotificationResponseDTO}.
 */

@Mapper(componentModel = "spring")
@Generated(
        value = "org.mapstruct.ap.MappingProcessor",
        date = "2022-12-03T16:55:35+0200",
        comments = "version: 1.4.2.Final, compiler: javac, environment: Java 11.0.15 (Oracle Corporation)"
)
public interface NotificationMapper {
    NotificationResponseDTO toDto(Notification notification);

    @Mapping(target = "type", ignore = true)
    @Mapping(target = "relatedEntityType", ignore = true)
    @Mapping(target = "relatedEntityId", ignore = true)
    @Mapping(target = "user", ignore = true)
    Notification toEntity(NotificationResponseDTO notificationDTO);
}
