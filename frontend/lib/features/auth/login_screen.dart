import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:oshapp/shared/config/app_config.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:oshapp/features/auth/forgot_password_screen.dart';
import 'package:oshapp/main.dart';
import 'package:oshapp/shared/services/navigation_service.dart';
import 'package:oshapp/shared/config/theme_controller.dart';
import 'package:oshapp/shared/config/locale_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _didShowInitMessage = false;
  bool _isThemePanelOpen = false;
  bool _isDeactivatedAccount = false;
  // Animations: subtle pulses for background bubbles and fade-ins for panels
  late final AnimationController _pulseCtl;
  late final AnimationController _fadeCtl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale1;
  late final Animation<double> _scale2;
  late final Animation<double> _scale3;
  late final Animation<double> _opacity1;
  late final Animation<double> _opacity2;
  late final Animation<double> _opacity3;

  // Loading overlay state
  bool _showSuccess = false;
  double _authProgress = 0.0; // 0..1
  Timer? _progressTimer;
  String _progressMessage = 'Préparation...';

  @override
  void initState() {
    super.initState();
    // Gentle repeating pulse for decorative bubbles to mirror V0's ping/bounce
    _pulseCtl = AnimationController(
      vsync: this,
      // Slow down to align with V0's 15–20s subtle ping durations
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);

    _scale1 = Tween(begin: 0.98, end: 1.06).animate(
      CurvedAnimation(
          parent: _pulseCtl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeInOut)),
    );
    _scale2 = Tween(begin: 0.98, end: 1.06).animate(
      CurvedAnimation(
          parent: _pulseCtl,
          curve: const Interval(0.2, 0.7, curve: Curves.easeInOut)),
    );
    _scale3 = Tween(begin: 0.98, end: 1.06).animate(
      CurvedAnimation(
          parent: _pulseCtl,
          curve: const Interval(0.4, 0.9, curve: Curves.easeInOut)),
    );

    _opacity1 = Tween(begin: 0.08, end: 0.16).animate(
      CurvedAnimation(
          parent: _pulseCtl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeInOut)),
    );
    _opacity2 = Tween(begin: 0.06, end: 0.14).animate(
      CurvedAnimation(
          parent: _pulseCtl,
          curve: const Interval(0.2, 0.7, curve: Curves.easeInOut)),
    );
    _opacity3 = Tween(begin: 0.04, end: 0.12).animate(
      CurvedAnimation(
          parent: _pulseCtl,
          curve: const Interval(0.4, 0.9, curve: Curves.easeInOut)),
    );

    // Unified fade-in for primary panels
    _fadeCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeCtl, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didShowInitMessage) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(args), backgroundColor: Colors.green),
        );
      });
    }
    _didShowInitMessage = true;
  }

  // Top-right language and theme controls
  Widget _buildTopControls() {
    return Consumer2<LocaleController, ThemeController>(
      builder: (context, localeCtl, themeCtl, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _languagePill(localeCtl),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: _isThemePanelOpen ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: AnimatedScale(
                scale: _isThemePanelOpen ? 0.9 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: _isThemePanelOpen,
                  child: _themeButton(themeCtl),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Returns the gradient colors for the background.
  // V0 behavior: if the active seed is corporate red, use exact #B71C1C→#E53935.
  // Otherwise: primary → primary@0.8 opacity (like hsl(var(--primary)) → hsl(var(--primary)/0.8)).
  List<Color> _gradientColors(BuildContext context) {
    // Follow V0
    final themeCtl = Provider.of<ThemeController>(context, listen: false);
    final primary = Theme.of(context).colorScheme.primary;
    if (themeCtl.seedColor.value == const Color(0xFFB71C1C).value) {
      return const [Color(0xFFB71C1C), Color(0xFFE53935)];
    }
    return [primary, primary.withOpacity(0.8)];
  }

  Widget _languagePill(LocaleController localeCtl) {
    return InkWell(
      key: const ValueKey('language-pill'),
      borderRadius: BorderRadius.circular(999),
      onTap: localeCtl.toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              localeCtl.shortLabel,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeButton(ThemeController themeCtl) {
    return Tooltip(
      message: 'Thème',
      child: InkWell(
        key: const ValueKey('theme-button'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openThemeDialog(themeCtl),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Icon(Icons.color_lens_outlined,
              color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Future<void> _openThemeDialog(ThemeController themeCtl) async {
    if (mounted) setState(() => _isThemePanelOpen = true);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Tap outside to close
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                top: 60,
                right: 12,
                child: _buildThemePopover(themeCtl),
              ),
            ],
          ),
        );
      },
    );
    if (mounted) setState(() => _isThemePanelOpen = false);
  }

  Widget _buildThemePopover(ThemeController themeCtl) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in ThemeController.palette)
                _colorChoice(
                  c,
                  c.value == themeCtl.seedColor.value,
                  () {
                    themeCtl.setSeed(c);
                    Navigator.of(context).maybePop();
                  },
                  size: 44,
                  square: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.brightness_6_outlined, color: Colors.black87),
              const Spacer(),
              Switch(
                value: themeCtl.themeMode == ThemeMode.dark,
                onChanged: (val) {
                  themeCtl.toggleDark(val);
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colorChoice(
    Color color,
    bool selected,
    VoidCallback onTap, {
    double size = 28,
    bool square = false,
  }) {
    final borderRadius = BorderRadius.circular(square ? 12 : size);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: square ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: square ? borderRadius : null,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
          ),
          if (selected)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                shape: square ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: square ? borderRadius : null,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pulseCtl.dispose();
    _fadeCtl.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startAuthProgress() {
    _progressTimer?.cancel();
    _authProgress = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 140), (t) {
      if (!mounted) return;
      setState(() {
        // Ease towards 0.92 while waiting
        final next = _authProgress + (0.92 - _authProgress) * 0.14;
        _authProgress = next.clamp(0.0, 0.92);
      });
    });
  }

  void _stopAuthProgress({bool success = false}) {
    _progressTimer?.cancel();
    _progressTimer = null;
    if (!mounted) return;
    setState(() {
      _authProgress = success ? 1.0 : _authProgress;
    });
  }

  // Synchronize progress updates from AuthService
  void _setAuthProgress(double value, String message) {
    if (!mounted) return;
    setState(() {
      _authProgress = math.max(_authProgress, value.clamp(0.0, 1.0));
      if (message.isNotEmpty) _progressMessage = message;
    });
  }

  Future<void> _login() async {
    if (_isLoading) return; // Prevent re-entrant calls
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isDeactivatedAccount = false;
      _showSuccess = false;
      _authProgress = 0.0;
      _progressMessage = 'Préparation de l\'authentification...';
    });
    _startAuthProgress();

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      // Attempt login; returns true if account needs activation.
      final needsActivation = await authService.login(
        _emailController.text,
        _passwordController.text,
        onProgress: _setAuthProgress,
      );

      if (needsActivation) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        _stopAuthProgress();
        // Navigate to activation screen with the provided credentials
        getIt<NavigationService>().navigateTo(
          '/activation',
          arguments: {
            'email': _emailController.text,
            'password': _passwordController.text,
          },
        );
        return;
      }

      // Successful login path: AuthService handles navigation to dashboards.
      _stopAuthProgress(success: true);
      if (mounted) {
        setState(() {
          _showSuccess = true;
        });
      }
      // Briefly show success state before the route transition completes
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      final emLow = e.message.toLowerCase();
      final isUnauthorized = (e.statusCode == 401) ||
          emLow.contains('unauthorized') ||
          emLow.contains('bad credentials') ||
          emLow.contains('invalid credentials');
      if (mounted) {
        setState(() {
          _errorMessage =
              (isUnauthorized && !e.needsActivation && !e.isDeactivated)
                  ? 'Email ou mot de passe incorrect.'
                  : e.message;
          _isDeactivatedAccount = e.isDeactivated;
          _isLoading = false;
        });
      }
      _stopAuthProgress();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isDeactivatedAccount = false;
          _isLoading = false;
        });
      }
      _stopAuthProgress();
    }
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: _inputDecoration(context, 'Email', Icons.email_outlined),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || !value.contains('@')) {
          return 'Please enter a valid email.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: _inputDecoration(context, 'Mot de passe', Icons.lock_outline)
          .copyWith(
        suffixIcon: IconButton(
          icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Theme.of(context).colorScheme.primary),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
      obscureText: !_isPasswordVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Le mot de passe est requis.';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton(ThemeData theme) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors(context),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _gradientColors(context).last.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          key: const ValueKey('login-btn'),
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Se connecter',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ForgotPasswordScreen()));
      },
      child: Text(
        'Mot de passe oublié ?',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isDeactivatedAccount = false;
      _showSuccess = false;
      _authProgress = 0.0;
      _progressMessage = 'Préparation de la connexion Google...';
    });
    _startAuthProgress();
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // v6 flow: provide server (Web) client ID so Android returns an ID token
      final signIn = GoogleSignIn(
        serverClientId: AppConfig.googleServerClientId,
        scopes: const ['openid', 'email', 'profile'],
      );
      debugPrint('--- LOGIN: Using v6 GoogleSignIn with scopes [openid,email,profile]');
      debugPrint('--- LOGIN: serverClientId=' + AppConfig.googleServerClientId);

      // Reset any stale session to avoid Credential Manager reauth loops ([16] Account reauth failed)
      try {
        await signIn.signOut();
        debugPrint('--- LOGIN: Performed signOut() before authenticate.');
      } catch (e) {
        debugPrint('--- LOGIN: signOut() ignored error: $e');
      }
      // Also revoke any cached consent so we get the account chooser instead of silent restore
      try {
        await signIn.disconnect();
        debugPrint(
            '--- LOGIN: Performed disconnect() to revoke cached consent.');
      } catch (e) {
        debugPrint('--- LOGIN: disconnect() ignored error: $e');
      }

      // Start the classic sign-in flow (v6 API)
      debugPrint('--- LOGIN: Starting signIn() flow (v6).');
      final GoogleSignInAccount? account = await signIn.signIn();
      if (account == null) {
        debugPrint('--- LOGIN: User canceled Google Sign-In.');
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: cs.primary,
              content: Text(
                'Connexion Google annulée.',
                style: GoogleFonts.poppins(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        _stopAuthProgress();
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('--- LOGIN: Received empty/null idToken from Google.');
        if (mounted) {
          setState(() {
            _errorMessage =
                'Failed to retrieve Google ID token. Please try again.';
          });
        }
        _stopAuthProgress();
        return;
      }

      debugPrint(
          '--- LOGIN: Google ID token acquired (len=${idToken.length}).');
      await authService.loginWithGoogle(idToken, onProgress: _setAuthProgress);
      _stopAuthProgress(success: true);
      if (mounted) {
        setState(() {
          _showSuccess = true;
        });
      }
      await Future.delayed(const Duration(milliseconds: 600));
    } on PlatformException catch (e) {
      // Handle native Google Sign-In specific errors (e.g., DEVELOPER_ERROR 10)
      debugPrint('--- LOGIN: PlatformException during Google sign-in: code=${e.code}, message=${e.message}');
      final msg = (e.message ?? '').toLowerCase();
      final isDeveloperError10 = msg.contains('10:') || msg.contains('developer_error');
      if (mounted) {
        setState(() {
          _errorMessage = isDeveloperError10
              ? 'Configuration Google Android invalide (code 10). Vérifiez le client OAuth Android dans Google Cloud: package com.example.frontend et SHA-1 debug.'
              : 'Échec de la connexion Google. Veuillez réessayer.';
        });
      }
      _stopAuthProgress();
    } on ApiException catch (e) {
      if (e.needsActivation) {
        // Navigate to activation with the best email we can provide
        getIt<NavigationService>().navigateTo('/activation', arguments: {
          'email':
              _emailController.text.isNotEmpty ? _emailController.text : '',
        });
      } else if (e.isDeactivated) {
        if (mounted) {
          setState(() {
            _isDeactivatedAccount = true;
            _errorMessage = e.message;
          });
        }
      } else {
        final emLow = e.message.toLowerCase();
        final isUnauthorized = (e.statusCode == 401) ||
            emLow.contains('unauthorized') ||
            emLow.contains('bad credentials') ||
            emLow.contains('invalid credentials');
        if (mounted) {
          setState(() {
            _errorMessage = isUnauthorized
                ? 'Échec de la connexion Google. Veuillez réessayer.'
                : e.message;
          });
        }
      }
      _stopAuthProgress();
    } catch (e) {
      // Catch-all to surface unexpected errors to the user instead of failing silently
      debugPrint('--- LOGIN: Unexpected error during Google sign-in: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Erreur inattendue lors de la connexion Google. Veuillez réessayer.';
        });
      }
      _stopAuthProgress();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      key: const ValueKey('google-btn'),
      onPressed: _isLoading ? null : _loginWithGoogle,
      icon: Image.asset(
        'assets/google-icon.png',
        width: 20,
        height: 20,
      ),
      label: const Text('Continuer avec Google'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: _gradientColors(context).last),
        foregroundColor: Theme.of(context).colorScheme.primary,
        overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
      ),
    );
  }

  // Theme-colored loading overlay with progress and success states
  Widget _buildLoadingOverlay() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final primary = cs.primary;
    final isDark = theme.brightness == Brightness.dark;
    // Use themed surface for the card; keep slight translucency for depth
    final cardColor = cs.surface.withOpacity(isDark ? 0.96 : 0.98);
    // Barrier adapts to theme (stronger dim in dark mode)
    final barrierColor = isDark ? Colors.black54 : Colors.black38;
    return Stack(
      children: [
        ModalBarrier(dismissible: false, color: barrierColor),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _showSuccess
                    ? Icon(Icons.check_circle_rounded, color: primary, size: 32)
                    : SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(primary),
                        ),
                      ),
                const SizedBox(height: 12),
                Text(
                  (_showSuccess
                          ? 'Connexion réussie!'
                          : 'Connexion en cours...')
                      .toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _showSuccess ? 'Redirection en cours...' : _progressMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!_showSuccess) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: _authProgress.clamp(0.0, 1.0),
                      backgroundColor:
                          cs.surfaceVariant.withOpacity(isDark ? 0.35 : 0.6),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_authProgress * 100).clamp(0, 100).floor()}%',
                    style: GoogleFonts.poppins(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
      BuildContext context, String label, IconData icon) {
    final primary = Theme.of(context).colorScheme.primary;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primary, width: 1.6),
      ),
    );
  }

  // Login card extracted to reuse in wide and narrow layouts
  Widget _buildLoginCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 20,
              spreadRadius: 5)
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // OHSE logo
            Image.asset(
              'assets/logo_ohse_capital.png',
              height: 72,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'Connexion',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Accédez à votre espace de travail',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            if (_isDeactivatedAccount)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE), // light red
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF5350)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block, color: Color(0xFFD32F2F)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage ??
                              'Votre compte a été désactivé. Veuillez contacter votre administrateur.',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFD32F2F),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            Align(
              alignment: Alignment.centerRight,
              child: _buildForgotPasswordButton(),
            ),
            const SizedBox(height: 8),
            _buildLoginButton(theme),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Divider(color: Colors.grey.shade400)),
                const SizedBox(width: 8),
                Text('Ou continuer avec',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 12),
            _buildGoogleButton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 10, offset: Offset(0, 6)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBrandPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              'assets/logo_ohse_capital.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'OSHAPP',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bien-être corporatif professionnel',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Corporate Red Theme',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Plateforme intégrée de gestion de la santé et sécurité au travail\npour les entreprises modernes',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 28,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: [
              _feature(Icons.security, 'Sécurité'),
              _feature(Icons.lightbulb_outline, 'Innovation'),
              _feature(Icons.star_border_rounded, 'Excellence'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
                // Colors will be taken dynamically below using theme to reflect theme palette
                // Note: BoxDecoration is const, but we provide a child Positioned with dynamic gradient overlay.
                // The actual gradient is layered below using a Positioned.fill.
                ),
          ),
          // Dynamic gradient overlay reflecting current theme seed
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradientColors(context),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // Large soft decorative circles (V0 style) — responsive placement
          Positioned.fill(
            child: IgnorePointer(child: _buildBigCircles()),
          ),
          // Decorative bubbles
          Positioned(
            top: 60,
            right: 40,
            child: ScaleTransition(
              scale: _scale1,
              child: FadeTransition(
                opacity: _opacity1,
                child: _bubble(
                  90,
                  opacity: 0.18,
                  tintColors: _gradientColors(context),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 80,
            child: ScaleTransition(
              scale: _scale2,
              child: FadeTransition(
                opacity: _opacity2,
                child: _bubble(
                  70,
                  opacity: 0.14,
                  tintColors: _gradientColors(context),
                ),
              ),
            ),
          ),
          // Additional right-side bubbles to mirror V0's composition (no left-side bubbles)
          Positioned(
            top: 24,
            right: 20,
            child: ScaleTransition(
              scale: _scale3,
              child: FadeTransition(
                opacity: _opacity3,
                child: _bubble(
                  112, // ~w-28
                  opacity: 0.06,
                  tintColors: _gradientColors(context),
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 12,
            child: ScaleTransition(
              scale: _scale1,
              child: FadeTransition(
                opacity: _opacity1,
                child: _bubble(
                  80, // ~w-20
                  opacity: 0.10,
                  tintColors: _gradientColors(context),
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: 28,
            child: ScaleTransition(
              scale: _scale2,
              child: FadeTransition(
                opacity: _opacity2,
                child: _bubble(
                  64, // ~w-16
                  opacity: 0.08,
                  tintColors: _gradientColors(context),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 60,
            child: ScaleTransition(
              scale: _scale1,
              child: FadeTransition(
                opacity: _opacity1,
                child: _bubble(
                  88, // ~w-22
                  opacity: 0.28,
                  tintColors: _gradientColors(context),
                ),
              ),
            ),
          ),
          Positioned(
            top: 300,
            right: 180,
            child: ScaleTransition(
              scale: _scale2,
              child: FadeTransition(
                opacity: _opacity2,
                child: _bubble(
                  60, // ~w-15
                  opacity: 0.18,
                  tintColors: _gradientColors(context),
                ),
              ),
            ),
          ),
          // Subtle floating particles on the right side
          Positioned.fill(
            child: IgnorePointer(child: _buildParticles()),
          ),
          // Content
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: SingleChildScrollView(
                          child: FadeTransition(
                            key: const ValueKey('login-card'),
                            opacity: _fadeIn,
                            child: _buildLoginCard(theme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: FadeTransition(
                          key: const ValueKey('brand-panel'),
                          opacity: _fadeIn,
                          child: _buildBrandPanel(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        key: const ValueKey('login-card'),
                        opacity: _fadeIn,
                        child: _buildLoginCard(theme),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        key: const ValueKey('brand-panel'),
                        opacity: _fadeIn,
                        child: _buildBrandPanel(),
                      ),
                    ],
                  ),
                ),
              );
            }
          }),
          // Top-right controls: language + theme (placed last to stay on top)
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(child: _buildTopControls()),
          ),
          if (_isLoading)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: _buildLoadingOverlay(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubble(
    double size, {
    double opacity = 0.12,
    List<Color>? tintColors,
    bool radial = false,
    bool shadow = true,
  }) {
    final gradientColors =
        tintColors?.map((c) => c.withOpacity(opacity)).toList();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: radial
            ? RadialGradient(
                colors: [
                  Colors.white.withOpacity(opacity),
                  Colors.white.withOpacity(0),
                ],
                stops: const [0.0, 1.0],
                center: Alignment.center,
                radius: 0.85,
              )
            : (gradientColors != null
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null),
        color: (!radial && gradientColors == null)
            ? Colors.white.withOpacity(opacity)
            : null,
        shape: BoxShape.circle,
        boxShadow: shadow
            ? const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 8)),
              ]
            : null,
      ),
    );
  }

  // Builds 4 tiny ping-like particles positioned on the right side using percentages
  Widget _buildParticles() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        List<Widget> dots = [];
        for (int i = 0; i < 4; i++) {
          final rightPct = 0.20 + i * 0.15; // 20% + i*15%
          final topPct = 0.15 + i * 0.12; // 15% + i*12%
          dots.add(
            Positioned(
              right: w * rightPct,
              top: h * topPct,
              child: FadeTransition(
                opacity: _opacity1,
                child: _bubble(
                  8,
                  opacity: 0.15,
                  tintColors: _gradientColors(context),
                ),
              ),
            ),
          );
        }
        return Stack(children: dots);
      },
    );
  }

  // Large background circles inspired by V0 — responsive and animated
  Widget _buildBigCircles() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // Sizes adapt to screen; clamp to keep nice proportions
        final bigSize = (w * 0.28).clamp(200.0, 360.0).toDouble();
        final smallSize = (w * 0.22).clamp(150.0, 280.0).toDouble();
        // Subtle drift amplitudes (in px), scaled to screen size
        final ampX1 = (w * 0.006).clamp(3.0, 14.0).toDouble();
        final ampY1 = (h * 0.006).clamp(3.0, 14.0).toDouble();
        final ampX2 = (w * 0.008).clamp(4.0, 16.0).toDouble();
        final ampY2 = (h * 0.008).clamp(4.0, 16.0).toDouble();

        return Stack(
          children: [
            // Top-right large circle
            Positioned(
              top: h * 0.06,
              right: w * 0.05,
              child: AnimatedBuilder(
                animation: _pulseCtl,
                builder: (context, child) {
                  final v = _pulseCtl.value * 2 * math.pi; // 0..2π
                  final dx = math.sin(v) * ampX1;
                  final dy = math.cos(v) * ampY1;
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: child,
                  );
                },
                child: ScaleTransition(
                  scale: _scale1,
                  child: _bubble(
                    bigSize,
                    opacity: 0.24,
                    radial: true,
                    shadow: false,
                  ),
                ),
              ),
            ),
            // Bottom-right medium circle
            Positioned(
              bottom: h * 0.12,
              right: w * 0.18,
              child: AnimatedBuilder(
                animation: _pulseCtl,
                builder: (context, child) {
                  final v =
                      (_pulseCtl.value + 0.33) * 2 * math.pi; // phase offset
                  final dx = math.sin(v) * ampX2;
                  final dy = math.cos(v) * ampY2;
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: child,
                  );
                },
                child: ScaleTransition(
                  scale: _scale2,
                  child: _bubble(
                    smallSize,
                    opacity: 0.20,
                    radial: true,
                    shadow: false,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
