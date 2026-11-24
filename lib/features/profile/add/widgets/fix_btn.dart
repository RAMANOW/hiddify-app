import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FixBtn extends ConsumerWidget {
  const FixBtn({super.key, required this.height, required this.title, required this.icon, required this.onTap});

  final double height;
  final String title;
  final IconData icon;
  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = Breakpoint(context).isMobile();
    final color = theme.colorScheme.primary;
    final borderRadius = BorderRadius.circular(16);

    // Raman VPN 1.9: a soft tinted tile with the icon in a round badge, no outline
    final bg = Color.alphaBlend(color.withValues(alpha: .06), theme.colorScheme.surfaceContainerLow);
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            alignment: Alignment.center,
            // a minimum: a language whose letters are taller (Chinese, Burmese) needs more than the square
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isMobile ? 36 : 48,
                  height: isMobile ? 36 : 48,
                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(icon, size: isMobile ? 20 : 26, color: theme.colorScheme.onPrimaryContainer),
                ),
                Gap(isMobile ? 4 : 8),
                Text(
                  title,
                  style: isMobile
                      ? theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onSurface)
                      : theme.textTheme.titleSmall!.copyWith(color: theme.colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
