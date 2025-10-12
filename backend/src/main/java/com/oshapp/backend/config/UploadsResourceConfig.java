package com.oshapp.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;
import java.nio.file.Paths;

@Configuration
public class UploadsResourceConfig implements WebMvcConfigurer {
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // Map '/uploads/**' to the local filesystem 'uploads' directory
        Path uploadsDir = Paths.get("uploads").toAbsolutePath().normalize();
        String location = uploadsDir.toUri().toString(); // e.g., file:///.../uploads/
        registry
            .addResourceHandler("/uploads/**")
            .addResourceLocations(location)
            .setCachePeriod(3600); // cache 1h
    }
}
