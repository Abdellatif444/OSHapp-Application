import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/config/locale_controller.dart';
import 'package:oshapp/shared/config/theme_controller.dart';

/// V0-style language pill and theme popover (palette + dark-mode switch).
/// Matches the behavior and visuals used on the Login screen.
class ThemeControls extends StatefulWidget {
  const ThemeControls({super.key});

  @override
  State<ThemeControls> createState() => _ThemeControlsState();
}

class _ThemeControlsState extends State<ThemeControls> {
  bool _isThemePanelOpen = false;

  @override
  Widget build(BuildContext context) {
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
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
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
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Icon(Icons.color_lens_outlined, color: Theme.of(context).colorScheme.primary),
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
          BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8)),
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
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
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
}
