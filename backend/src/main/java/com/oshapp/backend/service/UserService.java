package com.oshapp.backend.service;

import com.oshapp.backend.dto.UserResponseDTO;
import com.oshapp.backend.model.Role;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.User;
import com.oshapp.backend.security.UserPrincipal;
import org.springframework.security.core.userdetails.UserDetailsService;

import java.util.List;
import java.util.Collections;
import java.util.Optional;
import java.util.Set;

public interface UserService extends UserDetailsService {

    void activateAccount(String token);

    void resendActivationCode(String email);

    void createAndSendActivationToken(User user);

    // Forgot/Reset password flow
    void requestPasswordReset(String email);
    void resetPassword(String token, String newPassword);

    List<User> findAll();

    Optional<User> findById(Long id);

    Optional<UserResponseDTO> findByUsername(String username);

    Optional<User> findByEmail(String email);

    User createUser(String username, String password, Set<String> roleNames, boolean enabled);

    User save(User user);

    void addRolesToUser(User user, Set<String> roleNames);

    void delete(User user);

    long countUsers();

    void deleteById(Long id);

    User updateUser(Long id, User userDetails);

    void updatePassword(User user, String newPassword);

    Set<Role> findRolesByNames(Set<String> roleNames);

    List<User> findUsersByRoleName(String roleName);

    Long findEmployeeIdByEmail(String email);

    UserResponseDTO createDtoFromPrincipal(UserPrincipal userPrincipal);

}
