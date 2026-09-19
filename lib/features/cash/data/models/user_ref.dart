import '../../../../core/utils/json_reader.dart';

/// Referencia mínima a un usuario (`opener`, `users[]`, `technician`).
class UserRef {
  const UserRef({required this.id, required this.name});

  factory UserRef.fromJson(Map<String, dynamic> json) => UserRef(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
  );

  final int id;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
}
