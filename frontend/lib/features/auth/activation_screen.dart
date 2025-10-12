import 'package:flutter/material.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'package:animated_background/animated_background.dart';
import 'package:oshapp/shared/widgets/app_logo.dart';
import 'package:get_it/get_it.dart';
import 'package:oshapp/shared/services/navigation_service.dart';
import 'package:oshapp/main.dart';

class ActivationScreen extends StatefulWidget {
  final String email;
  final String? password;

  const ActivationScreen({super.key, required this.email, this.password});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _onActivate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.activateAccount(_pinController.text);
      
      // If credentials are available (coming from login), auto-login and route to dashboard.
      if ((widget.password ?? '').isNotEmpty) {
        try {
          await authService.login(widget.email, widget.password!);
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          // AuthService handles dashboard navigation; stop here.
          return;
        } catch (_) {
          // Fall back to login screen if auto-login fails for any reason.
        }
      }

      if (mounted) {
        // If the user is already authenticated (ActivationScreen opened from AuthWrapper),
        // send them directly to their dashboard based on role.
        if (authService.isAuthenticated) {
          final roles = authService.roles;
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
            getIt<NavigationService>().navigateToAndRemoveUntil(targetRoute, arguments: authService.user);
            return;
          }
        }

        // Fallback to login if not authenticated or no role matched.
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
          arguments: 'Your account has been activated. Please log in.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onResend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.resendActivationCode(widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A new activation code has been sent to your email.'),
              backgroundColor: Colors.green),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final isFr = lang.toLowerCase().startsWith('fr');

    final titleText = isFr ? 'Activation du compte' : 'Account Activation';
    final descText = isFr
        ? "Un code à 6 chiffres a été envoyé à votre adresse e-mail : ${widget.email}"
        : 'A 6-digit code has been sent to your email address: ${widget.email}';
    final activateLabel = isFr ? 'ACTIVER' : 'ACTIVATE';
    final resendLabel = isFr
        ? "Vous n'avez pas reçu le code ? Renvoyer"
        : "Didn't receive the code? Resend";
    final codeError = isFr
        ? 'Veuillez saisir le code complet'
        : 'Please enter the complete code';
    final goToLoginLabel = isFr ? 'Aller à la connexion' : 'Go to Login';

    return Scaffold(
      body: AnimatedBackground(
        behaviour: RandomParticleBehaviour(
          options: ParticleOptions(
            baseColor: theme.colorScheme.primary,
            spawnOpacity: 0.0,
            opacityChangeRate: 0.25,
            minOpacity: 0.1,
            maxOpacity: 0.3,
            particleCount: 70,
            spawnMaxRadius: 15.0,
            spawnMinRadius: 10.0,
            spawnMaxSpeed: 50.0,
            spawnMinSpeed: 30,
          ),
        ),
        vsync: this,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.92 : 0.96,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const AppLogoSimple(height: 80),
                    const SizedBox(height: 24),
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PinCodeTextField(
                      appContext: context,
                      length: 6,
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      animationType: AnimationType.fade,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(8),
                        fieldHeight: 50,
                        fieldWidth: 40,
                        activeFillColor: theme.colorScheme.surface,
                        inactiveFillColor: theme.colorScheme.surfaceVariant,
                        selectedFillColor: theme.colorScheme.surface,
                        activeColor: theme.colorScheme.primary,
                        inactiveColor: theme.colorScheme.outline,
                        selectedColor: theme.colorScheme.primary,
                        borderWidth: 1,
                      ),
                      onCompleted: (v) => _onActivate(),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return codeError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _onActivate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                            child: Text(
                              activateLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _onResend,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      child: Text(resendLabel),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                (route) => false,
                              ),
                      icon: const Icon(Icons.login_rounded),
                      label: Text(goToLoginLabel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
