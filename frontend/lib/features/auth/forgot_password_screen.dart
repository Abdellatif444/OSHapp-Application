import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'package:oshapp/features/auth/reset_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oshapp/shared/config/theme_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  // Language toggle (FR by default) and localized strings mimicking V0 copy
  String _language = 'fr';
  static const Map<String, Map<String, String>> _texts = {
    'fr': {
      'title': 'Réinitialiser Votre Mot de Passe',
      'subtitle':
          "Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe",
      'email': 'Adresse Email',
      'emailPlaceholder': 'utilisateur@entreprise.com',
      'sendLink': 'Envoyer le Lien',
      'backToLogin': 'Retour à la Connexion',
      'successTitle': 'Vérifiez Votre Email',
      'successMessage':
          "Nous avons envoyé un lien de réinitialisation à votre adresse email. Veuillez vérifier votre boîte de réception et suivre les instructions.",
      'resendLink': 'Renvoyer le Lien',
      'sending': 'Envoi...',
      'loading': 'Envoi du lien...',
      'warning': 'Veuillez entrer votre email.',
      'haveCode': "J'ai déjà un code",
      'appBarTitle': 'Mot de passe oublié',
      'errorTooManyAttempts': 'Trop de tentatives. Veuillez réessayer plus tard.',
      'errorGeneric': 'Une erreur est survenue. Veuillez réessayer.',
      'errorEmailNotFound':
          'Si un compte existe pour cet email, un lien a été envoyé. Veuillez vérifier votre boîte de réception.',
    },
    'en': {
      'title': 'Reset Your Password',
      'subtitle':
          "Enter your email address and we'll send you a link to reset your password",
      'email': 'Email Address',
      'emailPlaceholder': 'user@company.com',
      'sendResetLink': 'Send Reset Link',
      'sendLink': 'Send Reset Link',
      'backToLogin': 'Back to Login',
      'successTitle': 'Check Your Email',
      'successMessage':
          "We have sent a password reset link to your email address. Please check your inbox and follow the instructions.",
      'resendLink': 'Resend Link',
      'sending': 'Sending...',
      'loading': 'Sending reset link...',
      'warning': 'Please enter your email.',
      'haveCode': 'I already have a code',
      'appBarTitle': 'Forgot Password',
      'errorTooManyAttempts': 'Too many attempts. Please try again later.',
      'errorGeneric': 'Something went wrong. Please try again.',
      'errorEmailNotFound':
          'If an account exists for this email, a link has been sent. Please check your inbox.',
    },
  };
  Map<String, String> get t => _texts[_language]!;

  // Returns the gradient colors for the background similar to Login page.
  // If the active seed is corporate red, use exact #B71C1C→#E53935, otherwise
  // derive from theme primary color.
  List<Color> _gradientColors(BuildContext context) {
    final themeCtl = Provider.of<ThemeController>(context, listen: false);
    final primary = Theme.of(context).colorScheme.primary;
    if (themeCtl.seedColor.value == const Color(0xFFB71C1C).value) {
      return const [Color(0xFFB71C1C), Color(0xFFE53935)];
    }
    return [primary, primary.withValues(alpha: 0.8)];
  }

  Widget _buildLoadingOverlay() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = cs.surface.withValues(alpha: isDark ? 0.96 : 0.98);
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
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t['loading']!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Resend cooldown state
  int _timer = 0; // seconds remaining
  Timer? _countdown;
  String? _warning;

  @override
  void dispose() {
    _emailController.dispose();
    _countdown?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _restoreTimer();
  }

  Future<void> _restoreTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs.getKeys().where((k) => k.startsWith('reset-timer-')).toList();
    if (keys.isEmpty) return;
    final key = keys.first;
    final last = prefs.getInt(key);
    if (last == null) return;
    final email = key.replaceFirst('reset-timer-', '');
    final diff = 60 - ((DateTime.now().millisecondsSinceEpoch - last) ~/ 1000);
    if (diff > 0) {
      if (mounted) {
        setState(() {
          _emailController.text = email;
          _emailSent = true;
          _timer = diff;
        });
      }
      _startCountdown(email);
    } else {
      await prefs.remove(key);
    }
  }

  Future<void> _storeTimerStart(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'reset-timer-$email', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _clearStoredTimer(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('reset-timer-$email');
  }

  void _startCountdown(String email) {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      setState(() {
        if (_timer > 0) _timer -= 1;
      });
      if (_timer <= 0) {
        timer.cancel();
        await _clearStoredTimer(email);
      }
    });
  }

  Future<void> _resend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _warning = t['warning']);
      return;
    }
    setState(() {
      _warning = null;
      _isLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _emailSent = true;
        _timer = 60;
      });
      await _storeTimerStart(email);
      _startCountdown(email);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            _errorMessage = _mapForgotError(e);
          } else {
            _errorMessage = t['errorGeneric'];
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapForgotError(ApiException e) {
    final code = e.statusCode ?? 0;
    final msg = e.message.toLowerCase();
    if (code == 429 || msg.contains('too many') || msg.contains('rate')) {
      return t['errorTooManyAttempts']!;
    }
    if (code == 400 || code == 404 || msg.contains('not found') || msg.contains('unknown')) {
      return t['errorEmailNotFound']!;
    }
    return t['errorGeneric']!;
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final email = _emailController.text.trim();
      await apiService.forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _emailSent = true;
        _warning = null;
        _timer = 60;
      });
      await _storeTimerStart(email);
      _startCountdown(email);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            _errorMessage = _mapForgotError(e);
          } else {
            _errorMessage = t['errorGeneric'];
          }
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
    final themeCtl = Provider.of<ThemeController>(context);
    final isDark = themeCtl.themeMode == ThemeMode.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(t['appBarTitle']!),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
        ),
        actions: [
          _buildLanguageToggle(),
          IconButton(
            tooltip: isDark ? 'Mode clair' : 'Mode sombre',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeCtl.toggleDark(!isDark),
            color: Colors.white,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _gradientColors(context),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _emailSent ? _buildSuccessMessage() : _buildResetForm(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() {
    final isFr = _language == 'fr';
    return Container
      (
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: ToggleButtons(
        isSelected: [isFr, !isFr],
        onPressed: (index) {
          setState(() => _language = index == 0 ? 'fr' : 'en');
        },
        constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
        renderBorder: false,
        borderRadius: BorderRadius.circular(16),
        selectedColor: Colors.white,
        color: Colors.white70,
        fillColor: Colors.white.withValues(alpha: 0.20),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('FR', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('EN', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            _emailSent ? Icons.check_circle : Icons.mail_outline,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          t['title']!,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t['subtitle']!,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.90),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildEmailField(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorMessage(),
                ],
                const SizedBox(height: 24),
                _buildResetButton(),
                const SizedBox(height: 8),
                _buildHaveCodeLink(),
                const SizedBox(height: 16),
                _buildBackToLogin(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: t['email'],
        hintText: t['emailPlaceholder'],
        prefixIcon: Icon(Icons.email_outlined,
            color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor:
            Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.70),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez saisir votre email';
        }
        if (!value.contains('@')) {
          return 'Veuillez saisir un email valide';
        }
        return null;
      },
    );
  }

  Widget _buildErrorMessage() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.error.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    final disabled = _isLoading;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
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
                color: _gradientColors(context).last.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: disabled ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              t['sendLink']!,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackToLogin() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        t['backToLogin']!,
        style: GoogleFonts.poppins(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHaveCodeLink() {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      },
      child: Text(
        t['haveCode']!,
        style: GoogleFonts.poppins(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.check_circle,
              size: 50,
              color: Colors.green[600],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t['successTitle']!,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t['successMessage']!,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.80),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
              );
            },
            child: Text(
              t['haveCode']!,
              style: GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_warning != null) ...[
            const SizedBox(height: 12),
            Text(
              _warning!,
              style: const TextStyle(color: Colors.amber),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
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
                    color: _gradientColors(context).last.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  t['backToLogin']!,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: (_timer > 0 || _isLoading) ? null : _resend,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isLoading
                    ? t['sending']!
                    : _timer > 0
                        ? '${t['resendLink']} (${_timer}s)'
                        : t['resendLink']!,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
