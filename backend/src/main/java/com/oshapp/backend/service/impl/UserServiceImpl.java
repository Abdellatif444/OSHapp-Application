package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.EmployeeProfileDTO;
import com.oshapp.backend.dto.UserResponseDTO;
import com.oshapp.backend.model.Role;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.enums.RoleName;
import com.oshapp.backend.model.ActivationToken;
import com.oshapp.backend.model.PasswordResetToken;
import com.oshapp.backend.repository.ActivationTokenRepository;
import com.oshapp.backend.repository.PasswordResetTokenRepository;
import com.oshapp.backend.repository.EmployeeRepository;
import com.oshapp.backend.repository.RoleRepository;
import com.oshapp.backend.repository.UserRepository;
import com.oshapp.backend.service.EmailService;
import com.oshapp.backend.service.UserService;
import com.oshapp.backend.security.UserPrincipal;
import com.oshapp.backend.exception.InvalidTokenException;
import com.oshapp.backend.exception.UserAlreadyEnabledException;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Random;
import java.util.Set;
import java.util.ArrayList;
import java.util.stream.Collectors;



@Service
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final EmployeeRepository employeeRepository;
    private final PasswordEncoder passwordEncoder;
    private final ActivationTokenRepository activationTokenRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final EmailService emailService;

    public UserServiceImpl(UserRepository userRepository, RoleRepository roleRepository, EmployeeRepository employeeRepository, PasswordEncoder passwordEncoder, ActivationTokenRepository activationTokenRepository, PasswordResetTokenRepository passwordResetTokenRepository, EmailService emailService) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.employeeRepository = employeeRepository;
        this.passwordEncoder = passwordEncoder;
        this.activationTokenRepository = activationTokenRepository;
        this.passwordResetTokenRepository = passwordResetTokenRepository;
        this.emailService = emailService;
    }

    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userRepository.findByUsernameOrEmail(username, username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with username or email: " + username));

        Set<SimpleGrantedAuthority> authorities = user.getRoles().stream()
                .map(role -> new SimpleGrantedAuthority(role.getName().name()))
                .collect(Collectors.toSet());

        return new org.springframework.security.core.userdetails.User(user.getUsername(), user.getPassword(), authorities);
    }

    @Override
    @Transactional(readOnly = true)
    public List<User> findAll() {
        return userRepository.findAll();
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<User> findById(Long id) {
        return userRepository.findById(id);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<UserResponseDTO> findByUsername(String username) {
        return userRepository.findByUsernameOrEmail(username, username).map(user -> {
            UserResponseDTO dto = new UserResponseDTO();
            dto.setId(user.getId());
            dto.setUsername(user.getUsername());
            dto.setEmail(user.getEmail());
            dto.setRoles(user.getRoles().stream().map(role -> role.getName().name()).collect(Collectors.toSet()));
            // 'active' reflects deactivation status, not activation (enabled). Use isActive().
            dto.setActive(user.isActive());

            if (user.getEmployee() != null) {
                dto.setEmployee(new EmployeeProfileDTO(user.getEmployee()));
                if (user.getEmployee().getManager1() != null) {
                    dto.setN1(user.getEmployee().getManager1().getId());
                }
                if (user.getEmployee().getManager2() != null) {
                    dto.setN2(user.getEmployee().getManager2().getId());
                }
            }
            return dto;
        });
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<User> findByEmail(String email) {
        return userRepository.findByUsernameOrEmail(email, email);
    }

    @Override
    @Transactional
    public User createUser(String username, String password, Set<String> roleNames, boolean enabled) {
        // Rely on DB unique constraints to detect duplicates (mapped to 409 by controller)
        
        User user = new User();
        user.setUsername(username);
        user.setEmail(username); // Assuming email is the same as username for simplicity
        user.setPassword(passwordEncoder.encode(password));
        
        // Vérifier si l'utilisateur a le rôle ADMIN
        boolean isAdmin = roleNames.contains("ADMIN") || roleNames.contains("ROLE_ADMIN");
        
        if (isAdmin) {
            // Les comptes ADMIN sont activés directement
            user.setActive(true);
            user.setEnabled(true);
        } else {
            // Les autres comptes nécessitent une activation
            user.setActive(true); // Le compte existe mais...
            user.setEnabled(false); // ...n'est pas encore activé
        }
        
        addRolesToUser(user, roleNames);
        user = userRepository.save(user);
        
        // Si ce n'est pas un admin, générer et envoyer le code d'activation
        if (!isAdmin) {
            try {
                createAndSendActivationToken(user);
                System.out.println("Code d'activation généré et envoyé pour l'utilisateur: " + user.getEmail());
            } catch (Exception e) {
                System.err.println("Erreur lors de l'envoi du code d'activation pour " + user.getEmail() + ": " + e.getMessage());
                // Ne pas faire échouer la création du compte si l'email échoue
            }
        }
        
        return user;
    }

    @Override
    @Transactional
    public User save(User user) {
        return userRepository.save(user);
    }

    @Override
    @Transactional
    public void addRolesToUser(User user, Set<String> roleNames) {
        Set<Role> roles = findRolesByNames(roleNames);
        user.setRoles(roles);
    }

    @Override
    @Transactional
    public void delete(User user) {
        // Soft delete: keep row for historical integrity, hide from queries via @Where, and disable access
        user.setDeleted(true);
        user.setDeletedAt(LocalDateTime.now());
        user.setActive(false);
        user.setEnabled(false);

        // Libérer les contraintes d'unicité sur email/username en les renommant
        String suffix = "_deleted_" + user.getId() + "_" + System.currentTimeMillis();
        user.setUsername(user.getUsername() + suffix);
        user.setEmail(user.getEmail() + suffix);

        userRepository.save(user);
    }

    @Override
    @Transactional(readOnly = true)
    public long countUsers() {
        return userRepository.count();
    }

    @Override
    @Transactional
    public void deleteById(Long id) {
        User user = userRepository.findById(id).orElseThrow(() -> new RuntimeException("User not found"));
        delete(user);
    }

    @Override
    @Transactional
    public User updateUser(Long id, User userDetails) {
        User user = userRepository.findById(id).orElseThrow(() -> new RuntimeException("User not found"));
        //user.setUsername(userDetails.getUsername());
        user.setEmail(userDetails.getEmail());
        // On force le username à être identique à l'email pour garantir la cohérence
        user.setUsername(userDetails.getEmail()); 
        user.setRoles(userDetails.getRoles());
        return userRepository.save(user);
    }

    @Override
    @Transactional
    public void updatePassword(User user, String newPassword) {
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }

    @Override
    @Transactional
    public Set<Role> findRolesByNames(Set<String> roleNames) {
        return roleNames.stream()
                .map(nameStr -> {
                    RoleName rn = RoleName.valueOf(nameStr.toUpperCase());
                    return roleRepository.findByName(rn)
                            .orElseGet(() -> roleRepository.save(new Role(rn)));
                })
                .collect(Collectors.toSet());
    }

    @Override
    @Transactional(readOnly = true)
    public List<User> findUsersByRoleName(String roleName) {
        return new ArrayList<>(userRepository.findByRoles_Name(RoleName.valueOf(roleName.toUpperCase())));
    }

    @Override
    @Transactional(readOnly = true)
    public Long findEmployeeIdByEmail(String email) {
        return employeeRepository.findByUserEmail(email).get().getId();
    }

    @Override
    @Transactional
    public void activateAccount(String token) {
        ActivationToken activationToken = activationTokenRepository.findByToken(token)
                .orElseThrow(() -> new InvalidTokenException("Invalid activation token."));

        if (LocalDateTime.now().isAfter(activationToken.getExpiresAt())) {
            User user = activationToken.getUser();
            // Token is expired, delete the old one and send a new one.
            activationTokenRepository.delete(activationToken);
            createAndSendActivationToken(user);
            throw new InvalidTokenException("Activation token has expired. A new token has been sent to your email.");
        }

        User user = activationToken.getUser();
        user.setEnabled(true);
        userRepository.save(user);

        // Activation successful, token is no longer needed.
        activationTokenRepository.delete(activationToken);
    }

    @Override
    @Transactional
    public void resendActivationCode(String email) {
        User user = userRepository.findByUsernameOrEmail(email, email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));

        if (user.isEnabled()) {
            throw new UserAlreadyEnabledException("Account is already activated.");
        }

        createAndSendActivationToken(user);
    }

    @Override
    @Transactional
    public void createAndSendActivationToken(User user) {
        // Invalidate previous tokens for this user
        activationTokenRepository.deleteByUser(user);

        String token = String.format("%06d", new Random().nextInt(999999));
        ActivationToken activationToken = new ActivationToken();
        activationToken.setToken(token);
        activationToken.setUser(user);
        activationToken.setExpiresAt(LocalDateTime.now().plusMinutes(15));
        activationTokenRepository.save(activationToken);

        emailService.sendActivationEmail(user, token);
    }

    @Override
    @Transactional
    public void requestPasswordReset(String email) {
        Optional<User> optionalUser = userRepository.findByUsernameOrEmail(email, email);
        if (optionalUser.isEmpty()) {
            // Do not reveal whether the email exists
            return;
        }

        User user = optionalUser.get();
        // Invalidate previous reset tokens for this user
        passwordResetTokenRepository.deleteByUser(user);

        String token;
        do {
            token = String.format("%06d", new Random().nextInt(999999));
        } while (passwordResetTokenRepository.findByToken(token).isPresent());

        PasswordResetToken resetToken = PasswordResetToken.builder()
                .token(token)
                .user(user)
                .createdAt(LocalDateTime.now())
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        passwordResetTokenRepository.save(resetToken);

        emailService.sendPasswordResetEmail(user, token);
    }

    @Override
    @Transactional
    public void resetPassword(String token, String newPassword) {
        PasswordResetToken resetToken = passwordResetTokenRepository.findByToken(token)
                .orElseThrow(() -> new InvalidTokenException("Invalid password reset token."));

        if (LocalDateTime.now().isAfter(resetToken.getExpiresAt())) {
            // Token expired: delete and inform
            passwordResetTokenRepository.delete(resetToken);
            throw new InvalidTokenException("Password reset token has expired.");
        }

        if (resetToken.getValidatedAt() != null) {
            throw new InvalidTokenException("Password reset token has already been used.");
        }

        User user = resetToken.getUser();
        updatePassword(user, newPassword);

        // Enforce single-use by deleting all tokens for this user
        passwordResetTokenRepository.deleteByUser(user);
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponseDTO createDtoFromPrincipal(UserPrincipal userPrincipal) {
        Employee employee = employeeRepository.findByUserId(userPrincipal.getId()).orElse(null);
        return new UserResponseDTO(userPrincipal, employee);
    }
}
