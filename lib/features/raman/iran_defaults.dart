import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef RamanReader = T Function<T>(ProviderListenable<T> provider);

const _kApplied = 'raman-iran-defaults-v1';

/// The settings Raman VPN suggests for Iran's filtered internet: domestic sites go direct (region
/// Iran), TLS fragment on, IPv4 only so connecting does not wait on IPv6, and Persian.
Future<void> applyIranDefaults(RamanReader read, {bool locale = true}) async {
  await read(ConfigOptions.region.notifier).update(Region.ir);
  await read(ConfigOptions.enableTlsFragment.notifier).update(true);
  await read(ConfigOptions.ipv6Mode.notifier).update(IPv6Mode.ipv4Only);
  if (locale) await read(localePreferencesProvider.notifier).changeLocale(AppLocale.fa);
}

/// Applies [applyIranDefaults] once, on the first start, and never again, so the user's own
/// changes stay.
Future<void> applyIranDefaultsOnce(RamanReader read) async {
  final prefs = read(sharedPreferencesProvider).requireValue;
  if (prefs.getBool(_kApplied) ?? false) return;
  // a language the user already picked stays
  await applyIranDefaults(read, locale: prefs.getString('locale') == null);
  await prefs.setBool(_kApplied, true);
}
