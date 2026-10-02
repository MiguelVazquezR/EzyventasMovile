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
///
/// Es el **contenido** de la card «Impresora» de la hoja de impresión: el
/// contenedor (color, radio y borde) lo pone la hoja, así que aquí no se anida
/// ninguna caja. Todo lo que habla con la impresora va en azul Bluetooth
/// ([EzyColors.bluetooth]): el color identifica la acción, no el estado.
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
        _PrinterStatusRow(state: state),
        const SizedBox(height: 10),
        Text(
          state.isConnected
              ? 'La impresora está lista: el ticket sale en cuanto lo envías.'
              : 'Los tickets se imprimen en la impresora térmica emparejada del '
                    'teléfono.',
          style: TextStyle(
            fontFamily: EzyTextStyles.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: surfaces.textMuted,
          ),
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
        const SizedBox(height: 14),
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

/// Fila del estado: icono en círculo, nombre de la impresora y chip de conexión.
class _PrinterStatusRow extends StatelessWidget {
  const _PrinterStatusRow({required this.state});

  final PrinterState state;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final connected = state.isConnected;
    final accent = EzyColors.bluetooth;

    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: connected ? accent.withValues(alpha: 0.16) : surfaces.panel,
            shape: BoxShape.circle,
            border: Border.all(
              color: connected
                  ? accent.withValues(alpha: 0.6)
                  : surfaces.borderStrong,
            ),
          ),
          child: Icon(
            connected
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled_outlined,
            size: 17,
            color: connected ? accent : surfaces.textMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      connected
                          ? (state.connectedName ?? 'Impresora conectada')
                          : 'Impresora Bluetooth',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: EzyTextStyles.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: surfaces.textPrimary,
                      ),
                    ),
                  ),
                  if (state.isBusy) ...<Widget>[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                connected ? 'Lista para imprimir' : state.statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: EzyTextStyles.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: surfaces.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _PrinterStatusChip(connected: connected),
      ],
    );
  }
}

/// Chip «Conectada» en azul Bluetooth (apagado cuando no hay impresora).
class _PrinterStatusChip extends StatelessWidget {
  const _PrinterStatusChip({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final accent = EzyColors.bluetooth;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: connected ? accent.withValues(alpha: 0.12) : surfaces.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: connected ? accent.withValues(alpha: 0.35) : surfaces.border,
        ),
      ),
      child: Text(
        connected ? 'Conectada' : 'Sin conexión',
        style: TextStyle(
          fontFamily: EzyTextStyles.fontFamily,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: connected ? accent : surfaces.textMuted,
        ),
      ),
    );
  }
}
