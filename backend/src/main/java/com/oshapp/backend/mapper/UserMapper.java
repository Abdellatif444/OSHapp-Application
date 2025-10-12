package com.oshapp.backend.mapper;

import com.oshapp.backend.dto.UserSummaryDTO;
import com.oshapp.backend.model.User;
import jakarta.annotation.Generated;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")

@Generated(
        value = "org.mapstruct.ap.MappingProcessor",
        date = "2025-07-27T15:37:52+0100",
        comments = "version: 1.5.5.Final, compiler: Eclipse JDT (IDE) 3.42.50.v20250628-1110, environment: Java 21.0.7 (Eclipse Adoptium)"
)
public interface UserMapper {

    UserSummaryDTO toSummaryDto(User user);
}
