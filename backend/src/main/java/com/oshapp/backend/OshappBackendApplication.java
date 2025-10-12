package com.oshapp.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;


@SpringBootApplication
@EnableAsync
@org.springframework.context.annotation.ComponentScan(basePackages = "com.oshapp.backend")
public class OshappBackendApplication {
    public static void main(String[] args) {
        SpringApplication.run(OshappBackendApplication.class, args);
    }


} 