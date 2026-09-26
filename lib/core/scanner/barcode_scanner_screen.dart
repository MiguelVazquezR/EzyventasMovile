import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ezy_button.dart';
import '../widgets/ezy_icon_button.dart';
import '../widgets/notice_banner.dart';

/// Abre el escáner a pantalla completa y devuelve el primer código leído (§12).
///
/// Devuelve `null` si el usuario cierra sin leer nada.
Future<String?> showBarcodeScanner(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (routeContext) => const BarcodeScannerScreen(),
    ),
  );
}

/// Escáner de códigos de barras y QR a pantalla completa (§12).
///
/// Cámara a pantalla completa con la barra oscura de cierre arriba, el marco de
/// esquinas y el barrido en `primary`, y la banda inferior con la instrucción.
/// Al leer un código **se cierra y devuelve el texto** al que lo abrió: la
/// confirmación la pinta la pantalla de origen, no una pantalla intermedia.
///
/// El permiso de cámara lo pide el plugin al arrancar (`AndroidManifest` ya
/// declara `CAMERA` para las evidencias de las órdenes). Si se deniega, en lugar
/// de la cámara negra aparece un `NoticeBanner` con lo que hay que hacer y un
/// botón para reintentar: nunca una pantalla en negro (§12).
///
/// [previewBuilder] existe para las pruebas: una prueba de widgets no tiene
/// plugin de cámara, así que se inyecta un lienzo y el estado real del escáner se
/// comprueba en el teléfono. El barrido está **animado en bucle**, así que las
/// pruebas usan `pump()`, no `pumpAndSettle()`.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    this.title = 'Escanear código',
    this.instruction = 'Apunta al código de barras o al QR del producto.',
    this.previewBuilder,
  });

  final String title;
  final String instruction;

  /// Vista previa alternativa a la cámara real (`null` = `MobileScanner`).
  final Widget Function(BuildContext context, ValueChanged<String> onDetect)?
  previewBuilder;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  /// `null` cuando la prueba inyecta su propia vista previa.
  MobileScannerController? _controller;

  /// Primer código leído: el `pop` ya está en marcha y no se repite.
  bool _handled = false;

  MobileScannerErrorCode? _errorCode;

  @override
  void initState() {
    super.initState();

    if (widget.previewBuilder == null) {
      _controller = MobileScannerController()..addListener(_onControllerState);
    }
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_onControllerState)
      ..dispose();
    super.dispose();
  }

  /// El estado del controlador dice si la cámara arrancó o falló (permiso
  /// denegado, sin cámara…): con error se cambia el marco por el aviso.
  void _onControllerState() {
    final code = _controller?.value.error?.errorCode;

    if (code != _errorCode && mounted) {
      setState(() => _errorCode = code);
    }
  }

  /// Cierra la pantalla devolviendo el código leído (§12).
  void _handleCode(String raw) {
    final code = raw.trim();

    if (_handled || code.isEmpty || !mounted) {
      return;
    }

    _handled = true;
    Navigator.of(context).pop(code);
  }

  /// Mensaje del fallo de cámara. No viene del servidor: es del teléfono, así
  /// que se explica qué hacer (§11.3, §12).
  String get _errorMessage => switch (_errorCode) {
    MobileScannerErrorCode.permissionDenied =>
      'La app no tiene permiso para usar la cámara. Actívalo en los ajustes del '
          'sistema (Aplicaciones → EzyVentas → Permisos → Cámara) y vuelve a '
          'intentarlo.',
    MobileScannerErrorCode.unsupported =>
      'Este teléfono no puede escanear códigos. Busca el producto por nombre o '
          'SKU.',
    _ => 'No se pudo abrir la cámara. Vuelve a intentarlo.',
  };

  @override
  Widget build(BuildContext context) {
    final hasError = _errorCode != null;

    return Scaffold(
      backgroundColor: EzyColors.black2,
      body: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: _ScannerTopBar(
              title: widget.title,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _preview(context),
                if (hasError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          NoticeBanner(message: _errorMessage),
                          const SizedBox(height: 12),
                          EzyButton(
                            label: 'Reintentar',
                            icon: Icons.refresh,
                            variant: EzyButtonVariant.outline,
                            expand: false,
                            textColor: EzyColors.white,
                            onPressed: () => _controller?.start(),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const IgnorePointer(child: _ScanFrame()),
              ],
            ),
          ),
          _ScannerBottomBand(instruction: widget.instruction),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final injected = widget.previewBuilder;

    if (injected != null) {
      return injected(context, _handleCode);
    }

    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;

          if (value != null && value.trim().isNotEmpty) {
            _handleCode(value);

            return;
          }
        }
      },
      // Con error el aviso lo pinta el `Stack` de arriba: aquí solo se deja el
      // fondo, sin el icono de error que el plugin trae por defecto.
      errorBuilder: (context, error) =>
          const ColoredBox(color: EzyColors.black2),
    );
  }
}

/// Barra superior del escáner: franja `black2`, cierre circular y título blanco
/// centrado (§12).
class _ScannerTopBar extends StatelessWidget {
  const _ScannerTopBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EzyColors.black2,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: <Widget>[
          EzyIconButton(icon: Icons.close, tooltip: 'Cerrar', onTap: onClose),
          const SizedBox(width: 4),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: EzyColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marco de escaneo: 4 esquinas de 32 × 32 (trazo 4, radio 8) y la línea de
/// barrido de 3 px, todo en `primary` y sin recuadro oscuro alrededor (§12).
class _ScanFrame extends StatefulWidget {
  const _ScanFrame();

  /// Lado del recuadro de las esquinas.
  static const double side = 260;

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, child) => CustomPaint(
          size: const Size(_ScanFrame.side, _ScanFrame.side),
          painter: _ScanFramePainter(progress: _sweep.value),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter({required this.progress});

  /// 0 = arriba del recuadro, 1 = abajo.
  final double progress;

  static const double _corner = 32;
  static const double _stroke = 4;
  static const double _radius = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Offset.zero & size;
    final corner = Paint()
      ..color = EzyColors.primary
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Cuatro esquinas en L, con el vértice redondeado.
    for (final anchor in <Alignment>[
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ]) {
      final point = anchor.withinRect(frame);
      final dx = anchor.x < 0 ? 1.0 : -1.0;
      final dy = anchor.y < 0 ? 1.0 : -1.0;
      final path = Path()
        ..moveTo(point.dx + dx * _corner, point.dy)
        ..lineTo(point.dx + dx * _radius, point.dy)
        ..quadraticBezierTo(
          point.dx,
          point.dy,
          point.dx,
          point.dy + dy * _radius,
        )
        ..lineTo(point.dx, point.dy + dy * _corner);

      canvas.drawPath(path, corner);
    }

    // Barrido: línea horizontal centrada que sube y baja dentro del recuadro.
    final centerY = size.height * (0.08 + progress * 0.84);
    final sweep = Paint()
      ..color = EzyColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.06, centerY),
      Offset(size.width * 0.94, centerY),
      sweep,
    );
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Banda inferior del escáner: la instrucción centrada en blanco (§12).
class _ScannerBottomBand extends StatelessWidget {
  const _ScannerBottomBand({required this.instruction});

  final String instruction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: EzyColors.black2,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SafeArea(
        top: false,
        child: Text(
          instruction,
          textAlign: TextAlign.center,
          style: EzyTextStyles.body.copyWith(color: EzyColors.white),
        ),
      ),
    );
  }
}
