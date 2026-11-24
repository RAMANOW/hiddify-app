import 'package:flutter/material.dart';

/// Raman VPN's own colours (from the Raman logo: a blue running from cyan to indigo) and the
/// state colours of the connect button. Our own palette; nothing taken from another VPN's brand.
abstract final class RamanBrand {
  /// The logo's middle blue: the seed of the light and dark colour schemes.
  static const blue = Color(0xFF2E78DD);

  /// The logo's two ends.
  static const cyan = Color(0xFF1C93D9);
  static const indigo = Color(0xFF3E5FE1);

  /// Connected (green), on its way (amber), stopped by an error (red).
  static const connected = Color(0xFF16A34A);
  static const connectedLight = Color(0xFF22C55E);
  static const connecting = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
  static const warning = Color(0xFFD97706);

  /// The Persian / Kurdish font bundled with the app (Vazirmatn, SIL Open Font License 1.1).
  static const persianFont = 'Vazirmatn';

  /// Spacing and corner steps used by Raman's own screens.
  static const radius = 20.0;
  static const radiusSmall = 14.0;
}
