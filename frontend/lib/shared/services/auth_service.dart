import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oshapp/shared/models/role.dart';
import 'package:oshapp/shared/models/user.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/models/employee_creation_request_dto.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'package:oshapp/shared/services/logger_service.dart';
import 'package:get_it/get_it.dart';
import 'package:oshapp/shared/services/navigation_service.dart';
import 'package:oshapp/main.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthService with ChangeNotifier {
  final ApiService _apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthService(this._apiService);

  Future<void> init() async {
    await tryAutoLogin();
  }

  // Store a route to navigate to after successful authentication (e.g., deep links)
  void setPendingRoute(String routeName, Object? args) {
    _pendingRouteName = routeName;
    _pendingRouteArgs = args;
  }

  // Navigate to pending route if any. Returns true if navigated.
  bool navigateToPendingIfAny() {
    if (_pendingRouteName != null) {
      final name = _pendingRouteName!;
      final args = _pendingRouteArgs;
      _pendingRouteName = null;
      _pendingRouteArgs = null;
      getIt<NavigationService>().navigateToAndRemoveUntil(name, arguments: args);
      return true;
    }
    return false;
  }

  String? _token;
  List<Role> _roles = [];
  bool _isProfileComplete = false;
  int? _userId;
  String? _email;
  User? _user;
  Employee? _employee;
  AuthStatus _authStatus = AuthStatus.unknown;
  String? _pendingRouteName;
  Object? _pendingRouteArgs;

  bool get isAuthenticated => _authStatus == AuthStatus.authenticated;
  List<String> get roles => _roles.map((role) => role.name).toList();
  bool get isProfileComplete => _isProfileComplete;
  int? get userId => _userId;
  String? get token => _token;
  String? get email => _email;
  User? get user => _user;
  Employee? get employee => _employee;
  AuthStatus get authStatus => _authStatus;

  Future<bool> login(String email, String password, {void Function(double, String)? onProgress}) async {
    try {
      debugPrint('--- AUTH_SERVICE: Attempting to login with email: $email ---');
      onProgress?.call(0.05, 'Demande d\'authentification...');
      final responseData = await _apiService.login(email, password);
      onProgress?.call(0.25, 'Vérification des identifiants...');
      await processLoginResponse(responseData, onProgress: onProgress);
      return false; // Login successful, no activation needed
    } on ApiException catch (e) {
      if (e.needsActivation) {
        debugPrint('--- AUTH_SERVICE: Account needs activation for user: $email ---');
        return true; // Activation is needed; UI will navigate
      } else if (e.isDeactivated) {
        debugPrint('--- AUTH_SERVICE: Account deactivated for user: $email ---');
        await clearAuthData();
        rethrow;
      } else {
        debugPrint('--- AUTH_SERVICE: Login failed for user: $email. Error: $e ---');
        await clearAuthData();
        rethrow;
      }
    } catch (e) {
      debugPrint('--- AUTH_SERVICE: An unexpected error occurred during login: $e ---');
      await clearAuthData();
      rethrow;
    }
  }

  Future<void> loginWithGoogle(String idToken, {void Function(double, String)? onProgress}) async {
    try {
      debugPrint('--- AUTH_SERVICE: Attempting Google login with ID token (len=${idToken.length}) ---');
      final responseData = await _apiService.googleLogin(idToken);
      onProgress?.call(0.30, 'Vérification Google...');
      await processLoginResponse(responseData, onProgress: onProgress);
    } on ApiException catch (e) {
      // Propagate activation-required so UI can navigate to Activation screen
      if (e.needsActivation) {
        debugPrint('--- AUTH_SERVICE: Google login needs activation ---');
        rethrow;
      } else if (e.isDeactivated) {
        debugPrint('--- AUTH_SERVICE: Google login blocked — account deactivated ---');
        await clearAuthData();
        rethrow;
      }
      debugPrint('--- AUTH_SERVICE: Google login failed: $e ---');
      await clearAuthData();
      rethrow;
    } catch (e) {
      debugPrint('--- AUTH_SERVICE: Unexpected error during Google login: $e ---');
      await clearAuthData();
      rethrow;
    }
  }

  Future<void> activateAccount(String token) async {
    try {
      await _apiService.activateAccount(token);
      // Do not fetch profile here; user is not authenticated yet.
      // Activation enables the account; the user should log in afterwards.
    } catch (e) {
      debugPrint('--- AUTH_SERVICE: Account activation failed. Error: $e ---');
      rethrow;
    }
  }

  Future<void> resendActivationCode(String email) async {
    await _apiService.resendActivationCode(email);
  }

  Future<void> processLoginResponse(Map<String, dynamic> responseData, {void Function(double, String)? onProgress}) async {
    debugPrint('--- AUTH_SERVICE: Processing login response ---');
    final token = responseData['token'] ?? responseData['accessToken'];
    final userData = responseData['user'];

    if (token == null || userData == null) {
      await clearAuthData();
      notifyListeners();
      return;
    }

    try {
      onProgress?.call(0.35, 'Initialisation de la session...');
      _token = token;
      _apiService.setAuthToken(_token); // Set token for future API calls
      _user = User.fromJson(userData as Map<String, dynamic>);
      debugPrint('--- AUTH_SERVICE: User object created: ${_user?.toJson()} ---');
      _userId = int.parse(_user!.id);
      _email = _user!.email;
      _roles = (_user!.roles as List<dynamic>)
          .map((role) => Role.fromString(role.toString()))
          .toList();

      onProgress?.call(0.45, 'Préparation des données...');
      await _storage.write(key: 'auth_token', value: _token);
      debugPrint('--- AUTH_SERVICE: Token stored securely ---');
      await _storage.write(key: 'user_data', value: json.encode(userData));
      await _storage.write(key: 'user_id', value: _userId.toString());
      await _storage.write(key: 'user_email', value: _email);
            await _storage.write(key: 'user_roles', value: json.encode(_roles));

  
      try {
        onProgress?.call(0.65, 'Récupération du profil...');
        await _fetchAndUpdateUserProfile();
      } on ApiException catch (e) {
        if (e.isDeactivated || e.needsActivation) {
          debugPrint('--- AUTH_SERVICE: Aborting login due to account state (deactivated=${e.isDeactivated}, needsActivation=${e.needsActivation}). ---');
          await clearAuthData();
          rethrow;
        }
        debugPrint('--- AUTH_SERVICE: getMe() failed after login (non-fatal). Proceeding with login payload. Error: $e ---');
      } catch (e) {
        debugPrint('--- AUTH_SERVICE: getMe() failed after login (unexpected). Proceeding with login payload. Error: $e ---');
      }
      try {
        onProgress?.call(0.80, 'Vérification du profil...');
        await ensureProfileForCurrentUser();
      } on ApiException catch (e) {
        if (e.isDeactivated || e.needsActivation) {
          debugPrint('--- AUTH_SERVICE: Aborting login during profile ensure due to account state. ---');
          await clearAuthData();
          rethrow;
        }
        debugPrint('--- AUTH_SERVICE: ensureProfileForCurrentUser() failed after login (non-fatal): $e ---');
      } catch (e) {
        debugPrint('--- AUTH_SERVICE: ensureProfileForCurrentUser() failed after login (unexpected): $e ---');
      }

    _authStatus = AuthStatus.authenticated;
    debugPrint('--- AUTH_SERVICE: Auth status updated to authenticated ---');
    notifyListeners();
    debugPrint('--- AUTH_SERVICE: Listeners notified ---');
    onProgress?.call(0.92, 'Finalisation...');
    // Prefer navigating to any pending deep-link route first
    if (!navigateToPendingIfAny()) {
      // Fallback to role-based dashboard
      onProgress?.call(0.98, 'Redirection...');
      _navigateToDashboard();
    }
    } on ApiException catch (e) {
      debugPrint('Failed to process login response (ApiException): $e');
      await clearAuthData();
      rethrow;
    } catch (e) {
      debugPrint('Failed to process login response (unexpected): $e');
      await clearAuthData();
      rethrow;
    } finally {
      // Removed notifyListeners() from here
    }
  }

  void setProfileComplete(bool status) {
    _isProfileComplete = status;
    _storage.write(key: 'profile_completed', value: status.toString());
    LoggerService.info('--- FRONTEND: Profile status updated to: $_isProfileComplete for user $_userId ---');
    notifyListeners();
  }

  Future<void> markProfileAsCompleted() async {
    _isProfileComplete = true;
    await _storage.write(key: 'profile_completed', value: 'true');
    notifyListeners();
  }

  /// Ensures the current user has a completed employee profile.
  /// If missing/incomplete, auto-fills with placeholder values and updates backend.
  Future<void> ensureProfileForCurrentUser() async {
    if (_user == null) return;
    // If already complete, nothing to do.
    if (_employee != null && _isProfileComplete) return;

    try {
      // Generate simple placeholder values
      final seed = DateTime.now().millisecondsSinceEpoch;
      final rnd = Random(seed);
      String genDigits(int n) => List.generate(n, (_) => rnd.nextInt(10)).join();

      final email = _user!.email;
      final namePart = email.split('@').first.replaceAll('.', ' ').trim();
      final parts = namePart.split(RegExp(r'[_\-\s]+'));
      final firstName = (parts.isNotEmpty ? parts.first : 'User').isNotEmpty ? parts.first : 'User';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ').toUpperCase() : 'OSH';

      // Map roles to backend role IDs (fallback EMPLOYEE=1)
      int mapRole(String role) {
        final r = role.trim().toUpperCase().replaceFirst('ROLE_', '');
        switch (r) {
          case 'EMPLOYEE':
            return 1;
          case 'HR':
          case 'RH':
            return 2;
          case 'NURSE':
          case 'INFIRMIER':
            return 3;
          case 'DOCTOR':
          case 'MEDECIN':
            return 4;
          case 'HSE':
            return 5;
          case 'ADMIN':
            return 6;
          default:
            return 1;
        }
      }

      final roleIds = roles.map(mapRole).toList();

      final dto = EmployeeCreationRequestDTO(
        id: _employee?.id,
        userId: _userId,
        firstName: firstName[0].toUpperCase() + firstName.substring(1),
        lastName: lastName,
        email: email,
        phoneNumber: '06${genDigits(8)}',
        address: 'Auto-filled Address ${genDigits(3)}',
        jobTitle: 'Employee',
        department: 'General',
        roleIds: roleIds.isNotEmpty ? roleIds : [1],
        managerId: _employee?.manager?.id,
      );

      await _apiService.updateEmployeeProfile(dto);

      // Refresh local state from backend (to get profileCompleted flag and id)
      await _fetchAndUpdateUserProfile();

      // If still not marked by backend, mark client-side to avoid loops
      if (!_isProfileComplete) {
        await markProfileAsCompleted();
      }

      LoggerService.info('--- FRONTEND: Auto-filled employee profile for user ${_user!.email} ---');
    } on ApiException catch (e) {
      if (e.isDeactivated || e.needsActivation) {
        LoggerService.error('--- FRONTEND: Aborting auto-fill due to account state (deactivated=${e.isDeactivated}, needsActivation=${e.needsActivation}). ---');
        rethrow;
      }
      LoggerService.error('--- FRONTEND: Failed to auto-fill profile (non-fatal): $e ---');
      // Do not throw; allow navigation to continue for other errors.
    } catch (e) {
      LoggerService.error('--- FRONTEND: Failed to auto-fill profile (unexpected): $e ---');
      // Do not throw; allow navigation to continue.
    }
  }

  Future<void> tryAutoLogin() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _token = token;
    _apiService.setAuthToken(_token); // Set token for future API calls

    try {
      // With a valid token, fetch the latest user profile from the backend.
      // This is more reliable than using stale data from storage.
      await _fetchAndUpdateUserProfile();
      // Auto-fill profile if missing/incomplete to avoid blocking dashboards on reload
      await ensureProfileForCurrentUser();

      LoggerService.info('--- FRONTEND: Auto-login successful. Profile complete: ${_user?.employee?.profileCompleted} ---');
      _authStatus = AuthStatus.authenticated;
    } catch (e) {
      LoggerService.error('--- FRONTEND: Failed to auto-login with token: $e ---');
      await clearAuthData(); // Invalid token or network issue, force logout.
      return;
    }

    notifyListeners();
  }

  /// Fetches the complete user profile from the API and updates the service state.
  Future<void> _fetchAndUpdateUserProfile() async {
    debugPrint('--- AUTH_SERVICE: Fetching user profile... ---');
    try {
      debugPrint('--- AUTH_SERVICE: Calling getMe() to fetch current user profile ---');
      final userProfile = await _apiService.getMe();
      // Using jsonEncode to get a readable string representation of the user data
      debugPrint('--- AUTH_SERVICE: Profile data received from getMe(): ${jsonEncode(userProfile.toJson())} ---');
      _user = userProfile;
      _userId = int.parse(_user!.id);
      _email = _user!.email;
      _roles = (_user!.roles as List<dynamic>)
          .map((role) => Role.fromString(role.toString()))
          .toList();
      if (_user!.employee != null) {
        _employee = _user!.employee;
        _isProfileComplete = _user!.employee!.profileCompleted;
      } else {
        _employee = null;
        _isProfileComplete = false;
        debugPrint('--- AUTH_SERVICE: Warning - Employee data is null in the response from getMe() ---');
      }

      // Persist the updated user data to storage for faster subsequent loads.
      await _storage.write(key: 'user_data', value: json.encode(_user!.toJson()));
    } on ApiException catch (e) {
      debugPrint('--- AUTH_SERVICE: getMe() threw ApiException: $e ---');
      // Propagate so callers can react (e.g., deactivated/activation-required)
      rethrow;
    } catch (e) {
      debugPrint('--- AUTH_SERVICE: Failed to fetch or update user profile: $e ---');
      // Propagate the error to be handled by the calling function (login/auto-login)
      throw Exception('Failed to retrieve user profile.');
    }
  }

  /// Public wrapper to refresh current user profile from server and notify listeners.
  Future<void> refreshCurrentUserProfile() async {
    await _fetchAndUpdateUserProfile();
    notifyListeners();
  }

  /// Apply an updated User object to the in-memory auth state if it matches the current user.
  /// Also persists to storage and notifies listeners.
  void applyUserUpdate(User updated) {
    try {
      final updatedId = int.tryParse(updated.id);
      if (updatedId == null) {
        debugPrint('--- AUTH_SERVICE: applyUserUpdate skipped — updated.id is not an int: ${updated.id}');
        return;
      }
      if (_userId != null && updatedId != _userId) {
        debugPrint('--- AUTH_SERVICE: applyUserUpdate skipped — updated user (${updated.id}) does not match current user ($_userId).');
        return;
      }

      _user = updated;
      _userId = updatedId;
      _email = updated.email;
      _roles = (updated.roles)
          .map((role) => Role.fromString(role.toString()))
          .toList();
      _employee = updated.employee;
      if (_employee != null) {
        _isProfileComplete = _employee!.profileCompleted;
        _storage.write(key: 'profile_completed', value: _isProfileComplete.toString());
      }

      // Persist user data
      _storage.write(key: 'user_data', value: json.encode(_user!.toJson()));
      _storage.write(key: 'user_email', value: _email);
      notifyListeners();
      debugPrint('--- AUTH_SERVICE: applyUserUpdate applied and notified listeners. ---');
    } catch (e) {
      debugPrint('--- AUTH_SERVICE: applyUserUpdate failed: $e');
    }
  }

  /// Apply an updated Employee profile for the current user and notify listeners.
  void applyEmployeeUpdate(Employee updated) {
    if (_user == null) {
      debugPrint('--- AUTH_SERVICE: applyEmployeeUpdate skipped — no current user. ---');
      return;
    }
    // Rebuild the User with the updated employee instance (User is immutable)
    _employee = updated;
    _isProfileComplete = updated.profileCompleted;
    _user = User(
      id: _user!.id,
      username: _user!.username,
      email: _user!.email,
      roles: _user!.roles,
      isActive: _user!.isActive,
      enabled: _user!.enabled,
      employee: updated,
      n1Id: _user!.n1Id,
      n2Id: _user!.n2Id,
    );
    _storage.write(key: 'user_data', value: json.encode(_user!.toJson()));
    _storage.write(key: 'profile_completed', value: _isProfileComplete.toString());
    notifyListeners();
    debugPrint('--- AUTH_SERVICE: applyEmployeeUpdate applied and notified listeners. ---');
  }

  Future<void> clearAuthData() async {
    _token = null;
    _roles = [];
    _userId = null;
    _email = null;
    _user = null;
    _employee = null;
    _isProfileComplete = false;
    _pendingRouteName = null;
    _pendingRouteArgs = null;
    await _storage.deleteAll();
    _apiService.setAuthToken(null); // Clear token in ApiService
    _authStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> logout({void Function(double, String)? onProgress, bool navigate = true}) async {
    try {
      onProgress?.call(0.08, 'Déconnexion du serveur...');
      await _apiService.logout(); // Attempt to log out on the server
    } catch (e) {
      // Log the error but don't rethrow, as we still want to clear local data
      LoggerService.error('--- AUTH_SERVICE: API logout failed, proceeding with local logout. Error: $e ---');
    } finally {
      // Also clear Google Sign-In session so next login shows the account chooser
      try {
        onProgress?.call(0.26, 'Nettoyage de la session Google...');
        final g = GoogleSignIn(
          scopes: const ['openid', 'email', 'profile'],
        );
        try {
          await g.signOut();
          debugPrint('--- AUTH_SERVICE: GoogleSignIn.signOut() executed during logout.');
        } catch (e) {
          debugPrint('--- AUTH_SERVICE: GoogleSignIn.signOut() during logout ignored: $e');
        }
        try {
          await g.disconnect();
          debugPrint('--- AUTH_SERVICE: GoogleSignIn.disconnect() executed to revoke consent.');
        } catch (e) {
          debugPrint('--- AUTH_SERVICE: GoogleSignIn.disconnect() during logout ignored: $e');
        }
      } catch (e) {
        debugPrint('--- AUTH_SERVICE: Google cleanup during logout ignored: $e');
      }

      onProgress?.call(0.62, 'Nettoyage des données locales...');
      // Ensure local data is always cleared and user is redirected
      await clearAuthData();
      onProgress?.call(0.88, 'Finalisation...');
      if (navigate) {
        onProgress?.call(0.96, 'Redirection...');
        getIt<NavigationService>().navigateToLogin();
      }
    }
  }

  void _navigateToDashboard() {
    if (_user == null) return;

    // Always route directly to dashboards; profile completion is not mandatory.
    debugPrint('--- AUTH_SERVICE: Skipping profile completion. Routing directly to dashboard. ---');

    // Determine the highest-priority role for redirection using normalized roles.
    final roles = this.roles; // e.g., ['ADMIN', 'HR', ...]
    String? targetRoute;

    if (roles.contains('ADMIN')) {
      targetRoute = '/admin_home';
    } else if (roles.contains('DOCTOR')) {
      targetRoute = '/doctor_home';
    } else if (roles.contains('NURSE')) {
      targetRoute = '/nurse_home';
    } else if (roles.contains('HR')) {
      targetRoute = '/rh_home';
    } else if (roles.contains('HSE')) {
      targetRoute = '/hse_home';
    } else if (roles.contains('EMPLOYEE')) {
      targetRoute = '/employee_home';
    }

    if (targetRoute != null) {
      getIt<NavigationService>().navigateToAndRemoveUntil(targetRoute, arguments: _user);
    } else {
      // Fallback to login if no role matches.
      getIt<NavigationService>().navigateToLogin();
    }
  }
}
