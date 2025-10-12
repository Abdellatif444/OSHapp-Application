package com.oshapp.backend.service;

import com.oshapp.backend.model.Role;

import java.util.List;
import java.util.Optional;

public interface RoleService {
    List<Role> findAll();
    Role createRole(String name);
    Role updateRole(Integer id, String name);
    void deleteRole(Integer id);

    long countRoles();
    Optional<Role> findByName(String name);
}
