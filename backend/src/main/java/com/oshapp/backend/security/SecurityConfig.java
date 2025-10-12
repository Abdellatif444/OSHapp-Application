package com.oshapp.backend.security;

import com.oshapp.backend.service.impl.UserDetailsServiceImpl;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;

import static org.springframework.security.config.Customizer.withDefaults;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
@RequiredArgsConstructor
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        // configuration.setAllowedOriginPatterns(Arrays.asList("*"));
        configuration.setAllowedOriginPatterns(Arrays.asList("http://localhost:3001", "*"));
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    private void configureCommonHttpSecurity(HttpSecurity http, AuthenticationProvider authenticationProvider, JwtAuthenticationFilter jwtAuthenticationFilter) throws Exception {
        http
            .cors(withDefaults())
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(authorize -> authorize
                .requestMatchers(HttpMethod.POST, "/api/v1/auth/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/v1/auth/**").permitAll()
                .requestMatchers(HttpMethod.OPTIONS, "/api/v1/auth/**").permitAll()
                // Public account endpoints: activation and resend activation
                .requestMatchers(HttpMethod.POST, "/api/v1/account/activate", "/api/v1/account/resend-activation").permitAll()
                // Allow CORS preflight for all endpoints (browser sends OPTIONS without Authorization)
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs/**", "/api-docs/**").permitAll()
                .requestMatchers("/error", "/error/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/.well-known/**", "/favicon.ico", "/assets/**", "/static/**", "/", "/index.html").permitAll()
                .requestMatchers(HttpMethod.HEAD, "/.well-known/**", "/favicon.ico", "/assets/**", "/static/**", "/", "/index.html").permitAll()
                // Publicly serve uploaded files (e.g., company logos)
                .requestMatchers(HttpMethod.GET, "/uploads/**").permitAll()
                .requestMatchers(HttpMethod.HEAD, "/uploads/**").permitAll()
                .requestMatchers("/api/v1/admin/**").hasAnyAuthority("ROLE_ADMIN", "ROLE_RH")
                .requestMatchers("/api/v1/rh/**").hasAuthority("ROLE_RH")
                .requestMatchers("/api/v1/employees/profile/**", "/api/v1/employees/medical-fitness", "/api/v1/employees/stats", "/api/v1/employees/manager/status", "/api/v1/employees/subordinates", "/api/v1/employees/notifications/**", "/api/v1/employees/medical-visit-request").authenticated()
                .requestMatchers("/api/v1/employees/medical-fitness/history/**").authenticated()
                .requestMatchers("/api/v1/employees/**").hasAnyAuthority("ROLE_RH", "ROLE_ADMIN", "ROLE_NURSE", "ROLE_DOCTOR")
                .requestMatchers("/api/v1/nurse/**").hasAuthority("ROLE_NURSE")
                .requestMatchers("/api/v1/doctor/**").hasAuthority("ROLE_DOCTOR")
                .requestMatchers("/api/v1/hse/**").hasAuthority("ROLE_HSE")
                .anyRequest().authenticated()
            )
            .authenticationProvider(authenticationProvider)
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
            .exceptionHandling(exceptions -> exceptions
                .authenticationEntryPoint((request, response, authException) -> {
                    response.setContentType("application/json");
                    if (authException instanceof DisabledException) {
                        response.setStatus(jakarta.servlet.http.HttpServletResponse.SC_FORBIDDEN);
                        response.getWriter().write("{\"error\":\"ACCOUNT_NOT_ACTIVATED\"}");
                    } else if (authException instanceof BadCredentialsException) {
                        response.setStatus(jakarta.servlet.http.HttpServletResponse.SC_UNAUTHORIZED);
                        response.getWriter().write("{\"error\":\"UNAUTHORIZED\"}");
                    } else {
                        response.setStatus(jakarta.servlet.http.HttpServletResponse.SC_UNAUTHORIZED);
                        response.getWriter().write("{\"error\":\"UNAUTHORIZED\"}");
                    }
                    response.getWriter().flush();
                })
            );
    }

    @Profile("local")
    @Configuration
    @RequiredArgsConstructor
    public class LocalSecurityConfig {
        private final UserDetailsServiceImpl userDetailsService;
        private final JwtAuthenticationFilter jwtAuthenticationFilter;
        private final PasswordEncoder passwordEncoder;

        @Bean
        public AuthenticationProvider authenticationProvider() {
            DaoAuthenticationProvider authProvider = new DaoAuthenticationProvider();
            authProvider.setUserDetailsService(userDetailsService);
            authProvider.setPasswordEncoder(passwordEncoder);
            return authProvider;
        }

        @Bean
        public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
            return config.getAuthenticationManager();
        }

        @Bean
        public SecurityFilterChain localFilterChain(HttpSecurity http) throws Exception {
            configureCommonHttpSecurity(http, authenticationProvider(), jwtAuthenticationFilter);
            return http.build();
        }
    }

    @Profile("docker")
    @Configuration
    @RequiredArgsConstructor
    public class DockerSecurityConfig {
        private final UserDetailsServiceImpl userDetailsService;
        private final JwtAuthenticationFilter jwtAuthenticationFilter;
        private final PasswordEncoder passwordEncoder;

        @Bean
        public AuthenticationProvider authenticationProvider() {
            DaoAuthenticationProvider authProvider = new DaoAuthenticationProvider();
            authProvider.setUserDetailsService(userDetailsService);
            authProvider.setPasswordEncoder(passwordEncoder);
            return authProvider;
        }

        @Bean
        public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
            return config.getAuthenticationManager();
        }

        @Bean
        public SecurityFilterChain dockerFilterChain(HttpSecurity http) throws Exception {
            configureCommonHttpSecurity(http, authenticationProvider(), jwtAuthenticationFilter);
            return http.build();
        }
    }

    @Profile("keycloak")
    @Configuration
    @RequiredArgsConstructor
    public static class KeycloakSecurityConfig {
        private final JwtAuthConverter jwtAuthConverter;

        @Bean
        public SecurityFilterChain keycloakFilterChain(HttpSecurity http) throws Exception {
            http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authorize -> authorize
                    .requestMatchers(HttpMethod.POST, "/api/v1/auth/**").permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/v1/auth/**").permitAll()
                    .requestMatchers(HttpMethod.OPTIONS, "/api/v1/auth/**").permitAll()
                    // Public account endpoints: activation and resend activation
                    .requestMatchers(HttpMethod.POST, "/api/v1/account/activate", "/api/v1/account/resend-activation").permitAll()
                    // Allow static assets and uploaded files to be served publicly
                    .requestMatchers(HttpMethod.GET, "/.well-known/**", "/favicon.ico", "/assets/**", "/static/**", "/", "/index.html").permitAll()
                    .requestMatchers(HttpMethod.HEAD, "/.well-known/**", "/favicon.ico", "/assets/**", "/static/**", "/", "/index.html").permitAll()
                    .requestMatchers(HttpMethod.GET, "/uploads/**").permitAll()
                    .requestMatchers(HttpMethod.HEAD, "/uploads/**").permitAll()
                    .requestMatchers("/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs/**", "/api-docs/**").permitAll()
                    .requestMatchers("/api/v1/admin/**").hasAnyRole("ADMIN", "RH")
                    .requestMatchers("/api/v1/appointments/**").hasAnyRole("EMPLOYEE", "NURSE", "DOCTOR", "RH")
                    .requestMatchers("/api/v1/notifications/**").authenticated()
                    .requestMatchers("/api/v1/employees/**").hasAnyAuthority("ROLE_ADMIN", "ROLE_RH", "ROLE_NURSE", "ROLE_DOCTOR")
                    .requestMatchers("/api/v1/rh/**").hasRole("HR")
                    .requestMatchers("/api/v1/nurse/**").hasRole("NURSE")
                    .requestMatchers("/api/v1/doctor/**").hasRole("DOCTOR")
                    .requestMatchers("/api/v1/hse/**").hasRole("HSE")
                    .anyRequest().authenticated()
                )
                .oauth2ResourceServer(o2 -> o2
                    .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthConverter))
                );
            return http.build();
        }
    }
}