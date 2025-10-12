class AppConfig {
  // Base URL for the backend API. It MUST include the API version prefix
  // (e.g., 'http://localhost:8081/api/v1' or 'https://api.example.com/api/v1').
  // The ApiService will normalize it to always have a trailing slash at runtime.
  //
  // Important:
  // - Do NOT hardcode '/api/v1' in endpoint paths; all endpoints in ApiService
  //   should be relative (e.g., 'users/me', not '/api/v1/users/me').
  // - Use --dart-define=API_BASE_URL=... to override per environment.
  // - For Flutter Web behind an Nginx proxy, a relative base '/api/v1/' may be
  //   used if the app is served from the same origin.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.100:8081/api/v1/',
  );
  // Final URL consumed by the app (kept as a separate alias for clarity)
  static const String apiUrl = apiBaseUrl;
  static const String keycloakBaseUrl = String.fromEnvironment(
    'KEYCLOAK_BASE_URL',
    defaultValue: 'http://192.168.1.100:8080/auth',
  );
  static const String keycloakUrl = '$keycloakBaseUrl/realms/oshapp';
  static const String keycloakDiscoveryUrl =
      '$keycloakUrl/.well-known/openid-configuration';

  // Google OAuth Client IDs
  // server (Web) client ID is required on Android to request an ID token from google_sign_in.
  // iOS client ID is required on iOS (if different). If left empty, the server ID will be reused.
  // TODO: Set these values from your Google Cloud Console OAuth credentials.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1070339122733-rpnkdg6q4v8mi1gpctctep95kckqooau.apps.googleusercontent.com',
  );

  // Feature flag: during testing, always show the spontaneous request form even
  // when a previous request is pending. Set via --dart-define on build/run.
  // IMPORTANT: Set this to false for production builds.
  static const bool showSpontaneousFormAlways = bool.fromEnvironment(
    'SHOW_SPONTANEOUS_FORM_ALWAYS',
    defaultValue: true,
  );

  // Feature flag: show the test-only Reset button that deletes all notifications
  // and appointments for the current logged-in user. Intended for testing only.
  // IMPORTANT: Keep disabled for production builds.
  static const bool showTestResetButton = bool.fromEnvironment(
    'SHOW_TEST_RESET_BUTTON',
    defaultValue: false,
  );
}
