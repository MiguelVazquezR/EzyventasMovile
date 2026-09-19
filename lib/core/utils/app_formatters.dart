import 'package:intl/intl.dart';

/// Formatos obligatorios del design system (§10).
///
/// El servidor guarda en UTC y la sucursal tiene `timezone`; la app muestra la
/// hora local del dispositivo.
class AppFormatters {
  const AppFormatters._();

  static final DateFormat _date = DateFormat('d MMM y', 'es_MX');
  static final DateFormat _dateTime = DateFormat('d MMM y, HH:mm', 'es_MX');
  static final DateFormat _time = DateFormat('HH:mm', 'es_MX');
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

  /// ISO-8601 UTC → `DateTime` local. `null` si viene vacío o inválido.
  static DateTime? parse(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }

    return null;
  }

  /// `18 sep 2026`.
  static String date(Object? value) {
    final parsed = parse(value);
    return parsed == null ? '—' : _date.format(parsed);
  }

  /// `18 sep 2026, 14:35`.
  static String dateTime(Object? value) {
    final parsed = parse(value);
    return parsed == null ? '—' : _dateTime.format(parsed);
  }

  /// `14:35`.
  static String time(Object? value) {
    final parsed = parse(value);
    return parsed == null ? '—' : _time.format(parsed);
  }

  /// `YYYY-MM-DD` para los filtros `date_start` / `date_end`.
  static String apiDate(DateTime value) => _apiDate.format(value);

  /// Días completos que faltan para una fecha (negativo si ya venció).
  static int? daysUntil(Object? value) {
    final parsed = parse(value);
    if (parsed == null) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);

    return target.difference(today).inDays;
  }

  /// Iniciales del nombre para el avatar (máximo 2 letras).
  static String initials(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '?';
    }

    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
