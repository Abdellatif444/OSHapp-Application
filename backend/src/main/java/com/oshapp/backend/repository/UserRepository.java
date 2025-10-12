package com.oshapp.backend.repository;

import com.oshapp.backend.model.Role;
import com.oshapp.backend.model.User;
import com.oshapp.backend.model.enums.RoleName;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.Set;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    long countByActive(boolean active);
    long countByEnabled(boolean enabled);

    @Modifying
    @Query(value = "INSERT INTO user_roles (user_id, role_id) VALUES (:userId, :roleId)", nativeQuery = true)
    void addUserRole(@Param("userId") Long userId, @Param("roleId") Integer roleId);

    @Query("SELECT u FROM User u LEFT JOIN FETCH u.employee WHERE u.username = :username")
    Optional<User> findByUsernameWithEmployee(@Param("username") String username);

    @Query("SELECT u FROM User u LEFT JOIN FETCH u.roles WHERE u.email = :email")
    Optional<User> findByEmail(String email);

    Optional<User> findByUsernameOrEmail(String username, String email);

    Boolean existsByEmail(String email);

    Boolean existsByUsername(String username);

    Optional<User> findFirstByRoles_Name(RoleName name);

    @Query("SELECT u FROM User u JOIN u.roles r WHERE r.name = :roleName")
    List<User> findUsersByRoleName(@Param("roleName") String roleName);

    Set<User> findByRoles_Name(RoleName name);

    List<User> findByRolesContaining(Role role);

    @Query("SELECT r.name, COUNT(u) FROM User u JOIN u.roles r GROUP BY r.name")
    List<Object[]> countUsersByRoleRaw();

}