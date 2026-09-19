import '../../../../core/utils/json_reader.dart';

/// Sucursal del negocio incluida en `available_branches`.
///
/// El usuario de soporte (id 1) recibe otra forma (agrupada por suscripción) que
/// la app no necesita: aquí solo se leen las sucursales con `id` y `name`.
class AvailableBranch {
  const AvailableBranch({
    required this.id,
    required this.name,
    required this.isCurrent,
  });

  factory AvailableBranch.fromJson(Map<String, dynamic> json) => AvailableBranch(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    isCurrent: JsonReader.boolean(json['is_current']),
  );

  final int id;
  final String name;
  final bool isCurrent;

  String get label => name.isEmpty ? 'Sucursal $id' : name;

  @override
  String toString() => 'AvailableBranch($id, $name, current: $isCurrent)';
}

/// Ayudas sobre la lista de sucursales del contexto.
extension AvailableBranchList on List<AvailableBranch> {
  /// Sucursal marcada como activa por el servidor.
  AvailableBranch? get currentBranch {
    for (final branch in this) {
      if (branch.isCurrent) {
        return branch;
      }
    }

    return null;
  }
}
