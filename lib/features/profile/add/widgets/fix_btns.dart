import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/profile/add/widgets/widgets.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_import.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_strings.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The file types a profile can be imported from.
const profileFileExtensions = ['txt', 'json', 'yaml', 'yml', 'conf', 'ovpn', 'zip'];

/// Opens the file picker for a profile file.
///
/// On Android and iOS file_picker turns each extension into a system file type (a MIME type,
/// a UTI) and drops the ones the system has none for, such as conf and ovpn, which grays out
/// WireGuard and OpenVPN files. There the picker shows all files; the import reads the
/// content, not the name.
Future<FilePickerResult?> pickProfileFile({TargetPlatform? platform}) {
  final filterByExtension = switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => false,
    _ => true,
  };
  return FilePicker.platform.pickFiles(
    type: filterByExtension ? FileType.custom : FileType.any,
    allowedExtensions: filterByExtension ? profileFileExtensions : null,
  );
}

class FixBtns extends ConsumerWidget {
  const FixBtns({super.key, required this.height, this.canScan = true});
  final double height;

  /// Raman VPN 1.8.1: the «کانفیگ DNS» button, on a row of its own under the others (five do not
  /// fit in one row on a phone). Android only, where the DNS tunnel runs.
  static bool get hasDnsRow => Platform.isAndroid;
  static const dnsRowHeight = 56.0;

  /// False on a device with no camera to scan a QR code with, such as a TV.
  final bool canScan;

  /// The usual import of [text], with its soar:// / cottendns:// links taken to the DNS tab first.
  static Future<void> _import(BuildContext context, WidgetRef ref, String text) async {
    final routed = await routeDnsLinks(context, ref, text);
    final rest = routed.rest;
    if (rest == null || !context.mounted) return;
    // the sheet shows its loading view (and drops these buttons) while the import runs
    final notifier = ref.read(addProfileNotifierProvider.notifier);
    final dnsAdded = routed.dnsAdded;
    final toast = dnsAdded == null ? null : dnsAddedToaster(ref);
    await notifier.addClipboard(rest);
    if (toast != null) toast(dnsAdded!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final isDesktop = PlatformUtils.isDesktop;
    // the buttons grow together when one needs more than its square
    final buttons = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(AddProfileModalConst.fixBtnsGap),
          FixBtn(
            key: const ValueKey('add_from_clipboard_button'),
            height: height,
            title: t.common.clipboard,
            icon: Icons.content_paste,
            onTap: () async {
              final cr = await Clipboard.getData(Clipboard.kTextPlain).then((value) => value?.text ?? '');
              if (context.mounted) await _import(context, ref, cr);
            },
          ),
          const Gap(AddProfileModalConst.fixBtnsGap),
          FixBtn(
            key: const ValueKey('add_from_file_button'),
            height: height,
            title: t.common.file,
            icon: Icons.insert_drive_file,
            onTap: () async {
              final result = await pickProfileFile();
              if (result == null) return;
              final picked = result.files.single;
              var bytes = picked.bytes;
              if (bytes == null) {
                final path = picked.path;
                if (path == null) return;
                final file = File(path);
                if (!await file.exists()) return;
                bytes = await file.readAsBytes();
              }
              final notifier = ref.read(addProfileNotifierProvider.notifier);
              if (picked.extension?.toLowerCase() == 'zip') {
                notifier.addArchive(bytes, name: picked.name.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), ''));
              } else if (context.mounted) {
                await _import(context, ref, decodeTextBytes(bytes));
              }
            },
          ),
          if (!isDesktop && canScan) ...[
            const Gap(AddProfileModalConst.fixBtnsGap),
            FixBtn(
              key: const ValueKey('add_by_qr_code_button'),
              height: height,
              title: t.common.qrCode,
              icon: Icons.qr_code_scanner,
              onTap: () async {
                final cr = await ref.read(dialogNotifierProvider.notifier).showQrScanner();
                if (cr == null || !context.mounted) return;
                await _import(context, ref, cr);
              },
            ),
          ],
          const Gap(AddProfileModalConst.fixBtnsGap),
          FixBtn(
            key: const ValueKey('add_manually_button'),
            height: height,
            title: t.common.manually,
            icon: Icons.add,
            onTap: () {
              ref.read(addProfilePageNotifierProvider.notifier).goManual();
            },
          ),
          const Gap(AddProfileModalConst.fixBtnsGap),
        ],
      ),
    );
    if (!hasDnsRow) return buttons;
    final dns = ref.watch(dnsTunnelStringsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buttons,
        const Gap(AddProfileModalConst.fixBtnsGap),
        Row(
          children: [
            const Gap(AddProfileModalConst.fixBtnsGap),
            FixBtn(
              key: const ValueKey('add_dns_config_button'),
              height: dnsRowHeight,
              title: dns.sheetButton,
              icon: Icons.cell_tower_rounded,
              horizontal: true,
              onTap: () => showAddDnsDialog(context, ref),
            ),
            const Gap(AddProfileModalConst.fixBtnsGap),
          ],
        ),
      ],
    );
  }
}
