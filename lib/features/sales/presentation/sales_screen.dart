import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/module_placeholder.dart';

/// Pestaña "Ventas": historial, detalle, abonos y cancelaciones.
///
/// Se habilita en la siguiente etapa.
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const AppScreenHeader(title: 'Ventas'),
            Expanded(
              child: ModulePlaceholder(
                icon: Icons.receipt_long_outlined,
                title: 'Ventas',
                description:
                    'Historial con filtros y detalle completo de cada venta, '
                    'abonos, cancelaciones y reembolsos.',
                upcoming: const <String>[
                  'Historial con búsqueda, filtro por estatus y rango de fechas.',
                  'Detalle con ítems, pagos, totales y saldo pendiente.',
                  'Registro de abonos con el ticket listo para WhatsApp.',
                  'Cancelación y reembolso con motivo, y edición de pagos.',
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
