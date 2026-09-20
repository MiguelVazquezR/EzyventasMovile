import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/available_branch.dart';
import '../../cash/application/cash_register_controller.dart';
import '../../catalog/application/catalog_pickers.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../customers/application/customers_providers.dart';
import '../../pos/application/cart_controller.dart';
import '../../sales/application/sales_controller.dart';
import '../../service_orders/application/service_orders_controller.dart';
import 'account_providers.dart';

/// Estado del cambio de sucursal.
class BranchSwitchState {
  const BranchSwitchState({
    this.isSwitching = false,
    this.errorMessage,
    this.notice,
    this.switchedBranchId,
  });

  final bool isSwitching;

  /// `message` del servidor (p. ej. `403 branch_out_of_scope`).
  final String? errorMessage;

  /// `message` del servidor cuando el cambio funcionó
  /// ("Cambiado a la sucursal: ...").
  final String? notice;

  /// Sucursal que quedó activa (`null` hasta que se cambia).
  final int? switchedBranchId;

  BranchSwitchState copyWith({
    bool? isSwitching,
    String? errorMessage,
    String? notice,
    int? switchedBranchId,
    bool clearError = false,
    bool clearNotice = false,
    bool clearSwitchedBranch = false,
  }) {
    return BranchSwitchState(
      isSwitching: isSwitching ?? this.isSwitching,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      switchedBranchId: clearSwitchedBranch
          ? null
          : (switchedBranchId ?? this.switchedBranchId),
    );
  }
}

/// `PUT /branch/switch/{branchId}` (contrato §11b.1).
///
/// Requiere conexión: el servidor recalcula permisos, módulos y caja de la
/// sucursal nueva y los devuelve en `context`. Después de aplicarlo, la app
/// limpia la caché de la sucursal anterior (catálogo, clientes, ventas, órdenes,
/// caja y carrito) y vuelve a pedir `GET /auth/me` para confirmar.
class BranchSwitchController extends Notifier<BranchSwitchState> {
  @override
  BranchSwitchState build() => const BranchSwitchState();

  Future<bool> switchTo(AvailableBranch branch) async {
    if (branch.isCurrent) {
      return false;
    }

    state = state.copyWith(
      isSwitching: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .switchBranch(branch.id);

      await ref.read(authControllerProvider.notifier).applyContext(
        result.context,
      );

      clearBranchCaches();

      // Confirma el contexto definitivo contra el servidor (contrato §11b.1).
      await ref.read(authControllerProvider.notifier).refreshContext();
      await ref.read(notificationsControllerProvider.notifier).refresh();

      state = state.copyWith(
        isSwitching: false,
        notice: result.message,
        switchedBranchId: result.branchId,
      );

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSwitching: false, errorMessage: error.message);

      return false;
    }
  }

  /// Limpia todo lo que se leyó de la sucursal anterior.
  void clearBranchCaches() {
    ref.invalidate(productsControllerProvider);
    ref.invalidate(productCategoriesProvider);
    ref.invalidate(productDetailProvider);
    ref.invalidate(productSearchProvider);
    ref.invalidate(servicesProvider);
    ref.invalidate(customerSearchProvider);
    ref.invalidate(transactionsControllerProvider);
    ref.invalidate(transactionDetailControllerProvider);
    ref.invalidate(serviceOrdersControllerProvider);
    ref.invalidate(serviceOrderDetailProvider);
    ref.invalidate(serviceOrderDetailControllerProvider);
    ref.invalidate(cashRegisterControllerProvider);
    ref.invalidate(cashSummaryProvider);
    ref.invalidate(bankAccountsProvider);

    // El carrito puede tener productos de la sucursal anterior.
    ref.invalidate(cartControllerProvider);
  }

  void consumeNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }

  void consumeError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final branchSwitchControllerProvider =
    NotifierProvider<BranchSwitchController, BranchSwitchState>(
      BranchSwitchController.new,
    );
