 # Stage 1: Build Flutter App
 # Use prebuilt Flutter image for faster and more reliable builds
 FROM ghcr.io/cirruslabs/flutter:stable AS build-env

 # Ensure web tooling is ready
 RUN flutter --version && flutter config --enable-web && flutter precache --web

# (Flutter is already installed in this image)

# Set the working directory
WORKDIR /app

# Copy pubspec files first to leverage Docker layer caching
COPY pubspec.* ./

# Get Flutter dependencies
RUN flutter pub get

# Copy the rest of the application source code
COPY . .

# Run the build_runner to generate necessary files
RUN flutter pub run build_runner build --delete-conflicting-outputs

# Build the Flutter web application
RUN flutter build web --release

# Stage 2: Serve the web app using Nginx
FROM nginx:alpine

# Copy the built web app from the build stage
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Copy the custom Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 3000 for Nginx
EXPOSE 3000

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]