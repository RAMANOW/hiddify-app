import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The launcher icons the app can show itself as. The names match the activity-aliases in
/// AndroidManifest.xml (Launcher<Name>).
enum DisguiseIcon {
  defaultIcon('Default', Icons.vpn_lock_rounded),
  calculator('Calculator', Icons.calculate_rounded),
  weather('Weather', Icons.wb_sunny_rounded),
  notes('Notes', Icons.sticky_note_2_rounded),
  clock('Clock', Icons.access_time_filled_rounded);

  const DisguiseIcon(this.alias, this.icon);

  final String alias;
  final IconData icon;

  String present(RamanStrings s) => switch (this) {
    defaultIcon => s.disguiseDefault,
    calculator => s.disguiseCalculator,
    weather => s.disguiseWeather,
    notes => s.disguiseNotes,
    clock => s.disguiseClock,
  };

  static DisguiseIcon fromAlias(String? alias) =>
      values.firstWhere((e) => e.alias == alias, orElse: () => defaultIcon);
}

abstract class DisguiseIconChannel {
  static const _channel = MethodChannel('com.ramanow.ramanvpn/launcher_icon');

  static bool get supported => Platform.isAndroid;

  static Future<DisguiseIcon> current() async {
    if (!supported) return DisguiseIcon.defaultIcon;
    try {
      return DisguiseIcon.fromAlias(await _channel.invokeMethod<String>('get'));
    } catch (_) {
      return DisguiseIcon.defaultIcon;
    }
  }

  static Future<bool> set(DisguiseIcon icon) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('set', {'icon': icon.alias}) ?? false;
    } catch (_) {
      return false;
    }
  }
}

final disguiseIconProvider = FutureProvider<DisguiseIcon>((ref) => DisguiseIconChannel.current());

/// Settings entry: shows the current launcher icon and lets the user pick another.
class DisguiseIconTile extends ConsumerWidget {
  const DisguiseIconTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DisguiseIconChannel.supported) return const SizedBox.shrink();
    final s = ref.watch(ramanStringsProvider);
    final current = ref.watch(disguiseIconProvider).valueOrNull ?? DisguiseIcon.defaultIcon;
    return ListTile(
      leading: const Icon(Icons.theater_comedy_rounded),
      title: Text(s.disguiseTitle),
      subtitle: Text('${s.disguiseSubtitle} — ${current.present(s)}'),
      onTap: () async {
        final picked = await showDialog<DisguiseIcon>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(s.disguiseTitle),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(s.disguiseHelp, style: Theme.of(context).textTheme.bodySmall),
              ),
              for (final icon in DisguiseIcon.values)
                ListTile(
                  leading: Icon(icon.icon),
                  title: Text(icon.present(s)),
                  trailing: icon == current ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.of(context).pop(icon),
                ),
            ],
          ),
        );
        if (picked == null || picked == current) return;
        final ok = await DisguiseIconChannel.set(picked);
        ref.invalidate(disguiseIconProvider);
        final notifications = ref.read(inAppNotificationControllerProvider);
        if (ok) {
          notifications.showSuccessToast(s.disguiseApplied);
        } else {
          notifications.showErrorToast(s.disguiseUnsupported);
        }
      },
    );
  }
}
