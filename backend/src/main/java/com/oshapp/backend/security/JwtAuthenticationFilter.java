package com.oshapp.backend.security;


import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import com.oshapp.backend.model.User;
import com.oshapp.backend.repository.UserRepository;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider jwtTokenProvider;
    private final UserRepository userRepository;

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain
    ) throws ServletException, IOException {

        // Bypass filter for authentication endpoints
        if (request.getServletPath().contains("/api/v1/auth")) {
            log.debug("JWT Filter bypass for auth endpoint: {} {}", request.getMethod(), request.getServletPath());
            filterChain.doFilter(request, response);
            return;
        }

        log.debug("JWT Filter processing: {} {}", request.getMethod(), request.getServletPath());

        final String authHeader = request.getHeader("Authorization");
        final String jwt;
        final String userEmail;

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            log.debug("No or invalid Authorization header. Proceeding unauthenticated.");
            filterChain.doFilter(request, response);
            return;
        }

        jwt = authHeader.substring(7);
        userEmail = jwtTokenProvider.getUsernameFromJWT(jwt);
        log.debug("Extracted subject from JWT: {}", userEmail);

        if (userEmail != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            if (jwtTokenProvider.validateToken(jwt)) {
                User user = userRepository.findByEmail(userEmail)
                        .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + userEmail));

                
                // Enforce account status: block deactivated or not yet activated users
                if (!user.isActive()) {
                    log.warn("User {} is not active (deactivated). Rejecting request.", userEmail);
                    response.setContentType("application/json");
                    response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                    response.getWriter().write("{\"error\":\"ACCOUNT_DEACTIVATED\"}");
                    response.getWriter().flush();
                    return;
                } else if (!user.isEnabled()) {
                    log.warn("User {} is not enabled (not activated). Rejecting request.", userEmail);
                    response.setContentType("application/json");
                    response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                    response.getWriter().write("{\"error\":\"ACCOUNT_NOT_ACTIVATED\"}");
                    response.getWriter().flush();
                    return;
                }

                UserDetails userDetails = UserPrincipal.create(user);
                UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                        userDetails,
                        null,
                        userDetails.getAuthorities()
                );
                authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                SecurityContextHolder.getContext().setAuthentication(authToken);
                log.debug("JWT authentication set for user: {} with authorities: {}", userEmail, userDetails.getAuthorities());
            } else {
                log.warn("JWT validation failed for subject: {}", userEmail);
            }
        }
        filterChain.doFilter(request, response);
    }
}
