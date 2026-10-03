/// Textos de la pestaña Cuenta (español, sentence case; §11 del design system).
///
/// Se centralizan aquí para que las pruebas de UI verifiquen el microcopy
/// aprobado y no una cadena escrita en cada pantalla.
class AccountLabels {
  const AccountLabels._();

  // Menú principal (§14.2)
  static const String title = 'Mi cuenta';
  static const String subtitle = 'Configuración del usuario';
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
      'Ahorra batería y mejora el confort visual en interiores.';
  static const String logout = 'Cerrar sesión';
  static const String logoutTitle = '¿Quieres cerrar sesión?';
  static const String logoutMessage =
      'Se cerrará la sesión de este dispositivo. Los demás dispositivos siguen '
      'conectados.';
  static const String cancel = 'Cancelar';
  static const String back = 'Regresar';

  // Pantalla Cuenta (rediseño: cabecera, perfil, sucursal, módulos y salida)
  static const String owner = 'Propietario';
  static const String emailUnverified = 'Correo sin verificar';
  static const String branchActive = 'Sucursal activa';
  static const String singleBranchRegistered =
      'Esta es la única sucursal registrada de tu negocio.';
  static const String active = 'ACTIVO';
  static const String modulesEmpty = 'Tu suscripción no tiene módulos activos.';
  static const String subscriptionExpiringBadge = 'POR VENCER';
  static const String logoutConfirmTitle = '¿Cerrar sesión?';
  static const String logoutConfirmMessage =
      'Se cerrará la sesión de este dispositivo. Deberás ingresar tus '
      'credenciales nuevamente para acceder.';
  static const String logoutConfirmAction = 'Sí, salir';
  static const String appVersion = 'EzyVentas POS v0.1.0 · Compilación 1';

  /// `Tu negocio tiene N sucursales registradas.`
  static String branchCountLegend(int count) =>
      'Tu negocio tiene $count sucursales registradas.';

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
  static const String notificationsSubtitle = 'Bandeja de pendientes';
  static const String notificationsEmpty =
      'No tienes notificaciones por ahora.';
  static const String notificationsEmptyTitle =
      'No tienes notificaciones por ahora';
  static const String notificationsEmptyMessage =
      'Todo se encuentra al día. Te notificaremos cuando haya deudas por vencer '
      'o entregas pendientes.';
  static const String notificationsLoading = 'Sincronizando notificaciones…';
  static const String notificationsSyncFailed = 'Fallo al actualizar';
  static const String notificationsRetry = 'Reintentar';
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

  // Centro de soporte (rediseño: cabecera, canales directos y centro de ayuda)
  static const String supportSubtitle = 'Atención al cliente y dudas';
  static const String supportRefresh = 'Actualizar';
  static const String supportChannelsDirect = 'Canales de contacto directo';
  static const String supportHelpCenterGuides = 'Centro de ayuda y guías';
  static const String supportSoonUpper = 'VIENE PRONTO';
  static const String supportHelpCenterActionSoon =
      'Abrir centro de ayuda (Viene pronto)';
  static const String supportLoading = 'Consultando canales de soporte…';
  static const String supportErrorTitle = 'No pudimos conectar con soporte';
  static const String supportErrorSubtitle =
      'Revisa tu conexión para cargar los canales actualizados.';
  static const String supportHelpBanner =
      'Estamos preparando la base de conocimientos interactiva con tutoriales '
      'paso a paso y videos explicativos. Estará disponible en la próxima '
      'actualización.';

  // Suscripción (§14.4)
  static const String subscriptionTitle = 'Mi suscripción';
  static const String subscriptionSubtitle =
      'Administra tu plan comercial, límites y datos fiscales';
  static const String subscriptionPlanStatus = 'Estado del plan';
  static const String subscriptionBusiness = 'Negocio';
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
  static const String subscriptionDocumentNote =
      'Solo imágenes o PDF (máx. 2 MB).';
  static const String subscriptionRequestInvoice = 'Solicitar factura';
  static const String subscriptionInvoiceUnavailable =
      'La factura ya no está disponible para este pago.';
  static const String subscriptionRenew = 'Renovar o mejorar plan';
  static const String subscriptionRenewMessage =
      'La renovación se completa de forma segura en la web.';
  static const String subscriptionRefresh = 'Actualizar';
  static const String subscriptionOwnerOnly =
      'Tu usuario no tiene permiso para acceder a esta sección.';
  static const String subscriptionModules = 'Módulos del sistema';
  static const String subscriptionLimits = 'Límites del plan';
  static const String subscriptionNoPayments =
      'Aún no hay pagos registrados.';

  // Rediseño de suscripción: leyendas, RFC, estados de documento y límites.
  static const String subscriptionRequiredLegend = '* Obligatorio';
  static const String subscriptionRequiredCommercialName =
      'Escribe el nombre comercial.';
  static const String subscriptionTaxId = 'RFC';
  static const String subscriptionUsageServerTitle =
      'Uso acumulado en el servidor';
  static const String subscriptionLimitAtTop = '(Al tope)';
  static const String subscriptionViewDocument = 'Ver documento';
  static const String subscriptionDocumentLoaded = 'Cargada';
  static const String subscriptionDocumentPending = 'Pendiente';

  /// `9 módulos activos` del plan contratado (dato del servidor).
  static String subscriptionActiveModules(int count) =>
      '$count ${count == 1 ? 'módulo activo' : 'módulos activos'}';
}
