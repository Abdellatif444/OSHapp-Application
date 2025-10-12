package com.oshapp.backend.dto;

import java.util.Set;
import lombok.Data;

@Data
public class UserUpdateRequestDTO {
    private String email;
    private Set<String> roles;
    private Boolean active;
    private String password; // Optionnel, si l'admin veut réinitialiser le mot de passe

    // Méthodes getter/setter explicites pour résoudre les erreurs de compilation
    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public Set<String> getRoles() {
        return roles;
    }

    public void setRoles(Set<String> roles) {
        this.roles = roles;
    }

    public Boolean getActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}