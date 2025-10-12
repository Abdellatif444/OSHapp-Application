import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double height;
  final bool showText;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 40,
    this.height = 40,
    this.showText = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo OHSE CAPITAL réel
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.1),
            child: Image.asset(
              'assets/images/logo_ohse_capital.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback en cas d'erreur de chargement du logo
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color ?? const Color(0xFF8B4A6B),
                    borderRadius: BorderRadius.circular(size * 0.1),
                  ),
                  child: Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: size * 0.6,
                  ),
                );
              },
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OSHapp',
                style: TextStyle(
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.bold,
                  color: color ?? const Color(0xFF8B4A6B),
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Santé & Sécurité au Travail',
                style: TextStyle(
                  fontSize: size * 0.25,
                  color: const Color(0xFF757575),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

}

// Widget simplifié pour les petites tailles
class AppLogoSimple extends StatelessWidget {
  final double height;
  final Color? color;

  const AppLogoSimple({
    super.key,
    this.height = 80.0, // Default size increased
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Image.asset(
        'assets/images/logo_ohse_capital.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback icon
          return Icon(
            Icons.local_hospital_rounded,
            color: color ?? const Color(0xFF8B4A6B),
            size: height * 0.8,
          );
        },
      ),
    );
  }
}
