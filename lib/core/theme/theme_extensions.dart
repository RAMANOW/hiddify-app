import 'package:flutter/material.dart';

class ConnectionButtonTheme extends ThemeExtension<ConnectionButtonTheme> {
  const ConnectionButtonTheme({this.idleColor, this.connectedColor});

  final Color? idleColor;
  final Color? connectedColor;

  // Raman VPN: the logo's blue at rest and one green for connected, in the app's light and dark
  // themes (the dark one a touch lighter so it stands out on the dark background)
  static const ConnectionButtonTheme light = ConnectionButtonTheme(
    idleColor: Color(0xFF2E78DD),
    connectedColor: Color(0xFF16A34A),
  );

  static const ConnectionButtonTheme dark = ConnectionButtonTheme(
    idleColor: Color(0xFF4C8DF0),
    connectedColor: Color(0xFF22C55E),
  );

  @override
  ThemeExtension<ConnectionButtonTheme> copyWith({Color? idleColor, Color? connectedColor}) => ConnectionButtonTheme(
    idleColor: idleColor ?? this.idleColor,
    connectedColor: connectedColor ?? this.connectedColor,
  );

  @override
  ThemeExtension<ConnectionButtonTheme> lerp(covariant ThemeExtension<ConnectionButtonTheme>? other, double t) {
    if (other is! ConnectionButtonTheme) {
      return this;
    }
    return ConnectionButtonTheme(
      idleColor: Color.lerp(idleColor, other.idleColor, t),
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t),
    );
  }
}
