import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

typedef ProgressCallback = void Function(double, String);

/// Shows a themed progress dialog that runs [task] and updates UI via [onProgress].
/// Displays a success state briefly before dismissing.
Future<void> showThemedProgressDialog({
  required BuildContext context,
  required String title,
  required String successTitle,
  required String initialMessage,
  required Future<void> Function(ProgressCallback onProgress) task,
}) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final barrierColor = isDark ? Colors.black54 : Colors.black38;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: barrierColor,
    builder: (dialogContext) => _ThemedProgressDialog(
      title: title,
      successTitle: successTitle,
      initialMessage: initialMessage,
      task: task,
    ),
  );
}

class _ThemedProgressDialog extends StatefulWidget {
  final String title;
  final String successTitle;
  final String initialMessage;
  final Future<void> Function(ProgressCallback onProgress) task;

  const _ThemedProgressDialog({
    required this.title,
    required this.successTitle,
    required this.initialMessage,
    required this.task,
  });

  @override
  State<_ThemedProgressDialog> createState() => _ThemedProgressDialogState();
}

class _ThemedProgressDialogState extends State<_ThemedProgressDialog> {
  double _progress = 0.0;
  bool _showSuccess = false;
  String _message = '';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Kick off the task after first frame so dialog is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.task((value, message) {
          if (!mounted) return;
          setState(() {
            _progress = value.clamp(0.0, 1.0);
            if (message.isNotEmpty) _message = message;
          });
        });
        if (!mounted) return;
        setState(() {
          _progress = 1.0;
          _showSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 500));
      } finally {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final primary = cs.primary;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = cs.surface.withOpacity(isDark ? 0.96 : 0.98);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12)),
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
                      value: _progress > 0 && _progress < 1.0 ? _progress : null,
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
            const SizedBox(height: 12),
            Text(
              (_showSuccess ? widget.successTitle : widget.title).toUpperCase(),
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
              _showSuccess ? '' : _message,
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
                  value: _progress.clamp(0.0, 1.0),
                  backgroundColor: cs.surfaceVariant.withOpacity(isDark ? 0.35 : 0.6),
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).clamp(0, 100).floor()}%',
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
    );
  }
}
