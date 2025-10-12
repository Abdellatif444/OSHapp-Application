package com.oshapp.backend.payload.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ActivationRequest {
    @NotBlank
    @Size(min = 6, max = 6)
    private String token;
}
