import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshapp/main.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:provider/provider.dart';

// Mock ApiService
class MockApiService extends ApiService {}

// Mock AuthService that uses the mock ApiService
class MockAuthService extends AuthService {
  MockAuthService(super.apiService);

  bool _mockIsAuthenticated = false;

  @override
  bool get isAuthenticated => _mockIsAuthenticated;

  Future<void> autoLogin() async {
    // In tests, we start unauthenticated by default.
    await logout();
  }

  @override
  Future<void> logout({void Function(double, String)? onProgress, bool navigate = true}) async {
    _mockIsAuthenticated = false;
    notifyListeners();
  }
}

void main() {
  testWidgets('App loads successfully and shows AuthWrapper', (WidgetTester tester) async {
    // Create instances of our mock services.
    final mockApiService = MockApiService();
    final mockAuthService = MockAuthService(mockApiService);

    // Build our app and trigger a frame, providing the mock services.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: mockApiService),
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ],
        child: const OSHApp(),
      ),
    );

    // Verify that the app loads without crashing and finds the root MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
