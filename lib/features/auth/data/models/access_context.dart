import '../../../../core/utils/json_reader.dart';
import '../../../cash/data/models/active_cash_session.dart';
import '../../../cash/data/models/cash_register_ref.dart';
import '../../../cash/data/models/joinable_cash_session.dart';
import 'auth_user.dart';
import 'available_branch.dart';

/// Contexto de acceso completo (`login` y `me`).
///
/// Es la única fuente de permisos, módulos y sucursal activa: la app **nunca**
/// los asume ni los escribe a mano.
class AccessContext {
  const AccessContext({
    required this.user,
    required this.moduleKeys,
    required this.modules,
    required this.availableBranches,
    required this.activeSession,
    required this.joinableSessions,
    required this.availableCashRegisters,
  });

  factory AccessContext.fromJson(Map<String, dynamic> json) {
    return AccessContext(
      user: AuthUser.fromJson(JsonReader.toMap(json['user'])),
      moduleKeys: JsonReader.stringList(json['module_keys']),
      modules: JsonReader.stringList(json['modules']),
      availableBranches: _parseBranches(json['available_branches']),
      activeSession: json['active_session'] == null
          ? null
          : ActiveCashSession.fromJson(
              JsonReader.toMap(json['active_session']),
            ),
      joinableSessions: JsonReader.toMapList(
        json['joinable_sessions'],
      ).map(JoinableCashSession.fromJson).toList(growable: false),
      availableCashRegisters: JsonReader.toMapList(
        json['available_cash_registers'],
      ).map(CashRegisterRef.fromJson).toList(growable: false),
    );
  }

  final AuthUser user;

  /// Módulos contratados por el negocio (`module_pos`, `module_services`, ...).
  final List<String> moduleKeys;

  /// Nombres legibles de los módulos contratados.
  final List<String> modules;

  final List<AvailableBranch> availableBranches;

  /// Sesión de caja abierta del usuario, si la hay.
  final ActiveCashSession? activeSession;

  final List<JoinableCashSession> joinableSessions;

  /// Terminales activas y libres de la sucursal.
  final List<CashRegisterRef> availableCashRegisters;

  /// Hay turno abierto: el POS puede cobrar.
  bool get hasActiveSession => activeSession != null;

  /// Nombre del negocio para la cabecera y la pestaña Cuenta.
  String get businessName {
    final commercial = user.subscription?.commercialName ?? '';
    return commercial.isEmpty ? user.branch?.name ?? 'EzyVentas' : commercial;
  }

  /// Sucursal activa según `available_branches` (o la del usuario).
  AvailableBranch? get currentBranch => availableBranches.currentBranch;

  /// Solo hay una sucursal: no se ofrece el selector.
  bool get hasSingleBranch => availableBranches.length <= 1;

  /// `available_branches` tiene dos formas según el usuario:
  /// - sucursales del negocio: `[{id, name, is_current}]`
  /// - usuario de soporte (id 1): `[{subscription_name, branches: [{id, name}]}]`
  ///
  /// Se aplanan ambas para que el selector de sucursal siempre tenga nombres
  /// reales (y nunca un `Sucursal 0` cuando el servidor agrupa).
  static List<AvailableBranch> _parseBranches(Object? raw) {
    final branches = <AvailableBranch>[];

    for (final entry in JsonReader.toMapList(raw)) {
      final nested = JsonReader.toMapList(entry['branches']);

      if (nested.isEmpty) {
        branches.add(AvailableBranch.fromJson(entry));
        continue;
      }

      for (final branch in nested) {
        branches.add(AvailableBranch.fromJson(branch));
      }
    }

    return List<AvailableBranch>.unmodifiable(branches);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user': user.toJson(),
    'module_keys': moduleKeys,
    'modules': modules,
    'available_branches': availableBranches
        .map(
          (branch) => <String, dynamic>{
            'id': branch.id,
            'name': branch.name,
            'is_current': branch.isCurrent,
          },
        )
        .toList(growable: false),
    // Las sesiones de caja se refrescan con /auth/me; se guardan para que la
    // pantalla de Caja responda al abrir la app sin conexión.
    'active_session': activeSession == null
        ? null
        : <String, dynamic>{
            'id': activeSession!.id,
            'status': activeSession!.status,
            'opened_at': activeSession!.openedAt?.toUtc().toIso8601String(),
            'opening_cash_balance': activeSession!.openingCashBalance,
            'cash_register': activeSession!.cashRegister == null
                ? null
                : <String, dynamic>{
                    'id': activeSession!.cashRegister!.id,
                    'name': activeSession!.cashRegister!.name,
                  },
            'opener': activeSession!.opener == null
                ? null
                : <String, dynamic>{
                    'id': activeSession!.opener!.id,
                    'name': activeSession!.opener!.name,
                  },
            'users': activeSession!.users
                .map(
                  (participant) => <String, dynamic>{
                    'id': participant.id,
                    'name': participant.name,
                  },
                )
                .toList(growable: false),
            'totals': <String, dynamic>{
              'cash': activeSession!.totals.cash,
              'card': activeSession!.totals.card,
              'transfer': activeSession!.totals.transfer,
              'balance': activeSession!.totals.balance,
            },
          },
    'available_cash_registers': availableCashRegisters
        .map((register) => <String, dynamic>{'id': register.id, 'name': register.name})
        .toList(growable: false),
    'joinable_sessions': joinableSessions
        .map(
          (session) => <String, dynamic>{
            'id': session.id,
            'opened_at': session.openedAt?.toUtc().toIso8601String(),
            'cash_register': session.cashRegister == null
                ? null
                : <String, dynamic>{
                    'id': session.cashRegister!.id,
                    'name': session.cashRegister!.name,
                  },
            'opener': session.opener == null
                ? null
                : <String, dynamic>{
                    'id': session.opener!.id,
                    'name': session.opener!.name,
                  },
          },
        )
        .toList(growable: false),
  };
}
