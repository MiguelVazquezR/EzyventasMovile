import 'package:flutter/material.dart';

/// Tipografía del design system (§3).
///
/// Dos registros: micro-etiquetas técnicas en MAYÚSCULAS pequeñas y montos
/// grandes y delgados. Los colores se pasan desde el tema (`context.surfaces`).
class EzyTextStyles {
  const EzyTextStyles._();

  static const String fontFamily = 'Figtree';

  /// Micro-etiqueta de campo: 10 px, `w700`, tracking 1.4, MAYÚSCULAS.
  static const TextStyle microLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    height: 1.2,
  );

  /// Título de card (`h2`): 14 px, `w700`, MAYÚSCULAS, tracking 1.4.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    height: 1.2,
  );

  /// Título de pantalla (`h1`): 24 px, `w300`, tracking-tight.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.4,
    height: 1.1,
  );

  /// Texto de cuerpo: 14 px.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Texto secundario: 12 px (folios, teléfonos).
  static const TextStyle secondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Monto destacado: 30 px, `w300`, cifras tabulares.
  static const TextStyle moneyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.6,
    height: 1.1,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle moneyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    height: 1.2,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Monto de barra: 19 px `w400` con cifras tabulares.
  ///
  /// Un paso por debajo de [moneyMedium] para el monto que comparte fila con el
  /// resumen del carrito y su acceso: con la letra grande un total largo se
  /// partía en dos renglones.
  static const TextStyle moneyBar = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.1,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Monto en lista: 14 px `w700` con cifras tabulares.
  static const TextStyle moneyList = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Badge / estatus: 10 px `w700`, MAYÚSCULAS, tracking 1.2.
  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.1,
  );

  /// Valor de un campo de formulario.
  static const TextStyle fieldValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
}
