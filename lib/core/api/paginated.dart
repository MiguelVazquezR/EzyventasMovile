import '../utils/json_reader.dart';

/// Respuesta paginada del backend (`{data, current_page, last_page, total, ...}`).
///
/// Los endpoints de listado devuelven `per_page` y `last_page`, así que la app
/// sabe cuándo pedir la siguiente página sin adivinar.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory Paginated.fromJson(
    Object? json,
    T Function(Map<String, dynamic> json) parser,
  ) {
    final map = JsonReader.toMap(json);

    return Paginated<T>(
      items: JsonReader.toMapList(map['data']).map(parser).toList(
        growable: false,
      ),
      currentPage: JsonReader.integerOr(map['current_page'], 1),
      lastPage: JsonReader.integerOr(map['last_page'], 1),
      perPage: JsonReader.integerOr(map['per_page'], 20),
      total: JsonReader.integerOr(map['total'], 0),
    );
  }

  const Paginated.empty()
    : items = const <Never>[],
      currentPage = 1,
      lastPage = 1,
      perPage = 20,
      total = 0;

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  bool get isEmpty => items.isEmpty;
}
