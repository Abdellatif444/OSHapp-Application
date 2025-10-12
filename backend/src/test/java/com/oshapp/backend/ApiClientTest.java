package com.oshapp.backend;

import com.oshapp.backend.dto.LoginResponseDTO;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.*;
import org.springframework.test.context.ActiveProfiles;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("local")
public class ApiClientTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void testLoginAndGetProfile() {
                String loginUrl = "http://localhost:" + port + "/api/v1/auth/login";

        // Create login request body
        Map<String, String> loginBody = new HashMap<>();
        loginBody.put("email", "admin@oshapp.com");
        loginBody.put("password", "admin12345678");

        // Create HttpEntity for the login request
        HttpHeaders loginHeaders = new HttpHeaders();
        loginHeaders.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, String>> loginRequestEntity = new HttpEntity<>(loginBody, loginHeaders);

        System.out.println("Sending login request to: " + loginUrl);
        ResponseEntity<LoginResponseDTO> loginResponse = restTemplate.postForEntity(loginUrl, loginRequestEntity, LoginResponseDTO.class);

        System.out.println("Login response body: " + loginResponse.getBody());

        assertEquals(HttpStatus.OK, loginResponse.getStatusCode());
        LoginResponseDTO authBody = loginResponse.getBody();
        assertNotNull(authBody, "Authentication response body should not be null");
        assertNotNull(authBody.getToken(), "Authentication token should not be null");

        // Use the token for the next request
        String token = authBody.getToken();
                String profileUrl = "http://localhost:" + port + "/api/v1/employees/profile/me";

        HttpHeaders profileHeaders = new HttpHeaders();
        profileHeaders.setBearerAuth(token);
        HttpEntity<String> profileRequestEntity = new HttpEntity<>(profileHeaders);

        System.out.println("Sending profile request to: " + profileUrl);
        ResponseEntity<String> profileResponse = restTemplate.exchange(
                profileUrl,
                HttpMethod.GET,
                profileRequestEntity,
                String.class
        );

        System.out.println("Profile response body: " + profileResponse.getBody());

        assertEquals(HttpStatus.OK, profileResponse.getStatusCode());
        assertNotNull(profileResponse.getBody());
    }
}
