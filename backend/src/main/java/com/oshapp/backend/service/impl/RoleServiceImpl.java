package com.oshapp.backend.service.impl;

import com.oshapp.backend.exception.ResourceNotFoundException;
import com.oshapp.backend.model.Role;
import com.oshapp.backend.repository.RoleRepository;
import com.oshapp.backend.model.enums.RoleName;
import com.oshapp.backend.service.RoleService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class RoleServiceImpl implements RoleService {

    private final RoleRepository roleRepository;

    @Override
    public List<Role> findAll() {
        return roleRepository.findAll();
    }

    @Override
    public Role createRole(String name) {
        RoleName roleName = RoleName.valueOf(name.toUpperCase());
        Role role = new Role(roleName);
        return roleRepository.save(role);
    }

    @Override
    public Role updateRole(Integer id, String name) {
        Role role = roleRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Role not found with id: " + id));
        role.setName(RoleName.valueOf(name.toUpperCase()));
        return roleRepository.save(role);
    }

    @Override
    public void deleteRole(Integer id) {
        if (!roleRepository.existsById(id)) {
            throw new ResourceNotFoundException("Role not found with id: " + id);
        }
        roleRepository.deleteById(id);
    }

    @Override
    public long countRoles() {
        return roleRepository.count();
    }

    @Override
    public Optional<Role> findByName(String name) {
        return roleRepository.findByName(RoleName.valueOf(name.toUpperCase()));
    }
}
