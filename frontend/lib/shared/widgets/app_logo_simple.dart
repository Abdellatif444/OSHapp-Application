import 'package:flutter/material.dart';

class AppLogoSimple extends StatelessWidget {
  final double size;

  const AppLogoSimple({super.key, this.size = 100.0});

  @override
  Widget build(BuildContext context) {
    return FlutterLogo(size: size);
  }
}
