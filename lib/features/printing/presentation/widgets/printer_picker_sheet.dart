import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/printing/bluetooth_printer_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../application/printer_controller.dart';

/// Busca y conecta una impresora térmica Bluetooth.
Future<void> showPrinterPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _PrinterPickerSheet(),
  );
}

class _PrinterPickerSheet extends ConsumerStatefulWidget {
  const _PrinterPickerSheet();

  @override
  ConsumerState<_PrinterPickerSheet> createState() =>
      _PrinterPickerSheetState();
}

class _PrinterPickerSheetState extends ConsumerState<_PrinterPickerSheet> {
  @override
  void initState() {
    super.initState();

    Future<void>.microtask(
      () => ref.read(printerControllerProvider.notifier).loadDevices(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final state = ref.watch(printerControllerProvider);
    final controller = ref.read(printerControllerProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Elegir impresora',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Se listan las impresoras emparejadas en el teléfono y las que '
            'estén encendidas cerca.',
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (state.errorMessage != null) ...<Widget>[
            NoticeBanner(
              message: state.errorMessage!,
              actionLabel: 'Ocultar',
              onAction: controller.consumeError,
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (state.isBusy && state.devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                for (final device in state.devices)
                  _PrinterTile(
                    device: device,
                    isConnecting: state.isBusy,
                    onSelected: () => _connect(device),
                  ),
                if (state.devices.isEmpty && !state.isBusy)
                  const EmptyState(
                    title: 'Sin impresoras',
                    message:
                        'Empareja la impresora térmica desde los ajustes de '
                        'Bluetooth del teléfono y vuelve a buscar.',
                    icon: Icons.print_disabled_outlined,
                    compact: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EzyButton(
            label: 'Buscar de nuevo',
            icon: Icons.bluetooth_searching_outlined,
            variant: EzyButtonVariant.outline,
            isLoading: state.isBusy,
            onPressed: () => controller.loadDevices(),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(PrinterDevice device) async {
    final connected = await ref
        .read(printerControllerProvider.notifier)
        .connectTo(device);

    if (connected && mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Una impresora de la lista (emparejada, guardada o encontrada al escanear).
class _PrinterTile extends StatelessWidget {
  const _PrinterTile({
    required this.device,
    required this.isConnecting,
    required this.onSelected,
  });

  final PrinterDevice device;
  final bool isConnecting;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: isConnecting ? null : onSelected,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surfaces.panelInner,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaces.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.print_outlined, size: 18, color: surfaces.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    device.label,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      device.id,
                      if (device.isPaired) 'emparejada',
                      if (device.isSaved) 'guardada',
                      if (device.rssi != null) '${device.rssi} dBm',
                    ].join(' · '),
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

