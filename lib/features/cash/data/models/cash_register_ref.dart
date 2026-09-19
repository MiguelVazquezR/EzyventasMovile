import '../../../../core/utils/json_reader.dart';

/// Terminal de caja de la sucursal.
class CashRegisterRef {
  const CashRegisterRef({required this.id, required this.name});

  factory CashRegisterRef.fromJson(Map<String, dynamic> json) => CashRegisterRef(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
  );

  final int id;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
}
