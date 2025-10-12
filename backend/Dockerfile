# Stage 1: Build the application with Maven
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app

# Copy the Maven project file and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy the rest of the source code and build the application
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Create the final image for development
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Expose the application port and the debug port
EXPOSE 8081
EXPOSE 5005

# Copy the built jar file from the build stage
COPY --from=builder /app/target/oshapp-backend-0.0.1-SNAPSHOT.jar app.jar


# Unpack the jar file into layers for better caching and devtools support
RUN java -Djarmode=layertools -jar app.jar extract

# Set the entrypoint to run the application using the unpacked launcher
# ENTRYPOINT ["java", "-Dspring.profiles.active=docker", "-Xdebug", "-Xrunjdwp:server=y,transport=dt_socket,address=*:5005,suspend=n", "-cp", ".:spring-boot-loader/:dependencies/BOOT-INF/lib/*:application/", "org.springframework.boot.loader.launch.JarLauncher"]
# ENTRYPOINT ["java", "-Dloader.main=com.oshapp.backend.OshappBackendApplication", "-Dspring.profiles.active=docker", "-Xdebug", "-Xrunjdwp:server=y,transport=dt_socket,address=*:5005,suspend=n", "-cp", "spring-boot-loader/:dependencies/BOOT-INF/lib/*:application/BOOT-INF/classes/", "org.springframework.boot.loader.launch.PropertiesLauncher"]
# Set the entrypoint to run the application with proper classpath
ENTRYPOINT ["java", "-Dspring.profiles.active=docker", "-Xdebug", "-Xrunjdwp:server=y,transport=dt_socket,address=*:5005,suspend=n", "-jar", "app.jar"]
