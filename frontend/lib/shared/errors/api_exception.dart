class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool needsActivation;
  final bool isDeactivated;

  ApiException({
    required this.message,
    this.statusCode,
    this.needsActivation = false,
    this.isDeactivated = false,
  });

  @override
  String toString() => 'ApiException: $message (Status Code: $statusCode)';
}
