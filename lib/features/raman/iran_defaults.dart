import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef RamanReader = T Function<T>(ProviderListenable<T> provider);

const _kApplied = 'raman-iran-defaults-v1';

/// Raman VPN's own settings, apart from the core's.
abstract final class RamanPrefs {
  /// Whether a connection that fails to start (the core not ready yet, the VPN interface still
  /// busy) is tried again, twice, before the error is shown.
  static final autoRetry = PreferencesNotifier.create<bool, bool>('raman-auto-retry', true);
}

/// How often the proxies of a profile are tested in the background, in "Iran mode": every 5
/// minutes, so a server whose address was blocked is left within minutes, not after 10.
const ramanUrlTestInterval = Duration(minutes: 5);

/// The settings Raman VPN suggests for Iran's filtered internet ("Iran mode"): domestic sites go
/// direct (region Iran), the fastest working proxy is used and left as soon as it fails (lowest
/// delay with failover, tested every 5 minutes), TLS fragment on, IPv4 only (IPv6 works inside
/// Iran but not to the outside, so waiting on it only slows connecting), a failed start is tried
/// again, and Persian.
Future<void> applyIranDefaults(RamanReader read, {bool locale = true}) async {
  await read(ConfigOptions.region.notifier).update(Region.ir);
  await read(ConfigOptions.enableTlsFragment.notifier).update(true);
  await read(ConfigOptions.ipv6Mode.notifier).update(IPv6Mode.ipv4Only);
  await read(ConfigOptions.defaultProxy.notifier).update(DefaultProxy.lowest);
  await read(ConfigOptions.urlTestInterval.notifier).update(ramanUrlTestInterval);
  await read(RamanPrefs.autoRetry.notifier).update(true);
  if (locale) await read(localePreferencesProvider.notifier).changeLocale(AppLocale.fa);
}

/// Whether the settings are those of [applyIranDefaults] (the language aside).
bool isIranMode(RamanReader read) =>
    read(ConfigOptions.region) == Region.ir &&
    read(ConfigOptions.ipv6Mode) == IPv6Mode.ipv4Only &&
    read(ConfigOptions.defaultProxy) == DefaultProxy.lowest &&
    read(ConfigOptions.urlTestInterval) <= ramanUrlTestInterval &&
    read(RamanPrefs.autoRetry);

/// Applies [applyIranDefaults] once, on the first start, and never again, so the user's own
/// changes stay.
Future<void> applyIranDefaultsOnce(RamanReader read) async {
  final prefs = read(sharedPreferencesProvider).requireValue;
  if (prefs.getBool(_kApplied) ?? false) return;
  // a language the user already picked stays
  await applyIranDefaults(read, locale: prefs.getString('locale') == null);
  await prefs.setBool(_kApplied, true);
}
