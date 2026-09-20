import '../../../../core/utils/json_reader.dart';

/// Horario de atención del Centro de soporte (`GET /support`).
class SupportScheduleRow {
  const SupportScheduleRow({required this.label, required this.hours});

  factory SupportScheduleRow.fromJson(Map<String, dynamic> json) =>
      SupportScheduleRow(
        label: JsonReader.stringOr(json['label'], ''),
        hours: JsonReader.stringOr(json['hours'], ''),
      );

  final String label;
  final String hours;

  /// `Lunes a viernes · 8:00 AM — 7:00 PM`.
  String get display => hours.isEmpty ? label : '$label · $hours';
}

/// Canal de contacto (`email`, `whatsapp`, ...).
///
/// La app **no** arma la URL: el servidor la entrega lista (`url`), y se abre con
/// el manejador del sistema (`mailto:` / `wa.me`).
class SupportChannel {
  const SupportChannel({
    required this.type,
    required this.label,
    required this.value,
    required this.url,
  });

  factory SupportChannel.fromJson(Map<String, dynamic> json) => SupportChannel(
    type: JsonReader.stringOr(json['type'], ''),
    label: JsonReader.stringOr(json['label'], ''),
    value: JsonReader.stringOr(json['value'], ''),
    url: JsonReader.stringOr(json['url'], ''),
  );

  final String type;
  final String label;
  final String value;

  /// URL lista para abrir (`mailto:...`, `https://wa.me/...`).
  final String url;

  bool get isUsable => url.isNotEmpty;

  String get display => value.isEmpty ? label : '$label · $value';
}

/// Tema del Centro de ayuda.
class SupportTopic {
  const SupportTopic({
    required this.id,
    required this.title,
    required this.description,
  });

  factory SupportTopic.fromJson(Map<String, dynamic> json) => SupportTopic(
    id: JsonReader.stringOr(json['id'], ''),
    title: JsonReader.stringOr(json['title'], ''),
    description: JsonReader.stringOr(json['description'], ''),
  );

  final String id;
  final String title;
  final String description;
}

/// Contenido del Centro de soporte alimentado por `GET /support`.
///
/// Todo el texto viene de `config/support.php` del servidor: la app solo lo
/// pinta (por eso el negocio puede cambiarlo sin publicar una nueva versión).
class SupportContent {
  const SupportContent({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.schedule,
    required this.channels,
    required this.helpCenterUrl,
    required this.helpTopics,
  });

  factory SupportContent.fromJson(Map<String, dynamic> json) => SupportContent(
    title: JsonReader.stringOr(json['title'], 'Centro de soporte'),
    subtitle: JsonReader.stringOr(json['subtitle'], ''),
    message: JsonReader.stringOr(json['message'], ''),
    schedule: JsonReader.toMapList(
      json['schedule'],
    ).map(SupportScheduleRow.fromJson).toList(growable: false),
    channels: JsonReader.toMapList(
      json['channels'],
    ).map(SupportChannel.fromJson).toList(growable: false),
    helpCenterUrl: JsonReader.string(json['help_center_url']),
    helpTopics: JsonReader.toMapList(
      json['help_topics'],
    ).map(SupportTopic.fromJson).toList(growable: false),
  );

  const SupportContent.empty()
    : title = 'Centro de soporte',
      subtitle = '',
      message = '',
      schedule = const <SupportScheduleRow>[],
      channels = const <SupportChannel>[],
      helpCenterUrl = null,
      helpTopics = const <SupportTopic>[];

  final String title;
  final String subtitle;
  final String message;
  final List<SupportScheduleRow> schedule;
  final List<SupportChannel> channels;

  /// Centro de ayuda web; se abre en el navegador externo.
  final String? helpCenterUrl;

  final List<SupportTopic> helpTopics;

  bool get isEmpty =>
      message.isEmpty && channels.isEmpty && schedule.isEmpty;
}
