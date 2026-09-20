/// Textos de la pestaña Cuenta (español, sentence case; §11 del design system).
///
/// Se centralizan aquí para que las pruebas de UI verifiquen el microcopy
/// aprobado y no una cadena escrita en cada pantalla.
class AccountLabels {
  const AccountLabels._();

  // Menú principal (§14.2)
  static const String title = 'Mi cuenta';
  static const String profile = 'Mi perfil';
  static const String profileSubtitle = 'Foto, nombre, correo y contraseña';
  static const String subscription = 'Mi suscripción';
  static const String subscriptionSubtitle = 'Estado, plan, pagos y documentos';
  static const String support = 'Centro de soporte';
  static const String supportSubtitle = 'Correo, WhatsApp y centro de ayuda';
  static const String notifications = 'Notificaciones';
  static const String notificationsEmptySubtitle = 'Sin avisos por ahora';
  static const String branch = 'Sucursal activa';
  static const String changeBranch = 'Cambiar de sucursal';
  static const String singleBranch =
      'Esta es la única sucursal de tu negocio.';
  static const String noBranchPermission =
      'Tu usuario no puede cambiar de sucursal.';
  static const String modules = 'Módulos contratados';
  static const String preferences = 'Preferencias';
  static const String darkMode = 'Modo oscuro';
  static const String darkModeSubtitle =
      'La app abre en modo oscuro por defecto.';
  static const String logout = 'Cerrar sesión';
  static const String logoutTitle = '¿Quieres cerrar sesión?';
  static const String logoutMessage =
      'Se cerrará la sesión de este dispositivo. Los demás dispositivos siguen '
      'conectados.';
  static const String cancel = 'Cancelar';
  static const String back = 'Regresar';

  // Perfil (§14.3)
  static const String profileTitle = 'Mi perfil';
  static const String personalInfo = 'Información personal';
  static const String changePhoto = 'Cambiar foto';
  static const String deletePhoto = 'Eliminar foto';
  static const String noPhoto = 'Aún no has subido una foto de perfil.';
  static const String name = 'Nombre';
  static const String email = 'Correo electrónico';
  static const String saveChanges = 'Guardar cambios';
  static const String security = 'Seguridad';
  static const String currentPassword = 'Contraseña actual';
  static const String newPassword = 'Nueva contraseña';
  static const String confirmPassword = 'Confirmar contraseña';
  static const String updatePassword = 'Actualizar contraseña';
  static const String activeSessions = 'Sesiones activas';
  static const String activeSessionsMessage =
      'Al cerrar las demás sesiones, los otros teléfonos y las sesiones web '
      'tendrán que iniciar sesión otra vez. Este teléfono sigue conectado.';
  static const String logoutOtherDevices = 'Cerrar otras sesiones';
  static const String confirmClose = 'Confirmar cierre';
  static const String confirmCloseMessage =
      'Escribe tu contraseña para confirmar el cierre de las demás sesiones.';
  static const String password = 'Contraseña';
  static const String photoFailed =
      'No pudimos preparar la foto. Intenta con otra imagen.';

  // Sucursal (§14.6)
  static const String branchTitle = 'Sucursal activa';
  static const String branchSubtitle =
      'El cambio aplica a todos tus dispositivos y a la versión web.';
  static const String branchCurrent = 'Activa';
  static const String branchConfirmMessage =
      'Verás la información de esa sucursal en este dispositivo, igual que en '
      'la web.';
  static const String branchChange = 'Cambiar de sucursal';
  static const String branchChangedGoToCash =
      'Regresa a Caja para abrir el turno de la nueva sucursal.';

  static String branchConfirm(String name) => '¿Cambiar a «$name»?';

  // Notificaciones (§14.6)
  static const String notificationsTitle = 'Notificaciones';
  static const String notificationsEmpty =
      'No tienes notificaciones por ahora.';
  static const String notificationsCached =
      'Sin conexión: se muestra el último valor guardado en el dispositivo.';
  static const String notificationsOpenSales = 'Abre el historial de ventas';
  static const String notificationsReleaseNotes =
      'Las novedades de la versión se leen desde la versión web.';
  static const String notificationsOnlineStore =
      'Los pedidos de la tienda en línea se gestionan desde la versión web.';
}


/// Textos del Centro de soporte y de la suscripción (§14.4 y §14.5).
class AccountMoreLabels {
  const AccountMoreLabels._();

  // Soporte (§14.5)
  static const String supportTitle = 'Centro de soporte';
  static const String supportSchedule = 'Horario de atención';
  static const String supportChannels = 'Canales de contacto';
  static const String supportHelpCenter = 'Centro de ayuda';
  static const String supportHelpCenterAction = 'Abrir centro de ayuda';
  static const String supportTopics = 'Temas de ayuda';

  // Suscripción (§14.4)
  static const String subscriptionTitle = 'Mi suscripción';
  static const String subscriptionGeneralData = 'Datos generales';
  static const String subscriptionCommercialName = 'Nombre comercial';
  static const String subscriptionBusinessName = 'Razón social';
  static const String subscriptionContactPhone = 'Teléfono de contacto';
  static const String subscriptionAddress = 'Dirección';
  static const String subscriptionPlan = 'Plan contratado';
  static const String subscriptionUsage = 'Uso actual';
  static const String subscriptionHistory = 'Historial de pagos';
  static const String subscriptionDocuments = 'Documentos fiscales';
  static const String subscriptionUploadDocument = 'Subir documento';
  static const String subscriptionNoDocument =
      'Aún no has subido tu constancia de situación fiscal.';
  static const String subscriptionDocumentImageOnly =
      'La constancia se sube como imagen (cámara o galería). Para enviar el PDF, '
      'usa la versión web.';
  static const String subscriptionRequestInvoice = 'Solicitar factura';
  static const String subscriptionInvoiceUnavailable =
      'El historial no incluye el identificador del pago: solicita la factura '
      'desde la versión web.';
  static const String subscriptionRenew = 'Renovar o mejorar plan';
  static const String subscriptionRenewMessage =
      'El pago se completa en la versión web; al volver, actualiza esta '
      'pantalla.';
  static const String subscriptionRefresh = 'Actualizar';
  static const String subscriptionOwnerOnly =
      'Tu usuario no tiene permiso para acceder a esta sección.';
  static const String subscriptionModules = 'Módulos';
  static const String subscriptionLimits = 'Límites del plan';
  static const String subscriptionNoPayments =
      'Todavía no hay pagos registrados.';
}
