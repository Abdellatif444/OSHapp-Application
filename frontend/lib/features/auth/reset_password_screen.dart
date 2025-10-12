import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:oshapp/shared/config/theme_controller.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _success = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _errorMessage;
  bool _canSubmit = false;

  // Bilingual text (FR default) similar to V0 copy
  String _language = 'fr';
  static const Map<String, Map<String, String>> _texts = {
    'fr': {
      'appBarTitle': 'Réinitialiser le mot de passe',
      'headerTitle': 'Saisir le code et le nouveau mot de passe',
      'headerSubtitle': 'Entrez le code reçu par email (valide 15 minutes) et créez un nouveau mot de passe.' ,
      'tokenLabel': 'Code de réinitialisation',
      'tokenHint': '6 chiffres',
      'newPassword': 'Nouveau mot de passe',
      'confirmPassword': 'Confirmer le mot de passe',
      'submit': 'Réinitialiser le mot de passe',
      'backToLogin': 'Retour à la connexion',
      'successTitle': 'Mot de passe réinitialisé !',
      'successMessage': 'Votre mot de passe a été mis à jour avec succès. Vous pouvez maintenant vous connecter avec vos nouvelles informations.',
      'login': 'Se connecter',
      'ruleMin': 'Au moins 8 caractères',
      'ruleUpper': 'Une majuscule (A-Z)',
      'ruleNumber': 'Un chiffre (0-9)',
      'ruleSpecial': 'Un caractère spécial (!,@,#,...)',
      'tokenRequired': 'Veuillez saisir le code',
      'tokenDigits': 'Le code doit contenir 6 chiffres',
      'passwordRequired': 'Veuillez saisir un mot de passe',
      'passwordMin8': 'Au moins 8 caractères',
      'passwordsMismatch': 'Les mots de passe ne correspondent pas',
      'errorInvalidCode': 'Code invalide. Veuillez vérifier le code à 6 chiffres.',
      'errorExpiredCode': 'Code expiré. Demandez un nouveau code et réessayez.',
      'errorTooManyAttempts': 'Trop de tentatives. Veuillez réessayer plus tard.',
      'errorGeneric': 'Une erreur est survenue. Veuillez réessayer.',
      'loading': 'Réinitialisation en cours...',
      'tooltipPaste': 'Coller',
      'tooltipShow': 'Afficher',
      'tooltipHide': 'Masquer',
    },
    'en': {
      'appBarTitle': 'Reset Password',
      'headerTitle': 'Enter the code and new password',
      'headerSubtitle': 'Enter the code received by email (valid for 15 minutes) and create a new password.',
      'tokenLabel': 'Reset code',
      'tokenHint': '6 digits',
      'newPassword': 'New password',
      'confirmPassword': 'Confirm password',
      'submit': 'Reset password',
      'backToLogin': 'Back to Login',
      'successTitle': 'Password reset!',
      'successMessage': 'Your password has been updated successfully. You can now log in with your new credentials.',
      'login': 'Log in',
      'ruleMin': 'At least 8 characters',
      'ruleUpper': 'One uppercase letter (A-Z)',
      'ruleNumber': 'One number (0-9)',
      'ruleSpecial': 'One special character (!,@,#,...)',
      'tokenRequired': 'Please enter the code',
      'tokenDigits': 'The code must be 6 digits',
      'passwordRequired': 'Please enter a password',
      'passwordMin8': 'At least 8 characters',
      'passwordsMismatch': 'Passwords do not match',
      'errorInvalidCode': 'Invalid code. Please check the 6-digit code.',
      'errorExpiredCode': 'Code expired. Please request a new code and try again.',
      'errorTooManyAttempts': 'Too many attempts. Please try again later.',
      'errorGeneric': 'Something went wrong. Please try again.',
      'loading': 'Resetting...',
      'tooltipPaste': 'Paste',
      'tooltipShow': 'Show',
      'tooltipHide': 'Hide',
    },
  };
  Map<String, String> get t => _texts[_language]!;

  // Theme-aware gradient, consistent with other auth screens
  List<Color> _gradientColors(BuildContext context) {
    final themeCtl = Provider.of<ThemeController>(context, listen: false);
    final primary = Theme.of(context).colorScheme.primary;
    if (themeCtl.seedColor.value == const Color(0xFFB71C1C).value) {
      return const [Color(0xFFB71C1C), Color(0xFFE53935)];
    }
    return [primary, primary.withValues(alpha: 0.8)];
  }

  Widget _buildLanguageToggle() {
    final isFr = _language == 'fr';
    return Container(
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

  // Live password rule checks
  bool _hasMin = false;
  bool _hasUpper = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_evaluateState);
    _tokenController.addListener(_evaluateState);
    _confirmController.addListener(_evaluateState);
  }

  void _evaluateState() {
    final p = _passwordController.text;
    final hasMin = p.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
    final hasNumber = RegExp(r'[0-9]').hasMatch(p);
    final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\;/+=`~]').hasMatch(p);
    final tokenOk = _tokenController.text.trim().length == 6;
    final confirmOk = _confirmController.text == p && _confirmController.text.isNotEmpty;
    setState(() {
      _hasMin = hasMin;
      _hasUpper = hasUpper;
      _hasNumber = hasNumber;
      _hasSpecial = hasSpecial;
      _canSubmit = tokenOk && hasMin && hasUpper && hasNumber && hasSpecial && confirmOk;
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.resetPassword(_tokenController.text.trim(), _passwordController.text);
      if (mounted) {
        setState(() {
          _success = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            _errorMessage = _mapResetError(e);
          } else {
            _errorMessage = e.toString();
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
                      _success ? _buildSuccess() : _buildForm(),
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
          child: const Icon(Icons.verified_user, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          t['headerTitle']!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t['headerSubtitle']!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withValues(alpha: 0.90)),
        ),
      ],
    );
  }

  Widget _buildForm() {
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
            child: AutofillGroup(
              child: Column(
              children: [
                _tokenField(),
                const SizedBox(height: 16),
                _passwordField(),
                const SizedBox(height: 16),
                _confirmField(),
                _passwordRules(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _errorBox(),
                ],
                const SizedBox(height: 24),
                _submitButton(),
                const SizedBox(height: 12),
                _backToLogin(),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _tokenField() {
    return TextFormField(
      controller: _tokenController,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onChanged: (v) {
        final val = v.trim();
        if (val.length == 6) {
          FocusScope.of(context).nextFocus();
        }
      },
      decoration: InputDecoration(
        labelText: t['tokenLabel'],
        hintText: t['tokenHint'],
        prefixIcon: Icon(Icons.pin, color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.70),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        suffixIcon: IconButton(
          tooltip: t['tooltipPaste'],
          icon: Icon(Icons.paste, color: Theme.of(context).colorScheme.primary),
          onPressed: _pasteCode,
        ),
      ),
      validator: (v) {
        final val = v?.trim() ?? '';
        if (val.isEmpty) return t['tokenRequired'];
        if (val.length != 6) return t['tokenDigits'];
        return null;
      },
    );
  }

  Future<void> _pasteCode() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (data?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (text.isEmpty) return;
      setState(() {
        _tokenController.text = (text.length >= 6) ? text.substring(0, 6) : text;
      });
      _evaluateState();
      if (_tokenController.text.trim().length == 6) {
        FocusScope.of(context).nextFocus();
      }
    } catch (_) {
      // no-op: best effort paste
    }
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      textInputAction: TextInputAction.next,
      obscureText: !_showPassword,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: t['newPassword'],
        prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.70),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        suffixIcon: IconButton(
          tooltip: _showPassword ? t['tooltipHide'] : t['tooltipShow'],
          icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, color: Theme.of(context).colorScheme.primary),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
      ),
      validator: (v) {
        final val = v ?? '';
        if (val.isEmpty) return t['passwordRequired'];
        if (val.length < 8) return t['passwordMin8'];
        if (!RegExp(r'[A-Z]').hasMatch(val)) return t['ruleUpper'];
        if (!RegExp(r'[0-9]').hasMatch(val)) return t['ruleNumber'];
        if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\;/+=`~]').hasMatch(val)) return t['ruleSpecial'];
        return null;
      },
    );
  }

  Widget _confirmField() {
    return TextFormField(
      controller: _confirmController,
      textInputAction: TextInputAction.done,
      obscureText: !_showConfirm,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: t['confirmPassword'],
        prefixIcon: Icon(Icons.lock_reset, color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.70),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        suffixIcon: IconButton(
          tooltip: _showConfirm ? t['tooltipHide'] : t['tooltipShow'],
          icon: Icon(_showConfirm ? Icons.visibility : Icons.visibility_off, color: Theme.of(context).colorScheme.primary),
          onPressed: () => setState(() => _showConfirm = !_showConfirm),
        ),
      ),
      onFieldSubmitted: (_) {
        if (_canSubmit && !_isLoading) {
          _submit();
        }
      },
      validator: (v) {
        if (v != _passwordController.text) return t['passwordsMismatch'];
        return null;
      },
    );
  }

  Widget _passwordRules() {
    Widget item(bool ok, String text) {
      return Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? Colors.green[600] : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: ok ? Colors.green[700] : const Color(0xFF666666),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(_hasMin, t['ruleMin']!),
          const SizedBox(height: 6),
          item(_hasUpper, t['ruleUpper']!),
          const SizedBox(height: 6),
          item(_hasNumber, t['ruleNumber']!),
          const SizedBox(height: 6),
          item(_hasSpecial, t['ruleSpecial']!),
        ],
      ),
    );
  }

  Widget _errorBox() {
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

  Widget _submitButton() {
    final disabled = _isLoading || !_canSubmit;
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
            onPressed: disabled ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    t['submit']!,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _backToLogin() {
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

  Widget _buildSuccess() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.90),
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
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      t['login']!,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _mapResetError(ApiException e) {
    final code = e.statusCode ?? 0;
    final msg = e.message.toLowerCase();
    // Map common backend responses to friendly, localized messages.
    if (code == 429 || msg.contains('too many') || msg.contains('rate')) {
      return t['errorTooManyAttempts']!;
    }
    if (code == 410 || msg.contains('expired') || msg.contains('expir')) {
      return t['errorExpiredCode']!;
    }
    if (code == 400 || code == 404 || msg.contains('invalid') || msg.contains('not valid') || msg.contains('not found')) {
      return t['errorInvalidCode']!;
    }
    return t['errorGeneric']!;
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
}
