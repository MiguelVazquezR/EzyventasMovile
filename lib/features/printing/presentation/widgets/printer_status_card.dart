import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../application/printer_controller.dart';
import 'printer_picker_sheet.dart';

/// Estado de la impresora Bluetooth con sus acciones (conectar, cambiar, olvidar).
class PrinterStatusCard extends ConsumerWidget {
  const PrinterStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final state = ref.watch(printerControllerProvider);
    final controller = ref.read(printerControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              state.isConnected
                  ? Icons.print_outlined
                  : Icons.print_disabled_outlined,
              size: 20,
              color: StatusPalette.text(
                context,
                state.isConnected ? EzySeverity.success : EzySeverity.neutral,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.statusLabel,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ),
            if (state.isBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Los tickets se imprimen en la impresora térmica emparejada del '
          'teléfono.',
          style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
        ),
        if (!state.isAdapterOn) ...<Widget>[
          const SizedBox(height: 12),
          NoticeBanner(
            message: state.isSupported
                ? 'Enciende el Bluetooth del teléfono para imprimir.'
                : 'Este dispositivo no soporta Bluetooth de baja energía.',
            tone: EzySeverity.warn,
            actionLabel: state.isSupported ? 'Encender' : null,
            onAction: state.isSupported ? controller.turnOnAdapter : null,
          ),
        ],
        if (state.notice != null) ...<Widget>[
          const SizedBox(height: 12),
          NoticeBanner(
            message: state.notice!,
            tone: EzySeverity.info,
            icon: Icons.info_outline,
            actionLabel: 'Ocultar',
            onAction: controller.consumeNotice,
          ),
        ],
        if (state.errorMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          NoticeBanner(
            message: state.errorMessage!,
            actionLabel: 'Ocultar',
            onAction: controller.consumeError,
          ),
        ],
        const SizedBox(height: 16),
        if (state.isConnected) ...<Widget>[
          EzyButton(
            label: 'Cambiar impresora',
            icon: Icons.bluetooth_searching_outlined,
            // Azul Bluetooth: todo lo que es hablar con la impresora.
            variant: EzyButtonVariant.info,
            isLoading: state.isBusy,
            onPressed: () => showPrinterPickerSheet(context),
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Desconectar',
            variant: EzyButtonVariant.text,
            onPressed: state.isBusy ? null : controller.disconnect,
          ),
        ] else ...<Widget>[
          if (state.hasSavedPrinter) ...<Widget>[
            EzyButton(
              label: 'Conectar impresora',
              icon: Icons.bluetooth_connected_outlined,
              variant: EzyButtonVariant.info,
              isLoading: state.isBusy,
              onPressed: state.isAdapterOn
                  ? () => controller.connectSaved()
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          EzyButton(
            label: 'Buscar impresoras',
            icon: Icons.bluetooth_searching_outlined,
            variant: EzyButtonVariant.info,
            onPressed: state.isAdapterOn
                ? () => showPrinterPickerSheet(context)
                : null,
          ),
          if (state.hasSavedPrinter) ...<Widget>[
            const SizedBox(height: 4),
            EzyButton(
              label: 'Olvidar impresora guardada',
              variant: EzyButtonVariant.text,
              onPressed: state.isBusy ? null : controller.forgetPrinter,
            ),
          ],
        ],
      ],
    );
  }
}
