import 'package:flutter/material.dart';

/// Raman VPN's brand colours, taken from the Raman logo (a blue running from cyan to indigo).
abstract final class RamanBrand {
  /// The logo's middle blue: the seed of the light and dark colour schemes.
  static const blue = Color(0xFF2E78DD);

  /// The logo's two ends.
  static const cyan = Color(0xFF1C93D9);
  static const indigo = Color(0xFF3E5FE1);

  /// Connected (green), on its way (the logo's indigo), stopped by an error (red), and a warning.
  static const connected = Color(0xFF16A34A);
  static const connecting = indigo;
  static const error = Color(0xFFDC2626);
  static const warning = Color(0xFFD97706);

  /// The logo's gradient, for the brand accents (the connect buttons, the tab pill).
  static const gradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [cyan, indigo],
  );

  /// The Persian font bundled with the app (Vazirmatn, SIL Open Font License 1.1).
  static const persianFont = 'Vazirmatn';
}
