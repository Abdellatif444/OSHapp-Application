import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:oshapp/shared/models/employee_creation_request_dto.dart'
    show EmployeeCreationRequestDTO;

import '../models/appointment.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:oshapp/shared/config/app_config.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'package:oshapp/shared/services/logger_service.dart';
import 'package:oshapp/shared/models/user.dart';
import 'package:oshapp/shared/models/role.dart';
import 'package:oshapp/shared/models/company.dart';
import 'package:oshapp/shared/models/notification.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/models/alert.dart';
import 'package:oshapp/shared/models/activity.dart';
import 'package:oshapp/shared/models/admin_dashboard_data.dart';
import 'package:oshapp/shared/models/doctor_dashboard_data.dart';
import 'package:oshapp/shared/models/nurse_dashboard_data.dart';
import 'package:oshapp/shared/models/hse_dashboard_data.dart';
import 'package:oshapp/shared/models/medical_certificate.dart';
import 'package:oshapp/shared/models/uploaded_medical_certificate.dart';
import 'package:oshapp/shared/models/work_accident.dart';
import 'package:oshapp/shared/models/appointment_request.dart';

class ApiService {
  final Dio _dio = Dio();
  // The token is now managed by AuthService to ensure a single source of truth.
  // The interceptor will dynamically fetch the token from AuthService when needed,
  // or AuthService will set it directly using a new method.

  ApiService() {
    // Normalize base URL to ensure it ends with a trailing '/'. This guarantees
    // correct joining with relative endpoint paths (e.g., 'users/me' becomes
    // '<base>/users/me' regardless of whether the provided base had a slash).
    final base = AppConfig.apiUrl;
    _dio.options.baseUrl = base.endsWith('/') ? base : '$base/';
    // Ensure sane timeouts (avoid Duration.zero which aborts immediately)
    _dio.options
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 60)
      ..sendTimeout = const Duration(seconds: 30);
    if (kDebugMode) {
      debugPrint(
          '--- API_SERVICE: Initialized with baseUrl=${_dio.options.baseUrl}');
    }
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // The Authorization header will be set by the new `setAuthToken` method.
        // Ensure paths are relative to baseUrl '/api/v1/' by stripping a leading '/'
        // so that Dio joins them correctly (e.g., 'users/me' => '/api/v1/users/me').
        final path = options.path;
        if (path.startsWith('/')) {
          options.path = path.substring(1);
        }
        // Log whether Authorization header is present for this request (always)
        final hasAuth = (options.headers['Authorization'] ??
                _dio.options.headers['Authorization']) !=
            null;
        debugPrint(
            '--- API_SERVICE: ${options.method} ${options.path} | Auth header present: $hasAuth');
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
      },
    ));
  }

  Future<T> _handleRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e, stackTrace) {
      // If we immediately get a 401 on a GET/PUT right after login, retry with backoff.
      // This mitigates transient backend token propagation delays.
      try {
        final method = e.requestOptions.method.toUpperCase();
        final hasAuthHeader = _dio.options.headers['Authorization'] != null ||
            e.requestOptions.headers['Authorization'] != null;
        if (e.response?.statusCode == 401 &&
            hasAuthHeader &&
            (method == 'GET' || method == 'PUT')) {
          const retryDelays = [
            Duration(milliseconds: 600),
            Duration(milliseconds: 1200),
          ];
          for (var i = 0; i < retryDelays.length; i++) {
            final delay = retryDelays[i];
            debugPrint(
                '--- API_SERVICE: 401 on $method ${e.requestOptions.path}. '
                'Retrying in ${delay.inMilliseconds}ms (attempt ${i + 1}/${retryDelays.length})...');
            await Future.delayed(delay);
            try {
              return await request();
            } on DioException {
              // Continue to next attempt; final error will be handled below.
            }
          }
        }
      } catch (_) {
        // Fall through to normal error handling below if retries also fail.
      }
      String errorMessage;
      bool needsActivation = false;
      bool isDeactivated = false;

      if (e.response != null) {
        // Handle structured error messages
        if (e.response!.data is Map<String, dynamic>) {
          errorMessage = e.response!.data['message'] ??
              e.response!.data['error'] ??
              'An error occurred.';
          // Handle plain string error messages
        } else if (e.response!.data is String && e.response!.data.isNotEmpty) {
          errorMessage = e.response!.data;
          // Fallback for other unexpected error formats
        } else {
          errorMessage =
              'Received an unexpected error from the server (Status: ${e.response!.statusCode})';
        }

        // Standardize the error string for matching
        final emLow = errorMessage.toLowerCase();

        // Check for account not activated (needs activation)
        if (errorMessage.contains('ACCOUNT_NOT_ACTIVATED') ||
            emLow.contains('account not activated') ||
            emLow.contains('compte non activé') ||
            emLow.contains('compte non active')) {
          needsActivation = true;
          // Provide a friendly, localized message fallback if backend only sent the code
          if (errorMessage == 'ACCOUNT_NOT_ACTIVATED') {
            errorMessage =
                'Votre compte n\'est pas encore activé. Veuillez entrer le code reçu par e-mail.';
          }
        }

        // Check for account deactivated (suspended/inactive)
        if (errorMessage.contains('ACCOUNT_DEACTIVATED') ||
            emLow.contains('account deactivated') ||
            emLow.contains('account inactive') ||
            emLow.contains('user inactive') ||
            emLow.contains('compte désactivé') ||
            emLow.contains('compte desactive') ||
            emLow.contains('compte inactif')) {
          isDeactivated = true;
          if (errorMessage == 'ACCOUNT_DEACTIVATED') {
            errorMessage =
                'Votre compte a été désactivé. Veuillez contacter votre administrateur.';
          }
        }
      } else {
        // Handle network errors where there is no response from the server
        errorMessage =
            e.message ?? 'Network error, please check your connection.';
      }

      LoggerService.error('ApiService DioError: $errorMessage');
      LoggerService.error('URL: ${e.requestOptions.uri}');
      LoggerService.error('Stack Trace: $stackTrace');

      throw ApiException(
        message: errorMessage,
        statusCode: e.response?.statusCode,
        needsActivation: needsActivation,
        isDeactivated: isDeactivated,
      );
    } catch (e, stackTrace) {
      LoggerService.error('ApiService Generic Error: $e');
      LoggerService.error('Stack Trace: $stackTrace');
      throw ApiException(message: 'An unexpected error occurred: $e');
    }
  }

  // Normalize visit types to canonical backend values
  String _normalizeVisitType(String visitType) {
    final raw = visitType
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    const Map<String, String> aliases = {
      'PRE_EMPLOYMENT': 'PRE_RECRUITMENT',
      'EMBAUCHE': 'PRE_RECRUITMENT',
      'HIRING': 'PRE_RECRUITMENT',
      'REPRISE': 'RETURN_TO_WORK',
      'PERIODIQUE': 'PERIODIC',
      'PÉRIODIQUE': 'PERIODIC',
      'ANNUAL': 'PERIODIC',
      'SPONTANEE': 'SPONTANEOUS',
      'SPONTANÉE': 'SPONTANEOUS',
      // UI aliases
      'SPONTANEOUS_REQUEST': 'SPONTANEOUS',
      'DOCTOR_REQUEST': 'SPONTANEOUS',
      // Surveillance particulière
      'SPECIAL_MONITORING': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIÈRE': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIERE': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIEREE': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIEREE_': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIER': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIERE_FR': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIERE_FRANCAIS': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIERE_FRANÇAIS': 'SURVEILLANCE_PARTICULIERE',
      'SURVEILLANCE_PARTICULIERE_LABEL': 'SURVEILLANCE_PARTICULIERE',
      // Medical call / À l'appel du médecin
      'APPEL_DU_MEDECIN': 'MEDICAL_CALL',
      'APPEL_DU_MÉDECIN': 'MEDICAL_CALL',
      'APPEL_MEDECIN': 'MEDICAL_CALL',
      'APPEL_MÉDECIN': 'MEDICAL_CALL',
      'CALL_DOCTOR': 'MEDICAL_CALL',
      'DOCTOR_CALL': 'MEDICAL_CALL',
      'MEDICAL_CALL': 'MEDICAL_CALL',
    };
    final mapped = aliases[raw] ?? raw;
    const allowed = {
      'SPONTANEOUS',
      'PERIODIC',
      'PRE_RECRUITMENT',
      'RETURN_TO_WORK',
      'SURVEILLANCE_PARTICULIERE',
      'MEDICAL_CALL',
      'OTHER'
    };
    return allowed.contains(mapped) ? mapped : 'OTHER';
  }

  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('auth/ping');
      LoggerService.info(
          'Backend connectivity test: ${response.statusCode} - ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      LoggerService.error('Backend connectivity failed: $e');
      return false;
    }
  }

  // Build the server origin (scheme + host[:port] + trailing slash) from the configured baseUrl
  String get _serverOrigin {
    final base = _dio.options.baseUrl;
    try {
      final uri = Uri.parse(base);
      if (uri.scheme.isNotEmpty && uri.authority.isNotEmpty) {
        return '${uri.scheme}://${uri.authority}/';
      }
    } catch (_) {
      // ignore, fallback below
    }
    // Fallback: strip '/api/...' if present to approximate origin
    final idx = base.indexOf('/api/');
    if (idx > 0) {
      return base.substring(0, idx + 1); // keep trailing '/'
    }
    return base.endsWith('/') ? base : '$base/';
  }

  /// Resolve a public URL for a file served under `/uploads/**`.
  /// Accepts absolute URLs and returns them unchanged. For relative paths
  /// (e.g., 'uploads/company-logos/abc.png' or '/uploads/abc.png'), it will
  /// prepend the server origin derived from ApiService baseUrl.
  String? getPublicFileUrl(String? path) {
    if (path == null) return null;
    final p = path.trim();
    if (p.isEmpty) return null;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final origin = _serverOrigin;
    if (p.startsWith('/')) return origin + p.substring(1);
    return origin + p;
  }

  void setAuthToken(String? token) {
    // Remove the header entirely if the token is null or empty
    if (token == null || token.trim().isEmpty) {
      _dio.options.headers.remove('Authorization');
      debugPrint('--- API_SERVICE: Auth token cleared. ---');
      return;
    }

    // Normalize: trim and ensure exactly one 'Bearer ' prefix (case-insensitive)
    final t = token.trim();
    final bare =
        t.toLowerCase().startsWith('bearer ') ? t.substring(7).trim() : t;
    final sanitized = 'Bearer $bare';
    _dio.options.headers['Authorization'] = sanitized;
    debugPrint(
        '--- API_SERVICE: Auth token updated (Bearer prefix normalized). ---');
  }

  Future<void> logout() async {
    setAuthToken(null);
    LoggerService.info(
        '--- FRONTEND: ApiService logout called, token cleared. ---');
  }

  Future<User> getMe() async {
    return _handleRequest(() async {
      final response = await _dio.get('users/me');
      return User.fromJson(response.data);
    });
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _dio.options.headers.remove('Authorization');
    return _handleRequest(() async {
      debugPrint(
          '--- API_SERVICE: Sending POST to /auth/login with email: $email ---');
      final response = await _dio.post(
        'auth/login',
        data: {'email': email, 'password': password},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) =>
              status != null && status < 500, // Handle non-200 gracefully
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        // Ensure the response data is a Map.
        final responseData = response.data is String
            ? json.decode(response.data) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        // Token is no longer stored in ApiService.
        // It will be returned to AuthService, which is responsible for storage and state management.
        return responseData;
      } else {
        // Manually throw a DioException for non-2xx responses so _handleRequest can process it.
        // This ensures our custom error handling logic in _handleRequest is triggered.
        throw DioException.badResponse(
          statusCode: response.statusCode!,
          requestOptions: response.requestOptions,
          response: response,
        );
      }
    });
  }

  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    _dio.options.headers.remove('Authorization');
    return _handleRequest(() async {
      debugPrint('--- API_SERVICE: Sending POST to /auth/google ---');
      final response = await _dio.post(
        'auth/google',
        data: {'idToken': idToken},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) =>
              status != null && status < 500, // Handle non-200 gracefully
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        // Ensure the response data is a Map.
        final responseData = response.data is String
            ? json.decode(response.data) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        return responseData;
      } else {
        // Manually throw a DioException for non-2xx responses so _handleRequest can process it.
        throw DioException.badResponse(
          statusCode: response.statusCode!,
          requestOptions: response.requestOptions,
          response: response,
        );
      }
    });
  }

  Future<void> forgotPassword(String email) async {
    return _handleRequest(
        () => _dio.post('auth/forgot-password', data: {'email': email}));
  }

  Future<void> resetPassword(String token, String newPassword) async {
    return _handleRequest(() => _dio.post(
          'auth/reset-password',
          data: {
            'token': token,
            'newPassword': newPassword,
          },
        ));
  }

  Future<List<Role>> getRoles() async {
    return _handleRequest(() async {
      final response = await _dio.get('admin/roles');
      return (response.data as List)
          .map((json) => Role.fromJson(json))
          .toList();
    });
  }

  Future<Role> createRole(String name, List<String> permissions) async {
    return _handleRequest(() async {
      final response = await _dio.post('admin/roles', data: {
        'name': name,
        'permissions': permissions,
      });
      return Role.fromJson(response.data);
    });
  }

  Future<Role> updateRole(
      int roleId, String name, List<String> permissions) async {
    return _handleRequest(() async {
      final response = await _dio.put('admin/roles/$roleId', data: {
        'name': name,
        'permissions': permissions,
      });
      return Role.fromJson(response.data);
    });
  }

  Future<void> deleteRole(int roleId) async {
    return _handleRequest(() => _dio.delete('admin/roles/$roleId'));
  }

  Future<List<AppNotification>> getNotifications() async {
    return _handleRequest(() async {
      final response = await _dio.get('notifications');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final dynamic content =
            data['content'] ?? data['items'] ?? data['data'];
        if (content is List) {
          return content.map((json) => AppNotification.fromJson(json)).toList();
        }
      }
      if (data is List) {
        return data.map((json) => AppNotification.fromJson(json)).toList();
      }
      return [];
    });
  }

  Future<Map<String, dynamic>> checkProfileStatus() async {
    return _handleRequest(() async {
      final response = await _dio.get('employees/profile/status');
      if (response.data is Map<String, dynamic>) {
        return response.data;
      } else {
        throw Exception('Unexpected format for profile status');
      }
    });
  }

  Future<bool> checkManagerStatus() async {
    return _handleRequest(() async {
      try {
        final response = await _dio.get('employees/manager/status');
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data['isManager'] ?? false;
        }
        if (data is bool) return data;
        return false;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          debugPrint(
              '--- API_SERVICE: manager/status not found (404). Assuming not manager.');
          return false;
        }
        rethrow;
      }
    });
  }

  Future<Map<String, dynamic>> getProfile() async {
    return _handleRequest(() async {
      final response = await _dio.get('employees/profile');
      return response.data;
    });
  }

  Future<Employee> getCurrentEmployeeProfile() async {
    return _handleRequest(() async {
      final response = await _dio.get('employees/profile/me');
      // The backend returns a UserResponseDTO: { id, email, roles, employee: { ...EmployeeProfileDTO } }
      // Ensure we extract and parse the nested 'employee' object.
      final Map<String, dynamic> data = response.data is String
          ? json.decode(response.data as String) as Map<String, dynamic>
          : (response.data as Map<String, dynamic>);

      final dynamic empNode = data['employee'];
      Map<String, dynamic>? empJson;
      if (empNode is Map<String, dynamic>) {
        empJson = empNode;
      } else if (empNode is String && empNode.trim().isNotEmpty) {
        // In case the server serialized the employee object as a JSON string.
        try {
          empJson = json.decode(empNode) as Map<String, dynamic>;
        } catch (_) {
          empJson = null;
        }
      }

      if (empJson == null) {
        throw ApiException(
            message: 'Unexpected response format: missing employee profile');
      }

      return Employee.fromJson(empJson);
    });
  }

  Future<List<Employee>> getSubordinates() async {
    return _handleRequest(() async {
      final response = await _dio.get('employees/subordinates');
      return (response.data as List).map((e) => Employee.fromJson(e)).toList();
    });
  }

  Future<List<Employee>> getAllEmployees() async {
    return _handleRequest(() async {
      final response = await _dio.get('employees');
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (data is Map<String, dynamic> && data['content'] is List) {
        final List<dynamic> content = data['content'];
        return content
            .map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
            message: 'Unexpected response format for getAllEmployees');
      }
    });
  }

  Future<Appointment> createAppointment(
      AppointmentRequest appointmentRequest) async {
    return _handleRequest(() async {
      // Normalize visit type to backend-supported enum before sending
      final Map<String, dynamic> payload =
          Map<String, dynamic>.from(appointmentRequest.toJson());
      final t = payload['type'];
      if (t is String && t.trim().isNotEmpty) {
        payload['type'] = _normalizeVisitType(t);
      }
      final response =
          await _dio.post('appointments/Rendez-vous-spontanee', data: payload);
      if (response.data != null && response.data is Map<String, dynamic>) {
        return Appointment.fromJson(response.data);
      } else {
        throw ApiException(
            message:
                'La création du rendez-vous a echoué. Réponse invalide du serveur.');
      }
    });
  }

  Future<Map<String, dynamic>> getAppointments(
      Map<String, dynamic> filters) async {
    return _handleRequest(() async {
      const url = 'appointments/filter';
      // Normalize payload
      final Map<String, dynamic> payload = Map<String, dynamic>.from(filters);
      // Extract pageable params to query string (Spring Pageable reads from query, not body)
      final Map<String, dynamic> query = {};
      if (payload.containsKey('page')) {
        query['page'] = payload.remove('page');
      }
      if (payload.containsKey('size')) {
        query['size'] = payload.remove('size');
      }
      if (payload.containsKey('sort')) {
        query['sort'] = payload.remove('sort');
      }
      // Support alias 'visitType' -> 'type' if provided by some UI flows
      if (payload.containsKey('visitType') &&
          (payload['type'] == null ||
              (payload['type'].toString()).trim().isEmpty)) {
        final vt = payload['visitType'];
        if (vt is String && vt.trim().isNotEmpty) {
          payload['type'] = _normalizeVisitType(vt);
        }
        payload.remove('visitType');
      }
      // Normalize type if present
      final t = payload['type'];
      if (t is String && t.trim().isNotEmpty) {
        payload['type'] = _normalizeVisitType(t);
      }
      // Ensure date fields are serialized correctly
      if (payload['dateFrom'] is DateTime) {
        payload['dateFrom'] =
            (payload['dateFrom'] as DateTime).toLocal().toIso8601String();
      }
      if (payload['dateTo'] is DateTime) {
        payload['dateTo'] =
            (payload['dateTo'] as DateTime).toLocal().toIso8601String();
      }
      LoggerService.info(
          '--- FRONTEND: Calling POST $url query=$query body=$payload ---');

      final response =
          await _dio.post(url, data: payload, queryParameters: query);

      if (response.data is Map<String, dynamic> &&
          response.data.containsKey('content')) {
        final appointments = (response.data['content'] as List)
            .map((item) => Appointment.fromJson(item))
            .toList();
        return {
          'appointments': appointments,
          'totalPages': response.data['totalPages'] ?? 1,
          'totalElements': response.data['totalElements'] ?? 0,
        };
      } else {
        throw Exception('Unexpected response format for getAppointments');
      }
    });
  }

  Future<List<Appointment>> getAppointmentsForEmployee(int employeeId) async {
    final Map<String, dynamic> data =
        await getAppointments({'employeeId': employeeId});
    return data['appointments'] as List<Appointment>;
  }

  Future<List<Appointment>> getMyAppointments({String? status}) async {
    return _handleRequest(() async {
      // Request a larger first page and sort by creation time descending so newest appear
      final params = <String, dynamic>{
        'page': 0,
        'size': 100,
        'sort': 'createdAt,desc',
        if (status != null)
          'status':
              status, // backend currently ignores this on /my-appointments
      };
      final response = await _dio.get('appointments/my-appointments',
          queryParameters: params);
      if (response.data is Map<String, dynamic> &&
          response.data.containsKey('content')) {
        final List<dynamic> data = response.data['content'];
        final appointments = data
            .map((json) => Appointment.fromJson(json as Map<String, dynamic>))
            .toList();
        // Debug: log fetched counts grouped by UI status
        try {
          if (kDebugMode) {
            final Map<String, int> byUi = {};
            for (final a in appointments) {
              final key = a.statusUiCategory ?? 'UNKNOWN';
              byUi[key] = (byUi[key] ?? 0) + 1;
            }
            debugPrint(
                '--- API_SERVICE: /appointments/my-appointments -> ${appointments.length} items. By UI status: $byUi');
          }
        } catch (_) {
          // ignore logging errors
        }
        return appointments;
      } else {
        return [];
      }
    });
  }

  Future<List<Appointment>> getRequestedAppointments() async {
    return _handleRequest(() async {
      final response = await _dio.get('appointments/requested');
      return (response.data as List)
          .map((e) => Appointment.fromJson(e))
          .toList();
    });
  }

  Future<Appointment> getAppointmentById(int appointmentId) async {
    return _handleRequest(() async {
      final response = await _dio.get('appointments/$appointmentId');
      return Appointment.fromJson(response.data);
    });
  }

  Future<Appointment> updateAppointment(
      int appointmentId, Map<String, dynamic> updates) async {
    return _handleRequest(() async {
      final response =
          await _dio.put('appointments/$appointmentId', data: updates);
      return Appointment.fromJson(response.data);
    });
  }

  Future<void> cancelAppointment(int appointmentId, {String? reason}) async {
    return _handleRequest(() async {
      await _dio.post('appointments/$appointmentId/cancel',
          data: {'reason': reason ?? 'Cancelled by user'});
    });
  }

  Future<void> confirmAppointment(int appointmentId, {String? visitMode}) async {
    final params = visitMode != null ? {'visitMode': visitMode} : <String, dynamic>{};
    return _handleRequest(
        () => _dio.post('appointments/$appointmentId/confirm', queryParameters: params));
  }

  Future<void> proposeAppointmentSlot({
    required int appointmentId,
    required DateTime proposedDate,
    String? comments,
    String? visitMode,
  }) async {
    return _handleRequest(() async {
      await _dio.post('appointments/$appointmentId/propose-slot', data: {
        'proposedDate': proposedDate.toIso8601String(),
        'comments': comments,
        'visitMode': visitMode,
      });
    });
  }

  Future<void> deleteAppointment(int appointmentId) async {
    return _handleRequest(() async {
      await _dio.delete('appointments/$appointmentId');
    });
  }

  Future<Appointment> planMedicalVisit(Map<String, dynamic> planRequest) async {
    return _handleRequest(() async {
      // Normalize and sanitize payload before sending
      final Map<String, dynamic> payload = Map<String, dynamic>.from(planRequest);
      final t = payload['type'];
      if (t is String && t.trim().isNotEmpty) {
        payload['type'] = _normalizeVisitType(t);
      }
      final sdt = payload['scheduledDateTime'];
      if (sdt is DateTime) {
        payload['scheduledDateTime'] = sdt.toIso8601String();
      }
      final response = await _dio.post('appointments/plan-medical-visit', data: payload);
      if (response.data != null && response.data is Map<String, dynamic>) {
        return Appointment.fromJson(response.data);
      } else {
        throw ApiException(
            message: 'Invalid response format for planMedicalVisit');
      }
    });
  }

  Future<List<int>> deleteAppointmentsBulk(List<int> appointmentIds) async {
    return _handleRequest(() async {
      final List<int> failed = [];
      for (final id in appointmentIds) {
        try {
          await _dio.delete('appointments/$id');
        } catch (e) {
          failed.add(id);
          debugPrint('Failed to delete appointment $id: $e');
        }
      }
      return failed;
    });
  }

  Future<void> updateAppointmentStatus(int appointmentId, String status) async {
    return _handleRequest(() => _dio.put(
          'appointments/$appointmentId/status',
          queryParameters: {'status': status},
        ));
  }

  Future<Map<String, dynamic>> getMedicalRecord(int employeeId) async {
    return _handleRequest(() =>
        _dio.get('medical-records/$employeeId').then((resp) => resp.data));
  }

  Future<Map<String, dynamic>> createMedicalRecord(
      Map<String, dynamic> recordData) async {
    return _handleRequest(() => _dio
        .post('medical-records', data: recordData)
        .then((resp) => resp.data));
  }

  Future<Map<String, dynamic>> updateMedicalRecord(
      int recordId, Map<String, dynamic> updates) async {
    return _handleRequest(() => _dio
        .put('medical-records/$recordId', data: updates)
        .then((resp) => resp.data));
  }

  Future<Map<String, dynamic>> getMedicalFitness(int employeeId) async {
    return _handleRequest(() => _dio
        .get('employees/medical-fitness/$employeeId')
        .then((resp) => resp.data));
  }

  Future<Map<String, dynamic>> updateMedicalFitness(
      int employeeId, Map<String, dynamic> fitnessData) async {
    return _handleRequest(() => _dio
        .put('employees/medical-fitness/$employeeId', data: fitnessData)
        .then((resp) => resp.data));
  }

  Future<List<dynamic>> getMedicalFitnessHistory(int employeeId) async {
    return _handleRequest(() => _dio
        .get('employees/medical-fitness/history/$employeeId')
        .then((resp) => resp.data));
  }

  /// Get medical fitness data for the current user
  Future<Map<String, dynamic>> getMedicalFitnessData() async {
    final currentUser = await getCurrentEmployeeProfile();
    final employeeId = int.parse(currentUser.id);
    return getMedicalFitness(employeeId);
  }

  Future<Map<String, dynamic>> getDashboardStatistics() async {
    return _handleRequest(
        () => _dio.get('statistics/admin').then((res) => res.data));
  }

  Future<Map<String, dynamic>> getRhDashboardStatistics() async {
    return _handleRequest(() => _dio
        .get('statistics/rh')
        .then((res) => res.data as Map<String, dynamic>));
  }

  Future<Company> getCompanyProfile() async {
    return _handleRequest(() async {
      final response = await _dio.get('company-profile');
      return Company.fromJson(response.data);
    });
  }

  Future<Company> updateCompanyProfile(Company companyData) async {
    return _handleRequest(() async {
      final response =
          await _dio.put('company-profile', data: companyData.toJson());
      return Company.fromJson(response.data);
    });
  }

  /// Upload a company logo image (PNG/JPG, max 5MB) as multipart/form-data.
  /// Backend endpoint: POST /api/v1/company-profile/logo
  /// Returns the updated Company entity with the new logoUrl set.
  Future<Company> uploadCompanyLogo({
    required List<int> bytes,
    required String filename,
  }) async {
    return _handleRequest(() async {
      final formData = FormData();

      // Infer MIME type from filename extension (default to image/jpeg)
      final lower = filename.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';

      formData.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse(mime),
        ),
      ));

      if (kDebugMode) {
        debugPrint(
            '--- API_SERVICE: POST /company-profile/logo file=$filename (${bytes.length} bytes, mime=$mime)');
      }

      final response = await _dio.post(
        'company-profile/logo',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return Company.fromJson(response.data);
    });
  }

  Future<Map<String, dynamic>> getSettings() async {
    return _handleRequest(
        () => _dio.get('admin/settings').then((resp) => resp.data));
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    // Backend expects a JSON array of { key, value } objects (List<Setting>).
    final List<Map<String, String>> payload = settings.entries
        .map((e) => {
              'key': e.key,
              'value': e.value == null ? '' : e.value.toString(),
            })
        .toList();
    return _handleRequest(() => _dio.put('admin/settings', data: payload));
  }

  Future<List<Map<String, dynamic>>> getAuditLogs(
      {int page = 0, int size = 20}) async {
    return _handleRequest(() async {
      final response = await _dio.get('admin/audit-logs',
          queryParameters: {'page': page, 'size': size});
      return (response.data['content'] as List).cast<Map<String, dynamic>>();
    });
  }

  Future<List<Employee>> searchEmployees(String query) async {
    return _handleRequest(() async {
      if (query.isEmpty) {
        return [];
      }
      final response = await _dio.get('employees');
      final employees =
          (response.data as List).map((e) => Employee.fromJson(e)).toList();
      final q = query.toLowerCase();
      return employees.where((emp) {
        final name = emp.fullName.toLowerCase();
        return name.contains(q);
      }).toList();
    });
  }

  Future<int> getUnreadNotificationCount() async {
    return _handleRequest(() async {
      final response = await _dio.get('notifications/count');
      final data = response.data;
      if (data is int) return data;
      if (data is num) return data.toInt();
      if (data is String) return int.tryParse(data) ?? 0;
      if (data is Map<String, dynamic>) {
        final c = data['count'];
        if (c is int) return c;
        if (c is num) return c.toInt();
        if (c is String) return int.tryParse(c) ?? 0;
      }
      return 0;
    });
  }

  Future<List<AppNotification>> getMyNotifications({bool? isRead}) async {
    return _handleRequest(() async {
      // If explicitly requesting unread only, use the dedicated endpoint.
      if (isRead == false) {
        final res = await _dio.get('notifications/unread');
        final data = res.data;
        if (data is List) {
          return data
              .map((json) =>
                  AppNotification.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        if (data is Map && data['content'] is List) {
          return (data['content'] as List)
              .map((json) =>
                  AppNotification.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      }

      // Default: fetch paginated notifications and optionally filter read ones client-side.
      final response = await _dio.get(
        'notifications',
        queryParameters: {
          'page': 0,
          'size': 50,
          'sort': 'createdAt,desc',
        },
      );
      List list;
      if (response.data is Map && response.data['content'] is List) {
        list = response.data['content'] as List;
      } else if (response.data is List) {
        list = response.data as List;
      } else {
        list = const [];
      }
      final items = list
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
      if (isRead == true) {
        return items.where((n) => n.read).toList();
      }
      return items;
    });
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    return _handleRequest(
        () => _dio.patch('notifications/$notificationId/read'));
  }

  Future<void> markAllNotificationsAsRead() async {
    return _handleRequest(() => _dio.patch('notifications/read-all'));
  }

  Future<void> deleteNotification(int notificationId) async {
    return _handleRequest(() => _dio.delete('notifications/$notificationId'));
  }

  Future<List<int>> deleteNotificationsBulk(List<int> notificationIds) async {
    return _handleRequest(() async {
      final List<int> failed = [];
      for (final id in notificationIds) {
        try {
          await _dio.delete('notifications/$id');
        } catch (e) {
          // Continue deleting others; collect failures to report at the end
          failed.add(id);
          debugPrint('Failed to delete notification $id: $e');
        }
      }
      return failed;
    });
  }

  Future<void> sendAppointmentNotification(
      {required int appointmentId,
      required String notificationType,
      required List<int> recipientIds,
      String? customMessage}) async {
    // No-op: backend triggers notifications automatically on appointment events.
    return _handleRequest(() async {
      debugPrint(
          'ApiService.sendAppointmentNotification: no-op; backend auto-notifies relevant users.');
    });
  }

  Future<void> sendObligatoryVisitNotification(
      {required List<int> employeeIds,
      required String message,
      Map<String, dynamic>? metadata}) async {
    // No-op: obligatory visit notifications are sent server-side when creating obligatory appointments.
    return _handleRequest(() async {
      debugPrint(
          'ApiService.sendObligatoryVisitNotification: no-op; backend handles notifications.');
    });
  }

  Future<Employee> updateEmployeeProfile(
      EmployeeCreationRequestDTO employeeDetails) async {
    return _handleRequest(() async {
      // If a userId is provided, this is an admin-driven update for a specific user.
      // Otherwise, update the currently authenticated user's profile.
      final bool hasUserId = employeeDetails.userId != null;
      final String url = hasUserId
          ? 'admin/users/${employeeDetails.userId}/employee-profile'
          : 'employees/profile';
      final response = await _dio.put(
        url,
        data: employeeDetails.toJson(),
      );
      return Employee.fromJson(response.data);
    });
  }

  Future<List<Appointment>> getAppointmentHistory(
      {int page = 0, int size = 20}) async {
    return _handleRequest(() async {
      final response = await _dio.get(
        'appointments/history',
        queryParameters: {
          'page': page,
          'size': size,
          'sort': 'updatedAt,desc',
        },
      );
      if (response.data != null && response.data['content'] is List) {
        return (response.data['content'] as List)
            .map((e) => Appointment.fromJson(e))
            .toList();
      }
      return [];
    });
  }

  Future<Employee> createEmployee(Map<String, dynamic> employeeData) async {
    return _handleRequest(() async {
      final response = await _dio.post('employees', data: employeeData);
      return Employee.fromJson(response.data);
    });
  }

  Future<Employee> createCompleteEmployee(
      EmployeeCreationRequestDTO request) async {
    return _handleRequest(() async {
      final response = await _dio.post(
        'employees/create-complete',
        data: request.toJson(),
      );
      return Employee.fromJson(response.data);
    });
  }

  Future<Employee> updateEmployeeManagers(int employeeId,
      {int? manager1Id, int? manager2Id}) async {
    return _handleRequest(() async {
      // Always include keys even when null so backend can clear assignments
      final Map<String, dynamic> payload = {
        'manager1Id': manager1Id,
        'manager2Id': manager2Id,
      };
      if (kDebugMode) {
        debugPrint(
            '--- API_SERVICE: PUT /admin/employees/$employeeId/managers payload=${jsonEncode(payload)}');
      }
      final response = await _dio.put(
        'admin/employees/$employeeId/managers',
        data: payload,
      );
      if (kDebugMode) {
        debugPrint(
            '--- API_SERVICE: updateEmployeeManagers -> status ${response.statusCode}');
      }
      return Employee.fromJson(response.data);
    });
  }

  Future<void> deleteEmployeeById(int employeeId) async {
    return _handleRequest(() => _dio.delete('employees/$employeeId'));
  }

  Future<Appointment> createMandatoryAppointment(
      AppointmentRequest request) async {
    return _handleRequest(() async {
      final response =
          await _dio.post('appointments/mandatory', data: request.toJson());
      return Appointment.fromJson(response.data);
    });
  }

  Future<void> createObligatoryAppointments(
      List<int> employeeIds, DateTime visitDate, String visitType,
      {String? reason, String? notes}) async {
    return _handleRequest(() async {
      // Normalize visit type to backend enum values
      final String normalizedType = _normalizeVisitType(visitType);

      // Use local time and ISO format without timezone for LocalDateTime on backend
      final scheduledAt = visitDate.toLocal().toIso8601String();

      // Backend processes a single employeeId per request; send one request per employee
      for (final id in employeeIds) {
        final payload = {
          'employeeId': id,
          'type': normalizedType,
          'scheduledTime': scheduledAt,
        };
        if (reason != null && reason.trim().isNotEmpty) {
          payload['reason'] = reason.trim();
        }
        if (notes != null && notes.trim().isNotEmpty) {
          payload['notes'] = notes.trim();
        }
        if (kDebugMode) {
          debugPrint(
              '--- API_SERVICE: POST /appointments/obligatory payload=${jsonEncode(payload)}');
        }
        await _dio.post('appointments/obligatory', data: payload);
      }
    });
  }

  /// Upload a medical certificate PDF for a specific employee.
  /// Backend endpoint: POST /hr/medical-certificates/upload (multipart/form-data)
  /// Params:
  /// - employeeId (required)
  /// - certificateType (optional)
  /// - issueDate (optional, LocalDate ISO "yyyy-MM-dd")
  /// - file (MultipartFile, PDF)
  Future<void> uploadMedicalCertificate({
    required int employeeId,
    required String filename,
    // Provide either a filePath or a stream+length. Prefer filePath when available.
    String? filePath,
    Stream<List<int>>? stream,
    int? length,
    String? certificateType,
    DateTime? issueDate,
  }) async {
    return _handleRequest(() async {
      // Serialize date-only if provided
      String? dateOnly;
      if (issueDate != null) {
        final iso = issueDate.toLocal().toIso8601String();
        dateOnly = iso.split('T').first; // yyyy-MM-dd
      }

      final Map<String, dynamic> fields = {
        'employeeId': employeeId,
        if (certificateType != null && certificateType.trim().isNotEmpty)
          'certificateType': certificateType.trim(),
        if (dateOnly != null) 'issueDate': dateOnly,
      };

      final formData = FormData();
      // Add scalar fields first
      fields.forEach(
          (key, value) => formData.fields.add(MapEntry(key, value.toString())));
      // Add the file part using a streaming-friendly approach
      MultipartFile filePart;
      final hasPath = filePath != null && filePath.trim().isNotEmpty;
      if (!hasPath && (stream == null || length == null)) {
        throw ApiException(
            message: 'No file provided: expected filePath or stream+length');
      }
      if (hasPath) {
        filePart =
            await MultipartFile.fromFile(filePath.trim(), filename: filename);
      } else {
        final Stream<List<int>> s = stream!;
        final int len = length!;
        filePart = MultipartFile.fromStream(() => s, len, filename: filename);
      }
      formData.files.add(MapEntry('file', filePart));

      if (kDebugMode) {
        try {
          final logFields = Map<String, dynamic>.from(fields);
          final src = hasPath
              ? 'path=${filePath.trim()}'
              : 'stream(len=${length ?? -1})';
          debugPrint(
              '--- API_SERVICE: POST /hr/medical-certificates/upload fields=' +
                  jsonEncode(logFields) +
                  ' file=' +
                  filename +
                  ' src=' +
                  src);
        } catch (_) {}
      }

      await _dio.post(
        'hr/medical-certificates/upload',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    });
  }

  Future<List<User>> getAllUsers() async {
    return _handleRequest(() async {
      final response =
          await _dio.get('admin/users', queryParameters: {'fetchAll': true});
      debugPrint('user data : ${response.data.toString()}');
      return (response.data as List).map((e) => User.fromJson(e)).toList();
    });
  }

  Future<bool> checkEmailExists(String email) async {
    return _handleRequest(() async {
      final response = await _dio.get(
        'admin/users/check-email',
        queryParameters: {'email': email.trim()},
      );
      final data = response.data;
      if (data is bool) return data;
      if (data is String) {
        final s = data.trim().toLowerCase();
        if (s == 'true') return true;
        if (s == 'false') return false;
      }
      if (data is Map) {
        final dynamic exists = data['exists'] ??
            data['data'] ??
            data['value'] ??
            data['emailExists'];
        if (exists is bool) return exists;
        if (exists is String) {
          final s = exists.trim().toLowerCase();
          if (s == 'true') return true;
          if (s == 'false') return false;
        }
      }
      throw ApiException(
          message: 'Unexpected response format for checkEmailExists');
    });
  }

  Future<User> createUser(
      String email, String password, List<String> roles) async {
    return _handleRequest(() async {
      const allowed = {
        'ROLE_ADMIN',
        'ROLE_RH',
        'ROLE_NURSE',
        'ROLE_DOCTOR',
        'ROLE_HSE',
        'ROLE_EMPLOYEE',
      };
      final sanitizedRoles = roles
          .map((r) => r.trim().toUpperCase())
          .where((r) => allowed.contains(r))
          .toSet()
          .toList();

      final payload = {
        'email': email.trim(),
        'password': password,
        'roles': sanitizedRoles,
      };
      if (kDebugMode) {
        final logPayload = Map<String, dynamic>.from(payload);
        if (logPayload.containsKey('password')) logPayload['password'] = '***';
        debugPrint(
            '--- API_SERVICE: POST /admin/users payload=${jsonEncode(logPayload)}');
      }
      final response = await _dio.post('admin/users', data: payload);
      return User.fromJson(response.data);
    });
  }

  Future<User> updateUser(int userId,
      {String? email,
      List<String>? roles,
      bool? isActive,
      String? password}) async {
    return _handleRequest(() async {
      final Map<String, dynamic> payload = {};
      if (email != null) payload['email'] = email.trim();
      if (roles != null) {
        const allowed = {
          'ROLE_ADMIN',
          'ROLE_RH',
          'ROLE_NURSE',
          'ROLE_DOCTOR',
          'ROLE_HSE',
          'ROLE_EMPLOYEE',
        };
        final sanitizedRoles = roles
            .map((r) => r.trim().toUpperCase())
            .where((r) => allowed.contains(r))
            .toSet()
            .toList();
        payload['roles'] = sanitizedRoles;
      }
      if (isActive != null) payload['active'] = isActive;
      if (password != null && password.trim().isNotEmpty) {
        payload['password'] = password;
      }
      if (kDebugMode) {
        final logPayload = Map<String, dynamic>.from(payload);
        if (logPayload.containsKey('password')) logPayload['password'] = '***';
        debugPrint(
            '--- API_SERVICE: PUT /admin/users/$userId payload=${jsonEncode(logPayload)}');
      }
      final response = await _dio.put('admin/users/$userId', data: payload);
      return User.fromJson(response.data);
    });
  }

  Future<void> deleteUser(int userId) async {
    return _handleRequest(() async {
      if (kDebugMode) {
        debugPrint('--- API_SERVICE: DELETE /admin/users/$userId');
      }
      await _dio.delete('admin/users/$userId');
    });
  }

  Future<List<Alert>> getRhDashboardAlerts() async {
    return _handleRequest(() async {
      final response = await _dio.get('statistics/rh/alerts');
      return (response.data as List)
          .map((json) => Alert.fromJson(json))
          .toList();
    });
  }

  Future<List<Activity>> getRhDashboardActivities() async {
    return _handleRequest(() async {
      final response = await _dio.get('statistics/rh/activities');
      return (response.data as List)
          .map((json) => Activity.fromJson(json))
          .toList();
    });
  }

  Future<DoctorDashboardData> getDoctorDashboardData() async {
    return _handleRequest(() async {
      final response = await _dio.get('doctor/dashboard');
      return DoctorDashboardData.fromJson(response.data);
    });
  }

  Future<NurseDashboardData> getNurseDashboardData() async {
    return _handleRequest(() async {
      final response = await _dio.get('nurse/dashboard');
      return NurseDashboardData.fromJson(response.data);
    });
  }

  Future<AdminDashboardData> getAdminDashboardData() async {
    return _handleRequest(() async {
      final response = await _dio.get('admin/dashboard');
      return AdminDashboardData.fromJson(response.data);
    });
  }

  Future<List<MedicalCertificate>> getMedicalCertificates() async {
    return _handleRequest(() async {
      final response = await _dio.get('hr/medical-certificates');
      return (response.data as List)
          .map((json) => MedicalCertificate.fromJson(json))
          .toList();
    });
  }

  Future<List<UploadedMedicalCertificate>>
      getUploadedMedicalCertificates() async {
    return _handleRequest(() async {
      final response = await _dio.get('hr/medical-certificates/uploads');
      return (response.data as List)
          .map((json) => UploadedMedicalCertificate.fromJson(json))
          .toList();
    });
  }

  /// Nurse-accessible: fetch uploaded medical certificates for a specific employee.
  /// Backend endpoint: GET /api/v1/nurse/medical-certificates/uploads?employeeId=...
  Future<List<UploadedMedicalCertificate>>
      getUploadedMedicalCertificatesForEmployee(int employeeId) async {
    return _handleRequest(() async {
      final response = await _dio.get(
        'nurse/medical-certificates/uploads',
        queryParameters: {'employeeId': employeeId},
      );
      return (response.data as List)
          .map((json) => UploadedMedicalCertificate.fromJson(json))
          .toList();
    });
  }

  Future<List<WorkAccident>> getWorkAccidents() async {
    return _handleRequest(() async {
      final response = await _dio.get('hr/work-accidents');
      return (response.data as List)
          .map((json) => WorkAccident.fromJson(json))
          .toList();
    });
  }

  Future<void> requestMandatoryVisits(
      List<int> employeeIds, String visitType) async {
    try {
      final String normalizedType = _normalizeVisitType(visitType);
      await _dio.post('hr/mandatory-visits', data: {
        'employeeIds': employeeIds,
        'visitType': normalizedType,
      });
    } catch (e) {
      // Handle error
      LoggerService.error('Failed to request mandatory visits: $e');
      rethrow;
    }
  }

  Future<HseDashboardData> getHseDashboardData() async {
    return _handleRequest(() async {
      final response = await _dio.get('hse/dashboard');
      return HseDashboardData.fromJson(response.data);
    });
  }

  Future<void> activateAccount(String token) async {
    return _handleRequest(() async {
      await _dio.post('account/activate', data: {'token': token});
    });
  }

  Future<void> resendActivationCode(String email) async {
    return _handleRequest(() async {
      await _dio.post('account/resend-activation', data: {'email': email});
    });
  }

  Future<void> resetAllAppointments() async {
    return _handleRequest(() async {
      await _dio.delete('appointments/reset-all');
    });
  }

  Future<void> resetAllNotifications() async {
    return _handleRequest(() async {
      await _dio.delete('notifications/reset-all');
    });
  }
}
