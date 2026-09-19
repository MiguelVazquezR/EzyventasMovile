import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/module_placeholder.dart';

/// Pestaña "Órdenes": listado y detalle de órdenes de servicio.
///
/// El listado, el stepper de estatus, el diagnóstico con fotos y los anticipos
/// llegan en la siguiente etapa.
class ServiceOrdersScreen extends ConsumerWidget {
  const ServiceOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const AppScreenHeader(title: 'Órdenes de servicio'),
            Expanded(
              child: ModulePlaceholder(
                icon: Icons.build_outlined,
                title: 'Órdenes de servicio',
                description:
                    'Seguimiento de reparaciones: estatus, diagnóstico con '
                    'evidencias fotográficas, refacciones y cobro de anticipos. '
                    'Todo lo que se capture aquí se ve igual en la web.',
                upcoming: const <String>[
                  'Listado con buscador y filtros por estatus.',
                  'Detalle con stepper de estatus e historial de cambios.',
                  'Diagnóstico con hasta 5 fotos comprimidas antes de subir.',
                  'Alta y edición de la orden con evidencias y campos personalizados.',
                  'Anticipos y cobro de la orden con ticket de WhatsApp.',
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
