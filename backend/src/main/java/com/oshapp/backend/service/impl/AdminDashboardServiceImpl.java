package com.oshapp.backend.service.impl;

import com.oshapp.backend.dto.AdminDashboardData;
import com.oshapp.backend.repository.UserRepository;
import com.oshapp.backend.service.AdminDashboardService;
import com.oshapp.backend.service.RoleService;
import com.oshapp.backend.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AdminDashboardServiceImpl implements AdminDashboardService {

    private final UserService userService;
    private final RoleService roleService;
    private final UserRepository userRepository;

    @Override
    public AdminDashboardData getDashboardData() {
        long totalUsers = userService.countUsers();
        long activeUsers = userRepository.countByActive(true);
        long inactiveUsers = userRepository.countByActive(false);
        long totalRoles = roleService.countRoles();
        // The 'recentLogins' is a placeholder for now.
        // A more complex implementation would involve tracking login events.
        long recentLogins = 0; 
        long awaitingVerificationUsers = userRepository.countByEnabled(false);

        return new AdminDashboardData(
                totalUsers,
                activeUsers,
                totalRoles,
                recentLogins,
                inactiveUsers,
                awaitingVerificationUsers
        );
    }
}
