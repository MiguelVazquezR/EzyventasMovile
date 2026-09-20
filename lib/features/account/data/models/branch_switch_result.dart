import '../../../../core/utils/json_reader.dart';
import '../../../auth/data/models/access_context.dart';

/// Resultado de `PUT /branch/switch/{branchId}` (contrato §11b.1).
///
/// El servidor devuelve el **contexto completo** (`context`) con los permisos,
/// los módulos, la sucursal activa y la sesión de caja de la nueva sucursal: la
/// app lo aplica tal cual, sin volver a calcular nada.
class BranchSwitchResult {
  const BranchSwitchResult({
    required this.branchId,
    required this.branchName,
    required this.message,
    required this.context,
  });

  factory BranchSwitchResult.fromJson(Map<String, dynamic> json) {
    final branch = JsonReader.toMap(json['branch']);

    return BranchSwitchResult(
      branchId: JsonReader.integerOr(branch['id'], 0),
      branchName: JsonReader.stringOr(branch['name'], ''),
      message: JsonReader.stringOr(json['message'], ''),
      context: AccessContext.fromJson(JsonReader.toMap(json['context'])),
    );
  }

  final int branchId;
  final String branchName;

  /// `message` del servidor ("Cambiado a la sucursal: Centro").
  final String message;

  /// Contexto de acceso ya recalculado por el servidor.
  final AccessContext context;
}
