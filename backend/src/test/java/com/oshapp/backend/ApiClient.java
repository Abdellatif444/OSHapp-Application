package com.oshapp.backend;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

public class ApiClient {

    @Test
    public void testLogin() throws Exception {
        String jsonPayload = "{\"email\": \"admin@oshapp.com\", \"password\": \"admin12345678\"}";
        String url = "http://localhost:8082/api/v1/auth/login";

        HttpClient client = HttpClient.newBuilder()
                .version(HttpClient.Version.HTTP_1_1)
                .connectTimeout(Duration.ofSeconds(10))
                .build();

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
                .build();

        System.out.println("Sending request to: " + url);
        System.out.println("Payload: " + jsonPayload);

        try {
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            System.out.println("Response status code: " + response.statusCode());
            System.out.println("Response headers: " + response.headers());
            System.out.println("Response body: " + response.body());

            assertEquals(200, response.statusCode());
        } catch (Exception e) {
            System.err.println("An error occurred during the HTTP request:");
            e.printStackTrace();
        }
    }
}
