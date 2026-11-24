import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hiddify/features/raman/netwatch/net_watch_strings.dart';
import 'package:hiddify/features/raman/netwatch/network_memory.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Raman VPN 1.9: the per-network memory switch on the Raman tools Iran tab (Android only).
class NetworkMemoryTile extends ConsumerWidget {
  const NetworkMemoryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    final s = ref.watch(netWatchStringsProvider);
    final memory = ref.read(networkMemoryProvider);
    final on = ref.watch(NetMemPrefs.enabled);
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([memory.current, memory.version]),
      builder: (context, _) {
        final net = memory.current.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.wifi_find_rounded),
              title: Text(s.memoryTitle),
              subtitle: Text(s.memorySubtitle),
              isThreeLine: true,
              value: on,
              onChanged: (v) => ref.read(NetMemPrefs.enabled.notifier).update(v),
            ),
            if (on)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 72, end: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          if (net != null) s.memoryNow(s.networkLabel(net.kind, net.label)),
                          s.memoryCount(memory.count),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (memory.count > 0) TextButton(onPressed: memory.clear, child: Text(s.memoryClear)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
