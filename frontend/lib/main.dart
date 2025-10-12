import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/features/auth/auth_wrapper.dart';
import 'package:oshapp/features/auth/login_screen.dart';
import 'package:oshapp/features/auth/activation_screen.dart';

import 'package:oshapp/features/dashboards/admin_dashboard_screen.dart';
import 'package:oshapp/features/dashboards/doctor_dashboard_screen.dart';
import 'package:oshapp/features/dashboards/employee_dashboard_screen.dart';
import 'package:oshapp/features/dashboards/hse_dashboard_screen.dart';
import 'package:oshapp/features/dashboards/nurse_dashboard_screen.dart';
import 'package:oshapp/features/dashboards/rh_dashboard_screen.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:oshapp/shared/services/navigation_service.dart';
import 'package:oshapp/shared/config/app_theme.dart';
import 'package:oshapp/shared/config/theme_controller.dart';
import 'package:oshapp/shared/config/locale_controller.dart';
import 'package:oshapp/generated/l10n/app_localizations.dart';
import 'package:oshapp/features/appointments/appointment_action_handler_screen.dart';
import 'package:oshapp/features/nurse/nurse_medical_visits_screen.dart';
import 'package:oshapp/shared/models/appointment.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerSingleton<NavigationService>(NavigationService());
  getIt.registerSingleton<ApiService>(ApiService());
  getIt.registerLazySingleton<AuthService>(
      () => AuthService(getIt<ApiService>()));
}

void main() {
  setupLocator();
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize AuthService right after setting up the locator
  getIt<AuthService>().init();
  runApp(const OSHApp());
}

class OSHApp extends StatelessWidget {
  const OSHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: getIt<ApiService>()),
        ChangeNotifierProvider<AuthService>.value(value: getIt<AuthService>()),
        ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController()),
        ChangeNotifierProvider<LocaleController>(
            create: (_) => LocaleController()),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, themeCtl, localeCtl, _) {
          final baseLight = ColorScheme.fromSeed(
            seedColor: themeCtl.seedColor,
            brightness: Brightness.light,
          );
          final light = ThemeData(
            useMaterial3: true,
            colorScheme: baseLight.copyWith(primary: themeCtl.seedColor),
          ).copyWith(
            // Keep existing AppTheme choices where desired
            appBarTheme: AppTheme.lightTheme.appBarTheme,
            inputDecorationTheme: AppTheme.lightTheme.inputDecorationTheme,
            elevatedButtonTheme: AppTheme.lightTheme.elevatedButtonTheme,
            textTheme: AppTheme.lightTheme.textTheme,
          );
          final baseDark = ColorScheme.fromSeed(
            seedColor: themeCtl.seedColor,
            brightness: Brightness.dark,
          );
          final dark = ThemeData(
            useMaterial3: true,
            colorScheme: baseDark.copyWith(primary: themeCtl.seedColor),
          ).copyWith(
            // Ensure textTheme structure matches light to avoid TextStyle lerp issues
            textTheme: AppTheme.lightTheme.textTheme,
          );
          return MaterialApp(
            navigatorKey: getIt<NavigationService>().navigatorKey,
            title: 'OSHApp',
            theme: light,
            darkTheme: dark,
            themeMode: themeCtl.themeMode,
            locale: localeCtl.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('fr')],
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/activation': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                String email = '';
                String? password;
                if (args is Map) {
                  email = (args['email'] as String?) ?? '';
                  password = args['password'] as String?;
                } else if (args is String) {
                  email = args;
                }
                return ActivationScreen(email: email, password: password);
              },
              '/admin_home': (context) =>
                  AdminDashboardScreen(user: getIt<AuthService>().user!),
              '/rh_home': (context) =>
                  RHDashboardScreen(user: getIt<AuthService>().user!),
              '/doctor_home': (context) =>
                  DoctorDashboardScreen(user: getIt<AuthService>().user!),
              '/nurse_home': (context) =>
                  NurseDashboardScreen(user: getIt<AuthService>().user!),
              '/hse_home': (context) =>
                  HseDashboardScreen(user: getIt<AuthService>().user!),
              '/employee_home': (context) =>
                  EmployeeDashboardScreen(user: getIt<AuthService>().user!),
              '/nurse_medical_visits': (context) => const NurseMedicalVisitsScreen(
                    initialIsPlanifier: false,
                    initialStatusFilter: 'Tous',
                    initialTypeFilter: 'Tous',
                    initialVisitModeFilter: 'Tous',
                    initialDepartmentFilter: 'Tous',
                    initialSearch: '',
                  ),
            },
            onGenerateRoute: (settings) {
              final raw = settings.name ?? '';
              Uri? uri;
              try {
                uri = Uri.parse(raw);
              } catch (_) {}
              final path = uri?.path ?? raw;
              if (path.startsWith('/appointment-action') ||
                  path.startsWith('/appointment_action')) {
                final effectiveUri = uri ?? Uri.parse(raw);
                final idStr = effectiveUri.queryParameters['id'];
                String? action = effectiveUri.queryParameters['action'];
                int? id = int.tryParse(idStr ?? '');

                // Fallback: allow passing via settings.arguments map
                if (id == null) {
                  final args = settings.arguments;
                  if (args is Map) {
                    final argId = args['appointmentId'];
                    if (argId is int) {
                      id = argId;
                    } else if (argId is String) {
                      id = int.tryParse(argId);
                    }
                    final argAction = args['action'];
                    if (action == null && argAction is String) {
                      action = argAction;
                    }
                  }
                }

                if (id == null) {
                  return MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: Center(
                          child: Text('Lien invalide: identifiant manquant.')),
                    ),
                  );
                }

                final auth = getIt<AuthService>();
                if (!auth.isAuthenticated) {
                  auth.setPendingRoute(raw, settings.arguments);
                  return MaterialPageRoute(builder: (_) => const LoginScreen());
                }

                return MaterialPageRoute(
                  builder: (_) => AppointmentActionHandlerScreen(
                    appointmentId: id!,
                    action: action,
                  ),
                  settings: settings,
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
