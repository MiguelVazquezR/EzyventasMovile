import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/printing/bluetooth_printer_service.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_list_tile.dart';
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
          EzySheetHeader(
            title: 'Elegir impresora',
            subtitle:
                'Se listan las impresoras emparejadas en el teléfono y las '
                'que estén encendidas cerca.',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
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
                for (int index = 0; index < state.devices.length; index++)
                  _PrinterTile(
                    device: state.devices[index],
                    isConnecting: state.isBusy,
                    showDivider: index < state.devices.length - 1,
                    onSelected: () => _connect(state.devices[index]),
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
            // Azul Bluetooth: la acción es el escaneo.
            variant: EzyButtonVariant.info,
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
///
/// Fila del design system: el cuadro del icono, el nombre, los datos del
/// dispositivo y el chevron los pinta [EzyListTile]. Mientras hay una conexión
/// en curso la fila no navega y su chevron se cambia por el indicador.
class _PrinterTile extends StatelessWidget {
  const _PrinterTile({
    required this.device,
    required this.isConnecting,
    required this.showDivider,
    required this.onSelected,
  });

  final PrinterDevice device;
  final bool isConnecting;
  final bool showDivider;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return EzyListTile(
      icon: Icons.bluetooth,
      title: device.label,
      subtitle: <String>[
        device.id,
        if (device.isPaired) 'emparejada',
        if (device.isSaved) 'guardada',
        if (device.rssi != null) '${device.rssi} dBm',
      ].join(' · '),
      trailing: isConnecting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      showDivider: showDivider,
      onTap: isConnecting ? null : onSelected,
    );
  }
}

