# EzyVentas - app movil (Flutter / Android)

Cliente Android de **EzyVentas**: punto de venta y ordenes de servicio contra la API REST
`/api/v1` del backend Laravel. Esta entrega es el **modo online** (todo se resuelve contra el
servidor). La fase offline (SQLite + cola de sincronizacion) **no** esta implementada: la capa
de datos ya esta aislada para anadirla sin reescribir la UI.

---

## 1. Como correr el proyecto

Requisitos: Flutter 3.47+ (Dart 3.13) y Android SDK con `minSdk 23`.

> **Importante (ruta del SDK).** El SDK de Flutter **no puede vivir en una ruta con espacios**:
> al compilar para Android, el paso de *native assets* (build hooks de `objective_c`, que llega
> como dependencia transitiva) lanza un comando con la ruta sin comillas y falla con
> `"C:\Users\windows" no se reconoce como un comando interno o externo.`, dejando el APK sin
> compilar. En este equipo hay dos SDK del mismo Flutter 3.47.4 y el proyecto usa el de
> `C:\flutter` (sin espacios) mediante `.vscode/settings.json` (`dart.flutterSdkPath`). Si corres
> desde una terminal, usa `C:\flutter\bin\flutter` (o pon `C:\flutter\bin` al principio del
> `PATH`).

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://ezyventas2.test/api/v1
```

La URL base **nunca** se escribe dentro de un widget: se inyecta con `--dart-define` y vive en
`lib/core/config/app_config.dart` (`AppConfig.apiBaseUrl`). Valor por defecto:
`https://ezyventas2.test/api/v1` (entorno local). El release debe sobreescribirlo:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://app.ezyventas.com/api/v1
```

| Variable | Default | Uso |
|---|---|---|
| `API_BASE_URL` | `https://ezyventas2.test/api/v1` | Base de la API |
| `DEVICE_NAME` | `EzyVentas Android` | Nombre del token en Sanctum |
| `ALLOW_BAD_CERTIFICATE` | `true` | Acepta el certificado autofirmado local |

```bash
flutter analyze     # debe quedar sin issues
flutter test        # 219 tests: dinero, errores, sesion, permisos, catalogo, caja, cobro,
                    # ventas, ordenes, impresion (CP850, ESC/POS del corte, plantillas,
                    # ESC/POS/HTML/WhatsApp, filtro de plantillas por contexto, la hoja de
                    # impresion en pantalla) y cuenta (sucursal, notificaciones, soporte,
                    # perfil y suscripcion)
```

Pruebas **reales** contra el servidor (no corren en `flutter test` normal):

```bash
# Etapa 1-2: login, permisos, catálogo y clientes
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto

# Etapa 3: turno de caja + venta de contado + corte (crea datos reales)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_POS=true

# Etapa 4: historial, filtros y detalle (solo lectura)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_SALES=true

# Etapa 4 con escritura: abona $1, lo edita y lo borra (deja la venta igual)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_SALES=true \
  --dart-define=LIVE_SALES_WRITE=true

# Etapa 4 completa: crea un APARTADO, lo abona, edita y borra el pago y lo
# cancela con reembolso en efectivo (deja el stock devuelto; ver hallazgo 8)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_SALES=true \
  --dart-define=LIVE_SALES_LAYAWAY=true

# Etapa 5: órdenes de servicio (solo lectura del listado y los filtros)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --plain-name "de servicio reales"

# Etapa 5 completa: crea una orden con foto, cambia estatus, guarda el
# diagnóstico con evidencia, cobra un anticipo de $10, la edita, prueba
# ensure-transaction y la BORRA al final (deja la base de datos limpia)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_SERVICE_ORDERS=true \
  --plain-name "de servicio reales"

# Etapa 5 con refacción: además agrega un producto como concepto (descuenta
# stock real y el borrado de la orden NO lo devuelve, igual que la web)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_SERVICE_ORDERS=true \
  --dart-define=LIVE_SERVICE_ORDERS_STOCK=true \
  --plain-name "de servicio reales"

# Etapa 6: plantillas, ticket ESC/POS, etiqueta TSPL, respaldo HTML y el texto
# de WhatsApp de una venta real (solo lectura; no crea ni modifica datos)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_PRINTING=true \
  --plain-name "impresi"

# Etapa 6 sobre una orden real: la etapa 5 crea la orden, la imprime (ESC/POS,
# HTML y WhatsApp) y la borra al final
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_SERVICE_ORDERS=true \
  --dart-define=LIVE_PRINTING=true \
  --plain-name "de servicio reales"

# Etapa 7: cuenta real (solo lectura) — notificaciones, soporte y perfil
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_ACCOUNT=true \
  --plain-name notificaciones

# Etapa 7 con suscripción: plan, límites, historial y escrituras REVERSIBLES
# (guarda el perfil y la suscripción con los mismos datos, comprueba los 422 de
# contraseña/documento y el 404 de una factura inexistente)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_ACCOUNT=true \
  --dart-define=LIVE_ACCOUNT_WRITE=true \
  --plain-name plan

# Etapa 7: cambio de sucursal de ida y vuelta (deja la cuenta como estaba)
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_ACCOUNT_BRANCH=true \
  --plain-name ida

# Etapa 7 con un empleado: la vista de suscripción debe responder 403 y el
# mensaje del servidor es el que se muestra
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=empleado@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_EXPECT_OWNER=false \
  --dart-define=LIVE_ACCOUNT=true \
  --plain-name plan
```

> El login de la API tiene *rate limit*: si aparece `429 Demasiadas solicitudes. Espera un momento e
> inténtalo de nuevo.` (el mismo `message` que muestra la app), espera ~1 minuto entre corridas. Para
> correr solo el escenario de ventas: añade `--plain-name ventas` (un solo login).

```bash
# Etapa 8: prueba de dispositivo REAL (login, pestañas, catálogo y Cuenta) en un
# teléfono Android conectado por USB con el túnel activo (ver §4.1). Instalar en
# un Xiaomi/Redmi tiene su propio requisito: ver §4.2.
flutter test integration_test/qa_device_test.dart -d <serial> \
  --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 \
  --dart-define=API_HOST_HEADER=ezyventas2.test \
  --dart-define=LIVE_API_EMAIL=propietario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_EMPLOYEE_EMAIL=empleado@negocio.com \
  --dart-define=LIVE_EMPLOYEE_PASSWORD=secreto
```

---

## 2. Credenciales de prueba

| Rol | Cuenta usada | Uso |
|---|---|---|
| Propietario de negocio (usuario **sin roles**) | `jean@apontephone.com` | Flujo completo: todas las pestañas |
| Empleado con permisos limitados | `ofelia@stilos.com` (Stilos boutique · Tizapan) | Valida `403`, pestañas ocultas y el flujo de caja/ventas sin ser propietaria |
| Empleado del mismo negocio | `daniel@apontephone.com` (ApontePhone · Melchor Ocampo) | Sin `system.branches.switch`, sin `settings.*`, sin `dashboard.*` ni `financial_reports.access`; **sí** tiene todos los `services.orders.*` |

`ofelia@stilos.com` tiene `pos.*`, `cash_registers.*` y `transactions.*` (incluye `add_payment`,
`edit_payment`, `cancel`, `refund`), pero **no** `services.orders.access` ni
`system.branches.switch`: sus pestañas son **Vender, Caja, Ventas y Cuenta** (sin Órdenes y sin
selector de sucursal), y `GET /service-orders` responde `403`.

`daniel@apontephone.com` **no** sirve para validar el `403` de las órdenes (tiene
`services.orders.access`): sirve para verificar que un usuario sin `system.branches.switch` no ve el
selector de sucursal y que sus pestañas excluyen lo que no le toca (`settings.*`, reportes). En la
etapa 7 también se usó para comprobar que **no** es propietario de la suscripción: la opción «Mi
suscripción» no aparece en su menú y `GET /subscription` responde `403`.

> Al correr las pruebas reales con `--plain-name <texto>` conviene usar un fragmento **sin acentos**
> (`notificaciones`, `plan`, `ida`): `cmd`/PowerShell del entorno recorta las tildes al pasar el
> argumento y el filtro no encontraría la prueba.

Las contrasenas **no** se guardan en el repositorio: se capturan en la pantalla de login o se pasan
por `--dart-define`. **Nunca** se usa `ezyventas@gmail.com` (superadmin id 1) para validar
permisos: su bypass oculta errores reales.

---

## 3. Decisiones tecnicas

### Certificado local autofirmado
El servidor de desarrollo usa HTTPS con certificado autofirmado. Se resuelve en
`ApiClient._buildDio()` con `badCertificateCallback` **solo en modo debug** (y solo si
`ALLOW_BAD_CERTIFICATE` no se desactiva). En release el certificado se valida normalmente. En un
telefono fisico, `ezyventas2.test` debe resolverse en la red (DNS/hosts del router) o apuntar
`API_BASE_URL` a la IP del equipo.

### Tipos decimales del contrato
El backend mezcla **texto decimal** (`"270.00"`) y **numero** (`270.0`) segun el campo. Toda
lectura pasa por `Money.toNullableDouble()`, que acepta ambos (incluso `"1,240.00"` o
`"$270.00"`), y el formato de salida es `NumberFormat` **es-MX** (`Money.format` -> `$1,240.00`).
Nunca se hace aritmetica con un `String`.

### Permisos y modulos
`PermissionsService` se construye unicamente con `user.permissions` y `module_keys` que devuelve
el servidor (`login` / `me`). No hay roles ni permisos hardcodeados: las pestanas se calculan en
`AppTab` + `PermissionsService.visibleTabs`, y el `redirect` de `go_router` devuelve al usuario a
su primera pestana disponible si intenta abrir una oculta.

Los tres permisos que usa esta entrega son los mismos que valida el servidor: `pos.access` (Caja y
POS), `pos.create_sale` (cobro, apartado y pedido) y `pos.edit_prices` (precio/descuento manual en
la linea del carrito). Sin `pos.create_sale` el carrito no aparece.

### Caja (etapa 3)
`GET /cash-register-sessions/current` alimenta la pestana Caja: turno activo con sus cobros por
metodo, turnos a los que unirse/retomar, terminales libres y cuentas bancarias con su saldo.

- **Apertura** (`POST /cash-register-sessions`): terminal libre + fondo de efectivo + saldos
  bancarios declarados (precargados y editables). Si el servidor responde `409
  cash_register_in_use`, la app lee `session_id` / `opened_by` del cuerpo del error
  (`ApiException.details`) y ofrece **"Unirme a esa sesion"** en lugar de mostrar un error seco.
- **Unirse / retomar / salir**: `POST /{id}/join`, `POST /rejoin-or-start` (hereda fondo y saldos
  del ultimo corte) y `POST /{id}/leave`.
- **Corte** (`GET /{id}/summary` → `PUT /{id}`): tres pasos como el modal web (resumen → aviso si
  hay mas de un usuario en la sesion → arqueo). La **diferencia en vivo** se calcula como
  `contado - esperado` (verde sin diferencia, naranja con descuadre); el boton "Finalizar turno"
  se habilita al capturar el efectivo contado. La app **no** crea ingresos/egresos de efectivo
  (eso es web) y no edita el corte.
- Al abrir, unir o cortar, la sesion se sincroniza con `AuthController.setActiveSession(...)` sin
  volver a pedir `/auth/me`: el POS queda habilitado de inmediato y el punto verde de la pestana
  Caja se actualiza. `current` se refresca en segundo plano y al volver la app a primer plano
  (cierre remoto desde la web).

### Cobro (POS, etapa 3)
El carrito replica **exactamente** las formulas del POS web (`ShoppingCart.vue`), nunca las
inventa la app:

| Concepto | Formula |
|---|---|
| `subtotal` | `Σ(precio de lista x cantidad)` |
| `total_discount` | `Σ(descuento por unidad x cantidad)` |
| `total` | `subtotal - total_discount` (+ `shipping_cost` en pedidos) |
| `discount` (por unidad) | `precio de lista - unit_price` (nunca negativo; si sube, `0` + "Aumento manual") |

- **Precio de la linea**: promocion de linea (`price`), mayoreo por cantidad (`price_tiers`) y
  variante (`selling_price + price_modifier`). Con `pos.edit_prices` el cajero puede capturar
  precio/descuento manual; el motivo viaja como `discount_reason` ("Descuento manual",
  "Precio de mayoreo", "Promocion de producto").
- **Cliente**: `POST /pos/checkout` con `customerId` o `guest_name` (publico general). Si la venta
  no se cubre, la app bloquea antes de enviar con los mismos textos del servidor
  (`customer_required`, `credit_limit_exceeded`) y ofrece el saldo a favor con `use_balance`.
- **Pago mixto**: efectivo / tarjeta / transferencia; `bank_account_id` obligatorio en tarjeta y
  transferencia (cuentas de `GET /bank-accounts`). El saldo a favor **no** es un pago: va como
  `use_balance: true` y el servidor lo registra como metodo `saldo`.
- **Cambio**: se muestra el que devuelve el servidor (solo efectivo puro, `Σ pagos - total`); la
  vista previa usa la misma regla.
- **Apartado** (`POST /pos/layaway`) con fecha limite obligatoria posterior a hoy y **pedido /
  comanda** (`POST /pos/store-order`) con contacto, fecha/hora de entrega, direccion, envio y
  notas. Los tres exigen turno abierto: sin sesion, la barra del carrito avisa y lleva a Caja.
- `client_uuid` idempotente por operacion: reintentar el mismo cobro no duplica la venta.
- Tras cobrar se refrescan el catalogo (stock) y el turno (cobros por metodo) y se muestra el
  **folio real** con el cambio; la impresion y el WhatsApp llegan en la etapa 6.

### Ventas (etapa 4)
`features/sales/` cubre el historial, el detalle y el dinero de una venta ya registrada.

- **Historial** (`GET /transactions`): búsqueda (folio, cliente o contacto), chips de estatus,
  rango de fechas (`Desde` / `Hasta` → `date_start` / `date_end` en `YYYY-MM-DD`) y orden
  (`created_at`, `folio`, `customer.name`, `total`). Paginacion infinita de 20 en 20: el servidor
  pagina el resultado ya filtrado y la app solo acumula paginas (`perPage` maximo 100).
- **Detalle** (`GET /transactions/{id}`): hoja con folio y estatus, cliente con saldo y limite de
  credito, lineas (`quantity` x precio, descuento y motivo), totales (`paid_amount` /
  `pending_balance` / `is_paid` ya resueltos por el servidor), pagos con su cuenta destino, factura
  (solo folio y estatus), sucursal, cajero, sesion de caja, fechas de entrega/apartado y notas.
  Exige `transactions.see_details`: sin el permiso la app avisa y no pide nada al servidor.
- **Abono** (`POST /transactions/{id}/payments`): exige turno abierto (`sessionId` del contexto) y
  permiso `transactions.add_payment`. Pago mixto (efectivo/tarjeta/transferencia), `use_balance`
  para el saldo a favor y accion rapida **"Liquidar saldo"**. La app **no** permite exceder el
  saldo pendiente: el servidor rechaza el sobrepago (ver discrepancias) y el texto que se muestra
  es el suyo. Al confirmar se pinta el **ticket de abono** que devuelve el servidor
  (`print.payload`) tal cual: los montos llegan formateados y no se recalculan.
- **Anular** (`POST /transactions/{id}/refund` y `POST /transactions/{id}/cancel`): la opcion
  "Devolver al cliente (reembolso)" usa `/refund` (permiso `transactions.refund`) y "Cobrar como
  penalizacion" usa `/cancel` con `action: penalty` (permiso `transactions.cancel`). El metodo de
  reembolso es `cash` (solo con turno abierto), `balance` (solo con cliente) o `transfer` (con
  `bank_account_id`). El `message` del servidor explica el resultado ("reembolsado en efectivo /
  al saldo / por transferencia / cancelado con penalizacion") y se muestra en el detalle.
- **Editar o borrar un pago** (`PUT` / `DELETE .../payments/{paymentId}`): monto, metodo
  (efectivo, tarjeta, transferencia y saldo de cliente, mas `intercambio` si es el metodo actual),
  cuenta destino y notas internas. El borrado pide confirmacion explicita y responde `204` sin
  cuerpo, asi que despues se vuelve a leer la venta para mostrar el saldo definitivo.
- Las acciones se muestran segun el permiso y el estatus: con la venta `cancelado`/`reembolsado`
  no hay abonos, ni cancelacion, ni edicion de pagos (misma regla que la web).

### Órdenes de servicio (etapa 5)
`features/service_orders/` cubre la lista de trabajo del taller, el detalle y todas las escrituras
de una orden (`01-contrato-api-v1.md` §9).

- **Listado** (`GET /service-orders`): buscador (folio, cliente o equipo), chips con los 6 estatus,
  orden (`received_at`, `promised_at`, `folio`, `final_total`) y paginacion infinita de 20 en 20.
  Cada tarjeta muestra folio, estatus, cliente, equipo, tecnico, la promesa de entrega (en rojo si ya
  vencio) y el saldo pendiente.
- **Detalle** (`GET /service-orders/{id}`): hoja con el **stepper** de 5 pasos (círculos de 46 px,
  halo en el paso actual, check en los cumplidos y banda roja si esta cancelada), cliente y equipo,
  fallas reportadas, diagnostico, conceptos (mano de obra vs. refaccion), panel financiero
  (`subtotal`, descuento, total, pagado, saldo) y, solo con `services.orders.see_financial_info`,
  refacciones, comision del tecnico y utilidad neta (§8.5). Ademas: anticipos de la venta vinculada
  (`OS-V-###`), evidencias de recepcion y de cierre, campos personalizados e historial (ultimos 20).
- **Cambio de estatus** (`PATCH .../status`): el stepper ofrece avanzar (permiso
  `services.orders.change_status`) y regresar (permiso `services.orders.edit` + confirmacion
  explicita) o cancelar. Un `422` se muestra con el texto real de **`errors.status[0]`** (estatus
  repetido o invalido), que es lo que pide el contrato. Al pasar a `entregado` con saldo pendiente la
  app abre el cobro (§8.2).
- **Diagnóstico** (`POST .../diagnosis`, multipart): texto (max. 1000) + hasta 5 fotos por peticion.
  Las fotos se comprimen antes de subir (libre de `image_picker` + `flutter_image_compress` en
  `core/utils/evidence_image.dart`: 1600 px y calidad descendente hasta bajar de 2 MB). Enviar el
  campo vacio **borra** el diagnostico previo; no enviarlo lo **conserva** (la hoja avisa de ambas
  cosas y no manda el campo si el usuario no lo toca).
- **Alta y edición** (`POST` / `PUT`, multipart): pantalla completa (`/service-orders/new` y
  `/service-orders/{id}/edit`) con cliente (buscar, capturar a mano o `create_customer` +
  `credit_limit`), equipo, fallas, promesa de entrega (`YYYY-MM-DD`), conceptos (servicios o
  variantes del catalogo, refacciones o concepto libre), descuento fijo o porcentual, tecnico con
  comision (`percentage`/`fixed`), hasta 5 fotos y, al editar, borrado de evidencias existentes
  (`deleted_media_ids`) y los campos personalizados que devuelve el detalle.
  El cuerpo viaja como **multipart** cuando hay fotos y como **JSON** cuando no las hay, para no
  convertir a texto los numeros ni los booleanos (`multipart/form-data` exige `1`/`0` en los
  booleanos porque Laravel no acepta la cadena `"true"`).
- **Anticipos** (`POST .../payments`): mismo flujo que el abono de una venta (pago mixto y saldo a
  favor) contra la orden; el servidor resuelve o crea la venta vinculada. Con `transactions.add_payment`
  y turno abierto. Si la orden no tiene venta (`transaction: null`), \"Cobrar ahora\" llama primero a
  `POST .../ensure-transaction`.
- **Borrado** (`DELETE`, `204`): confirmacion explicita (\"Esta accion no se puede deshacer: se
  eliminara la orden y su venta vinculada.\"); al terminar se cierra la hoja y se refresca la lista.
- Permisos: la pestaña exige `services.orders.access` + `module_services`; las acciones de la hoja
  usan `services.orders.see_details`, `create`, `edit`, `change_status`, `delete` y
  `transactions.add_payment`, y la utilidad del panel financiero `services.orders.see_financial_info`.

### Impresión, WhatsApp y corte (etapa 6)

`features/printing/` concentra la selección de plantilla, la impresión, el respaldo y WhatsApp
(`01-contrato-api-v1.md` §10). La app **nunca** dibuja ni interpreta una plantilla: pide al servidor
el documento ya codificado.

- **Plantillas** (`GET /print/templates`): se piden por **tipo** (`ticket_venta`, `etiqueta`) y se
  cachean en memoria; el conjunto de **contextos** válidos lo aplica el documento (ver hallazgo 17).
  La elegida se recuerda por tipo en el dispositivo, y cuando el cobro ya manda `print.template_ids`
  la app respeta esos ids (`PrintDocument.posCheckout`).
- **Hoja de impresión** (una sola, reutilizada en todos los flujos): estado de la impresora +
  conectar/cambiar/olvidar, selector de plantilla, interruptor de **abrir cajón**, `Imprimir ticket`,
  `Imprimir etiqueta` (TSPL, cuando el negocio tiene plantillas de etiqueta), `Ver respaldo HTML` y
  `Enviar por WhatsApp`.
- **Ticket** (`POST /print/bluetooth-payload`): `commands_base64` → `Uint8List` → bloques de 20 bytes.
  Si la impresora se desconecta a media impresión se avisa y se permite reimprimir; el ticket **no**
  se marca como impreso (no hay reimpresión automática).
- **Etiquetas** (`POST /print/payload`): se envía el comando TSPL completo de la operación
  `EscribirTexto`; si la plantilla trae imágenes que el teléfono no puede rasterizar, se avisa.
- **Respaldo** (`POST /print/ticket-html`): se muestra el HTML del mismo documento para copiarlo.
- **WhatsApp** (`POST /print/whatsapp-ticket`): el ticket lo arma el servidor y la app lo convierte al
  **mismo texto que la web** (`WhatsAppMessageBuilder`, réplica de `useWhatsAppTicket.js` para
  `sale`, `abono`, `order` y `order_payment`), abre una vista previa y lanza
  `https://wa.me/{customer_phone}?text=…` (con el prefijo 52 en teléfonos de 10 dígitos); sin teléfono
  abre `https://wa.me/?text=…` para elegir el contacto.
- **Dónde se ofrece**: al cobrar (carrito), al abonar una venta o un pedido (con el ticket que devolvió
  la operación), al **cerrar caja**, y desde el detalle de venta/pedido y de orden de servicio. El
  detalle de producto ofrece `Imprimir etiqueta`.
- **Corte de caja**: el ticket se arma en el teléfono (`CashCutRenderer` + `EscPosBuilder`, CP850,
  corte parcial y apertura de cajón) con el `summary` que ya calculó el servidor: encabezado, periodo
  del turno, efectivo, cobros por método, movimientos, bancos, total esperado, contado y diferencia
  (ver hallazgo 20). También se puede enviar por WhatsApp como texto.

### Corrida real del 19 sep 2026 (evidencia)
Contra `https://ezyventas2.test/api/v1`, con las dos cuentas.

**Propietario de negocio** (`jean@apontephone.com`, ApontePhone · sucursal `Melchor Ocampo`):

| Prueba | Resultado |
|---|---|
| Login + `/auth/me` | `owner=true`, **85 permisos**, 9 modulos |
| Pestanas visibles | `Vender · Ordenes · Caja · Ventas · Cuenta` (las 5) |
| Catalogo (`GET /catalog/products`) | 2 productos: `Funda iphone` ($35, stock 35, **2 variantes**) e `Iphone 20` ($12,000, stock 5) |
| Categorias y servicios | 2 categorias de producto + 1 de servicio, 1 servicio |
| Clientes | `Juanito babanas` (saldo $0.00, credito $20,000.00, disponible $20,000.00) + ficha con apartados/movimientos |
| Caja | turno abierto con fondo `$1,000.00` + 3 saldos bancarios precargados (terminal libre) |
| Venta de contado | folio **`V-001`**, variante `Color Rojo`, total `$70.00`, `completado`, cambio `$0.00`, plantilla de impresion `[3]` |
| Corte (`GET /summary` + `PUT`) | esperado `$1,070.00` = contado `$1,070.00`, **diferencia `$0.00`**, sesion `cerrada` |
| Historial y detalle | `V-001` con 1 linea, 1 pago, `pagada=true`; filtros por estatus/fecha |

**Empleada con permisos limitados** (`ofelia@stilos.com`, Stilos boutique · `Tizapan`):

| Prueba | Resultado |
|---|---|
| Login + `/auth/me` + permisos | 26 permisos, 8 modulos, sucursal `Tizapan` |
| Pestanas visibles | `Vender · Caja · Ventas · Cuenta` (sin Ordenes: no tiene `module_services`) |
| `GET /service-orders` | `403` → "Tu usuario no tiene permiso para esta acción." |
| Historial | `GET /transactions` paginado (7 ventas, `last_page=2`), filtros por estatus y fechas |
| Detalle | `GET /transactions/{id}` con items, pagos y desglose (`is_paid`, `pending_balance`) |
| Venta inexistente | `404` → "Recurso no encontrado." |
| Abono a venta anulada | `422 already_cancelled` → "No se pueden agregar pagos a transacciones canceladas o reembolsadas." |
| Reembolso de venta anulada | `422` → "La venta ya se encuentra cancelada o reembolsada." |
| Apartado + abono + edicion + borrado + reembolso | ✅ folio `V-007`: alta `apartado`, abono de `$1` (ticket `$1.00 MXN`), edicion a `$1.50` ("Pago actualizado correctamente."), borrado (pagado vuelve a `$0.00`), cancelacion con "Transaccion reembolsada en efectivo." y **stock devuelto** |

Datos que dejaron esas corridas en la base de pruebas (residuo **de las pruebas**, no de la app):

- ApontePhone: venta `V-001` (la de la prueba de cobro) y su corte cerrado. `Juanito babanas`
  conserva su saldo en `$0.00`.
- Stilos: ventas `V-005` (`reembolsado`), `V-006` (`cancelado`) y `V-007` (`reembolsado`) del
  cliente `Juanito P`; el stock de `Pantalon` quedo intacto.
- `Juanito P` quedo con **+$2.00 de saldo a favor** por el hallazgo 8 (una corrida deja `$1`). Se
  ajusta desde la web (*Clientes → ficha → ajustar saldo*); no hay ruta de ajuste en `/api/v1`.

### Corrida real del 20 sep 2026 — etapa 5 (evidencia)

Contra `https://ezyventas2.test/api/v1`, con `jean@apontephone.com` (ApontePhone · `Melchor Ocampo`),
`LIVE_SERVICE_ORDERS=true` (la salida real de la prueba, resumida):

| Paso | Resultado |
|---|---|
| Listado sin ordenes | `total=0`; filtros `status=terminado`, `search=OS-` y `sortField=promised_at` sin error |
| Orden inexistente | `404` → "Recurso no encontrado." |
| Turno de caja | Abierto por la prueba (terminal `Caja principal`, fondo `$0.00`) |
| **Alta con foto** | `OS-001` · estatus `pendiente` · total `$300.00` · venta vinculada `OS-V-001` · `evidencias=1` · comision `$60.00` (20 % de `$300`) |
| Detalle | `items=1`, `saldo=$300.00`, `actividades=1`, `campos=0` (la sucursal no tiene campos personalizados) |
| Estatus | \"Estatus de la orden actualizado correctamente.\" → `en_progreso` |
| Estatus repetido | `422` → **`errors.status[0]` = "El estatus ya es el seleccionado."** |
| Estatus invalido | `422` → **`errors.status[0]` = "El estatus seleccionado no es válido."** |
| Diagnóstico + foto | `cierre=1` y el texto guardado; una segunda llamada **sin** el campo conservo el diagnostico |
| Anticipo `$10` | `pagado=$10.00`, `saldo=$290.00`, ticket `abonado=$10.00 MXN` (sin telefono: la orden no tiene cliente) |
| Edición | Equipo, tecnico y comision fija `$50.00` actualizados; la evidencia inicial se borro (`evidencias iniciales=0`) |
| `ensure-transaction` | Devuelve la **misma** venta (`22`), sin duplicar |
| Borrado | `204` sin cuerpo y despues `GET` → `404` |
| Corte de la sesión de prueba | `cerrada`, esperado `$0.00`, diferencia `$0.00` (la orden y su venta ya no existen) |

### Corrida real del 20 sep 2026 — etapa 6 (evidencia)

Contra `https://ezyventas2.test/api/v1` con `jean@apontephone.com` (propietario) y `daniel@apontephone.com`
(empleado limitado). Solo lectura: los endpoints de impresión no modifican datos.

| Prueba | Resultado |
|---|---|
| `GET /print/templates` | 7 plantillas de la suscripción: `#3`, `#7` `ticket_venta`/`general`; `#1`, `#5` `ticket_venta`/`service_order`; `#4` `etiqueta`/`product`; `#2`, `#6` `etiqueta`/`service_order` |
| Selección de la app | Para una venta: `#3, #7` (conjunto `transaction`+`general`); para una orden: `#1, #5` (contexto `service_order`) |
| `POST /print/bluetooth-payload` (venta 21, plantilla 3) | `531` bytes, inicio `[27, 64, 27, 97]` (`ESC @`, `ESC a` centrado) — mismos comandos que envía el teléfono |
| `POST /print/bluetooth-payload` (orden 3, plantilla 3) | `535` bytes, inicio `[27, 64, 27, 97]` |
| `POST /print/ticket-html` | Venta: `1853` caracteres; orden: `1849` caracteres |
| `POST /print/whatsapp-ticket` (venta 21) | `ticket.kind=sale`, `customer_phone=null` → mensaje de `17` líneas que empieza con `» *TICKET DE VENTA* «` |
| `POST /print/whatsapp-ticket` (`service_order` 3) | `200` con `ticket: null` (hallazgo 16); la app usa la venta vinculada (`23`) → `kind=sale` |
| `POST /print/payload` (producto 6, plantilla 4) | `1` operación `EscribirTexto` con el TSPL completo (`SIZE 47 mm,28 mm … PRINT 1,1`), `noSoportadas=false` |
| Empleado limitado (`daniel@apontephone.com`) | También lista plantillas y obtiene ESC/POS, HTML, TSPL y WhatsApp: el endpoint exige `pos.access` **o** `transactions.access` **o** `services.orders.access` |

### Cuenta: sucursal, perfil, suscripción, soporte y notificaciones (etapa 7)

`features/account/` implementa el menú de usuario del topbar web en la pestaña **Cuenta**
(contrato §11b y documento maestro §9b), con las mismas opciones que ve el usuario según lo que
el servidor autoriza:

| Opción | Endpoints | Regla de visibilidad |
|---|---|---|
| Mi perfil | `GET /profile`, `PUT /profile`, `DELETE /profile/photo`, `PUT /profile/password`, `POST /profile/logout-other-devices` | siempre (sesión válida) |
| Mi suscripción | `GET /subscription`, `PUT /subscription`, `POST /subscription/documents`, `POST /subscription/payments/{id}/request-invoice` | solo `is_subscription_owner` (los empleados reciben `403`) |
| Notificaciones | `GET /notifications` | campana con `transactions.access`; la pantalla se abre desde la cabecera y desde Cuenta |
| Centro de soporte | `GET /support` | siempre |
| Sucursal activa | `PUT /branch/switch/{id}` | botón y pantalla solo con `system.branches.switch` y más de una sucursal |
| Cerrar sesión | `POST /auth/logout` | siempre, con confirmación |

- **Cambio de sucursal**: `PUT /branch/switch/{id}` devuelve el contexto completo ya recalculado
  (`context`), así que la app lo aplica con `AuthController.applyContext`, **invalida la caché de la
  sucursal anterior** (catálogo, categorías, servicios, detalle de producto, buscador de productos,
  clientes, ventas, órdenes, caja, corte, cuentas bancarias y carrito), refresca `GET /auth/me`, vuelve a
  pedir los contadores de notificaciones y regresa a la pestaña **Caja** (el turno anterior era de la otra
  sucursal). Confirmación previa: «¿Cambiar a «Guacamayas.Comercial»?».
- **Perfil**: foto con cámara/galería comprimida a **≤ 1 MB** (`AppConfig.maxProfilePhotoKb`) y enviada
  como `multipart`; sin foto el cuerpo va en JSON. Al cambiar el correo el servidor responde
  `email_verification_sent: true` y la app avisa («Te enviamos un código de verificación a tu nuevo
  correo», el `message` del servidor) y refresca el contexto para volver a mostrar «Correo sin verificar».
- **Notificaciones**: los cinco contadores que devuelve el servidor, con el total como badge. La pantalla
  pinta las cuatro categorías y las abre en el listado que **sí** existe en la app (Ventas, con el filtro
  `por_entregar` en «Entregas próximas»); «Novedades» y «Pedidos pendientes» se explican porque su
  gestión es de la web. El último valor se guarda en el almacenamiento seguro (`LocalCache`) y se muestra
  marcado cuando no hay conexión (§9b.5).
- **Suscripción**: estado con la etiqueta del servidor y color por `is_expired` / `days_left` +
  `warning` (banner también en la parte alta de la pestaña Cuenta), datos generales editables
  (`PUT /subscription`), plan con módulos y límites con su consumo, uso, historial de versiones con su
  pago y **«Renovar o mejorar plan»** que abre `https://<host>/subscription/manage` en el navegador
  externo (`url_launcher`), sin reimplementar el checkout de Mercado Pago.
- **Soporte**: todo el contenido viene de `GET /support` (mensaje, horario, canales y temas). Los canales
  se abren con el manejador del sistema (`mailto:`, `wa.me`) y el Centro de ayuda en el navegador
  externo. Cambiar `config/support.php` en el servidor no requiere publicar una app nueva.
- **Caché local mínima** (`lib/core/storage/local_cache.dart`): solo los contadores de notificaciones,
  para la regla «sin conexión se muestra el último valor cacheado». No guarda datos de negocio (folios,
  saldos y stock siempre vienen del servidor) y se limpia al cerrar sesión.

### Corrida real del 20 sep 2026 — etapa 7 (evidencia)

Contra `https://ezyventas2.test/api/v1` con `jean@apontephone.com` (propietario de ApontePhone) y
`daniel@apontephone.com` (empleado, **sin** `system.branches.switch` y **sin** ser propietario).

| Prueba | Resultado |
|---|---|
| `GET /notifications` (propietario y empleado) | `{expiring_debts: 0, upcoming_deliveries: 0, unread_updates: 0, pending_orders: 0, total: 0}` — el total que suma el servidor coincide con los cuatro contadores |
| `GET /support` | Título «Centro de soporte», 2 horarios, 2 canales (`mailto:notificaciones@ezyventas.com`, `https://wa.me/5213321705650`), 4 temas y `help_center_url=https://ezyventas2.test/centro-ayuda` |
| `GET /profile` | `id=2`, `jean@apontephone.com`, `email_verified_at` presente, `phone=7531107389`, `has_photo=false` con `profile_photo_url` de **ui-avatars** (hallazgo 22) |
| `PUT /profile` (mismos datos, JSON) | `200` → «Tus datos se guardaron.» · `email_verification_sent=false` |
| `DELETE /profile/photo` | `200` → «Foto eliminada.» (la cuenta no tenía foto) |
| `PUT /profile/password` (actual incorrecta) | `422` → `code=invalid_current_password` · «La contraseña actual no es correcta.» |
| `POST /profile/logout-other-devices` (contraseña incorrecta) | `422` → `code=invalid_current_password` · mismo mensaje (no se cerró ninguna sesión real) |
| `POST /subscription/documents` (archivo `.txt`) | `422` → «El documento debe ser un PDF o una imagen.» con `errors.fiscal_document[0]` |
| `POST /subscription/payments/999999/request-invoice` | `404` → «Recurso no encontrado.» |
| `PUT /subscription` (mismos datos) | `200` → «Los datos de la suscripción se guardaron.» |
| `GET /subscription` (propietario) | `ApontePhone`, `status=activo`, `status_data.label=Activa`, «Vence el 30 oct 2026 (quedan 40 días)», 9 módulos, 6 límites, 12 versiones en el historial; última `v12` con `total="439.00"` (texto) y `payment.status=approved` |
| `GET /subscription` (empleado `daniel`) | `403` → «Tu usuario no tiene permiso para esta acción.» (la app oculta la opción) |
| `PUT /branch/switch/3` y vuelta a `2` | «Cambiado a la sucursal: Guacamayas.Comercial» con `available_branches` marcando la nueva como `is_current`, `user.branch_id=3` y su terminal (`Caja principal`, `id 3`); la vuelta deja `Melchor Ocampo (id 2)` como activa |

### Corrida real del 20 sep 2026 — etapa 8 (evidencia en teléfono físico)

`integration_test/qa_device_test.dart` corrió **en el teléfono** (Redmi 2201116TG · MIUI/HyperOS V816 ·
Android 13 · `1080×2356`, dpr 2.75) contra la API real, entrando por el túnel USB de §4.1:

```bash
flutter test integration_test/qa_device_test.dart -d EE95QSVKORE6WCL7 \
  --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 \
  --dart-define=API_HOST_HEADER=ezyventas2.test \
  --dart-define=LIVE_API_EMAIL=jean@apontephone.com \
  --dart-define=LIVE_EMPLOYEE_EMAIL=daniel@apontephone.com
# 00:14 +2: All tests passed!
```

| Escenario | Qué comprueba en el dispositivo real | Resultado |
|---|---|---|
| Propietario (`jean@apontephone.com`) | Login real contra la API, las cinco pestañas del cascarón, el catálogo real de la sucursal (`ProductCard`) y la pestaña Cuenta | Pasa: aparecen **Vender, Órdenes, Caja, Ventas, Cuenta**; Vender lista productos sin `RenderFlex overflowed`; en Cuenta ve `SUCURSAL ACTIVA` → «Melchor Ocampo», «Tu negocio tiene 2 sucursales», «Cambiar de sucursal» y «Mi suscripción»; «Cerrar sesión» (con su diálogo) vuelve al login |
| Empleado (`daniel@apontephone.com`) | Mismas pestañas permitidas y lo que **no** le toca | Pasa: las cinco pestañas siguen ahí, pero **sin** «Mi suscripción» ni «Cambiar de sucursal»; su tarjeta de sucursal muestra «Tu usuario no puede cambiar de sucursal.» |
| Peticiones reales observadas en la corrida | Que la app habla con la API por el túnel | `POST /auth/login`, `GET /catalog/categories?type=product`, `GET /catalog/products?page=1&per_page=20`, `GET /notifications` y (solo el propietario) `GET /subscription`, todas por `https://127.0.0.1:8443/api/v1` |

Nota de la prueba (no es un fallo de la app): el ancla de «ya cargó la pestaña Cuenta» se busca como
`SUCURSAL ACTIVA`, no como `Sucursal activa`, porque `SectionCard` pinta los títulos en micro-mayúsculas
(`title!.toUpperCase()`). Comparar contra el texto en *sentence case* falla aunque la pantalla esté
perfecta.

### Discrepancias y hallazgos (etapa 7)

22. **`profile_photo_url` trae un avatar generado aunque el usuario no tenga foto.** La cuenta de prueba
    responde `has_photo: false` y aun así `profile_photo_url: "https://ui-avatars.com/api/?name=J+A&…"`
    (accesor de Jetstream `HasProfilePhoto`). El contrato §11b.4 lo describe como «URL de la foto», así que
    la app decide con **`has_photo`** y `UserProfile.realPhotoUrl` devuelve `null` cuando es `false`; el
    avatar generado no se pinta (la app ya dibuja iniciales con `UserAvatar`, respetando la paleta Tesla).
23. **El estado de la suscripción llega en masculino.** El contrato §11b.5 documenta `activa` / `expirada` /
    `suspendida` y las reglas de color hablan de esos textos, pero el enum real
    (`App\Enums\SubscriptionStatus`) usa `activo` / `expirado` / `suspendido`; la respuesta real es
    `"status": "activo"`. La app modela los valores reales (`SubscriptionStatus`) y **no** usa ese texto
    para la etiqueta visible: pinta `status_data.label` («Activa», «Por vencer», «Expirada») y colorea con
    `is_expired` + `days_left`/`warning`, que es lo que tampoco depende de traducciones.
24. **El historial de la suscripción no incluye el `id` del pago, así que la app no puede pedir la
    factura.** `history[].payment` trae `folio`, `status`, `paid_at` y `can_request_invoice`, pero **no**
    `id`, y `POST /subscription/payments/{paymentId}/request-invoice` exige ese id. Evidencia real:
    `[live] última versión: v12 … puedeFactura=true idPago=null`. La app implementa el método completo
    (`AccountRepository.requestInvoice`) —probado con `404` de un id inexistente—, modela `id` de forma
    tolerante y **solo** muestra «Solicitar factura» cuando el servidor lo incluya; mientras, el historial
    explica que la factura se solicita desde la web. **Hueco del backend**, no de la app.
25. **El historial no expone los pagos `pending` / `rejected` con id tampoco**, solo
    `pending_payment` / `last_rejected_payment` (que sí traen `id`, pero no son aprobados y el servidor
    responde `403 payment_not_approved`). Con el contrato actual no hay ningún camino en la app móvil para
    solicitar una factura de un pago aprobado.
26. **El `403` de la suscripción usa el mensaje genérico de permisos.** `SubscriptionRequest::authorize`
    devuelve `false` para un empleado, así que el cuerpo es «Tu usuario no tiene permiso para esta
    acción.» y **no** el `owner_only` que documenta el catálogo de códigos (§12 del contrato). La app
    muestra el `message` tal cual y oculta la opción del menú cuando `is_subscription_owner = false`.
27. **El stack aprobado no incluye un selector de archivos**, así que la constancia de situación fiscal se
    sube como **imagen** (cámara/galería, ≤ 2 MB) y no como PDF (el servidor sí acepta
    `pdf,jpg,jpeg,png,webp`). La pantalla lo explica y el envío del PDF queda para la web (pendiente 8).
28. **`GET /notifications` no distingue por módulo contratado** (los cuatro contadores llegan siempre;
    `pending_orders` solo se calcula si la tienda en línea está activa). La app pinta los cuatro y explica
    en «Novedades» y «Pedidos pendientes» que su gestión es de la web, en vez de inventar pantallas.
29. **`expiring_debts` agrupa dos estatus** (`apartado` y `pendiente`) y el listado de ventas solo acepta
    **un** `status` por llamada (contrato §8), así que «Deudas por vencer» abre el historial sin filtro
    (con el texto de la categoría explicando qué cuenta). «Entregas próximas» sí abre filtrado por
    `por_entregar`, que es exactamente lo que cuenta el servidor.
30. **`PUT /profile` funciona igual con JSON que con `multipart`.** El contrato exige
    `multipart/form-data`; la API real acepta JSON cuando no hay foto (verificado: `200` con el mismo
    `message`). La app envía `multipart` **solo** cuando hay foto y JSON cuando no, para no convertir a
    texto los campos (mismo criterio que las órdenes de servicio).
31. **`PUT /branch/switch/{id}` cambia la sucursal del usuario para todos sus dispositivos** (escribe
    `users.branch_id`), no solo para el teléfono que lo pide. La app lo advierte en la confirmación
    («Verás la información de esa sucursal en este dispositivo, igual que en la web») y por eso la prueba
    real deja la cuenta **como estaba** (ida y vuelta).

### Errores
`ApiException` conserva `message`, `errors` (por campo) y `code`. La UI muestra **siempre** el
`message` del servidor; `code` solo decide el flujo (`cash_register_in_use`, `session_required`,
...). Un `401` limpia token y contexto y regresa al login con el aviso aprobado
("Tu sesion expiro. Inicia sesion de nuevo.").

### Tema
"Tesla UI" en `lib/core/theme/`: modo oscuro por defecto (`#232323` paneles, `#1A1A1A` fondo e
inputs, bordes de 1 px sin sombras, radios 24/16/pill, micro-etiquetas de 10 px en mayusculas).
La tipografia es **Figtree** (fuente variable empaquetada en `assets/fonts`), asi Flutter aplica
el eje `wght` con `FontWeight`. El cambio a claro se guarda en el almacenamiento seguro
(`theme_mode`).

### Impresora termica (etapa 6)
`lib/core/printing/`:
- `bluetooth_printer_service.dart`: conexión GATT con `flutter_blue_plus`, búsqueda de la
  característica escribible (primero los servicios conocidos `0000af30…`, `49535343…`,
  `00001101…`, y `writeWithoutResponse` antes de `write`), envío en **bloques de 20 bytes con 25 ms
  de pausa** y aviso `Se perdió la conexión con la impresora.` si el enlace cae a media impresión.
- `printer_preferences.dart`: guarda el identificador de la impresora y la plantilla elegida por
  tipo. Se usa `flutter_secure_storage` porque el stack aprobado **no** incluye `shared_preferences`
  y el almacén seguro ya estaba en la app (sesión y tema).
- `esc_pos_builder.dart` + `cp850.dart`: encoder ESC/POS **local** con la página de códigos **CP850**
  (la misma que usa `PrintEncoderService` en el servidor). Solo se usa para el **corte de caja**, el
  único documento que la API no puede codificar (contrato §6.3); queda aislado para reutilizarlo en
  la fase offline.

> **Licencia de `flutter_blue_plus` (decisión de negocio).** La serie 2.x del paquete exige declarar
> una licencia y, para empresas con fines de lucro, **comprar una licencia comercial**; su API además
> obliga `device.connect(license: ...)`. Como EzyVentas es un producto comercial, el `pubspec.yaml`
> fija la rama **1.35.x** (BSD-3, sin costo) —la API que se usa aquí es idéntica—. Si el negocio
> compra la licencia 2.x, basta con subir la dependencia y añadir el argumento `license` en
> `BluetoothPrinterService.connect`.


### Discrepancias y hallazgos (etapas 3 y 4)
1. `POST /cash-register-sessions`: `01-contrato-api-v1.md` §6.1 documenta `user_id` como
   obligatorio, pero el `OpenCashRegisterSessionRequest` real **no** lo acepta ni lo exige (el
   servidor usa el usuario del token). La app no lo envia.
2. Ejemplo del request de `POST /pos/checkout` (contrato §7): con `unit_price: 135` y
   `quantity: 2` el `subtotal` correcto es `270` **solo si** `unit_price` es el precio de lista; su
   ejemplo envia `discount: 15` con `subtotal: 270` y `total: 270`, que no cumple la regla
   `total = subtotal - total_discount` = 240. La app implementa la regla escrita (§7.2) y las
   formulas reales del web (`ShoppingCart.vue`): `subtotal = Σ(precio de lista x cantidad)`,
   `total = subtotal - Σ(descuento por unidad x cantidad)`.
3. `POST /pos/store-order`: el POS web calcula `subtotal` con `item.price` (precio con
   descuento) mientras el flujo de venta usa `original_price`. La app usa una sola regla (la de
   §7.2) para las tres operaciones para que el mismo carrito cobre igual en los tres botones.
4. `POST /transactions/{id}/cancel` **no** acepta un motivo escrito: el contrato §8 solo documenta
   `action`, `refund_method`, `bank_account_id` y `client_uuid` (`CancelTransactionRequest` real).
   El plan de trabajo pedia "cancelar/reembolsar con motivo", asi que la app muestra una
   confirmacion explicita (que ocurre con el dinero, cuanto se paga, aviso de caja/cliente) pero
   **no** envia ningun campo nuevo al servidor; el texto que se muestra al final es su `message`.
5. `POST /transactions/{id}/payments` **rechaza** el sobrepago con `422` "El monto total del pago
   excede el saldo pendiente." (`TransactionPaymentService::applyPaymentToTransaction`), mientras
   `/pos/checkout` recorta el pago al total. El contrato §8 no lo menciona: la app valida el monto
   antes de enviar y usa el mismo texto del servidor.
6. `GET /transactions/{id}` no expone `customer_id` en la raiz (solo `customer: {id, name, balance,
   credit_limit}` o `null`), pero la web (`TransactionCancellationModal.vue`) decide si el reembolso
   puede ir a saldo con `transaction.customer_id`. La app usa `customer != null` (y `customer.id`).
7. `PUT /transactions/{id}/payments/{paymentId}` acepta los 5 metodos de `PaymentMethod` (incluye
   `saldo` e `intercambio`), pero el modal web (`EditPaymentModal.vue`) solo ofrece 4 (sin
   `intercambio`). La app ofrece los 4 de la web mas el metodo actual cuando es `intercambio`, para
   no perderlo al guardar.
8. **Hallazgo de conciliacion (backend, probado contra la API real).** `DELETE
   /transactions/{id}/payments/{paymentId}` no revierte el `payDebt` que el abono escribio en
   `customers.balance`: `TransactionPaymentEditService::delete()` revierte la cuenta bancaria, el
   saldo **usado como pago** (`saldo`) y el movimiento de caja del turno, y el `PUT` solo concilia
   el banco; ninguno ajusta la deuda del cliente. Evidencia (`LIVE_SALES_LAYAWAY=true`): apartado de
   $140 del cliente `Juanito P` ($0.00 inicial) → abono de $1 → edicion a $1.50 → borrado del pago →
   abono de $2 → cancelacion con reembolso en efectivo. Resultado: la venta queda `reembolsado`, el
   stock se devuelve, pero el cliente termina con **+$1.00 de saldo a favor** (exactamente el
   importe del pago borrado) porque al cancelar el servidor perdona `total - total_paid` sin contar
   ese pago. La prueba lo deja impreso y caracteriza el desfase; **cada corrida deja ese $1** en el
   cliente de prueba (se ajusta desde la web: *Clientes → ficha → ajustar saldo*).
9. `remaining_due` **no** se pone a 0 al cancelar/reembolsar: es `max(0, total - total_paid)`, asi
   que una venta `reembolsado` sigue reportando saldo en `GET /transactions` (visto en la prueba:
   `V-005 reembolsado ... saldo=$138.00`). La app **oculta** el saldo pendiente en ventas anuladas
   (`TransactionSummary.hasPendingBalance`); la web lo muestra tal cual.
10. `POST /pos/layaway` (y el cobro) **aplican automaticamente el saldo a favor** del cliente cuando
    la venta queda con deuda, aunque no se envie `use_balance` (visto en la primera corrida de la
    prueba: el cliente tenia $1 a favor y el servidor lo uso). El contrato §7.3 lo describe como una
    accion explicita del cajero; la app ya envia `use_balance` y el ticket de abono muestra lo que el
    servidor aplico de verdad.
11. `POST /service-orders` exige `create_customer` **siempre** (`required|boolean`), tambien cuando se
    elige un cliente existente; el contrato §9 lo marca como \"required boolean\" pero el ejemplo de
    `curl` **no** lo envia, y el `422` responde \"El campo create customer es obligatorio.\". La app lo
    manda en **todas** las altas (`true`/`false`; en multipart `1`/`0` porque Laravel no acepta la
    cadena `"true"` en un campo de formulario). Detectado por la prueba real contra la API.
12. El `message` del cambio de estatus es \"Estatus de la orden actualizado correctamente.\", no el
    \"Estatus actualizado a “Terminado”.\" que ilustra el contrato §9. La app muestra el `message` del
    servidor tal cual (nunca compone el texto) y, para el `422`, prioriza `errors.status[0]`.
13. `DeleteServiceOrderAction` borra la orden **y su venta vinculada**, pero **no** revierte el stock
    de las refacciones ni la deuda que genero en el cliente (`addDebt` en el alta). La app avisa que
    la accion no se puede deshacer; el desfase de stock/saldo es del backend (misma logica que la
    web). Por eso la prueba de humo usa un **servicio** como concepto y una orden **sin cliente**, y
    solo consume stock real con `LIVE_SERVICE_ORDERS_STOCK=true`.
14. `custom_field_definitions` solo viaja dentro del detalle de una orden
    (`GET /service-orders/{id}`): no hay endpoint que liste las definiciones antes de crear una. La
    app puede capturar y editar campos personalizados en la **edicion** (donde ya conoce las
    definiciones), pero en el **alta** no tiene como dibujarlos; no se inventan campos.
15. `promised_at` es una fecha con hora en el backend (`America/Mexico_City`): la app la envia como
    `YYYY-MM-DD` (medianoche local) para que la fecha mostrada sea la elegida por el usuario y no se
    corra un dia por la zona horaria.

### Discrepancias y hallazgos (etapa 6)

16. **`POST /print/whatsapp-ticket` no arma el ticket de una orden de servicio.** `PrintController::whatsappTicket`
    resuelve el origen con `PrintDataSourceResolver` y, si **no** es una `Transaction`, responde `200`
    con `ticket: null` (`customer_phone: null`). Evidencia real (`LIVE_SERVICE_ORDERS=true` + `LIVE_PRINTING=true`):
    `[live] WhatsApp service_order=3 ticket=null telefono=sin telefono`. La app **sí** imprime la orden
    (`service_order` funciona en `/print/bluetooth-payload` y `/print/ticket-html`) y, para WhatsApp,
    ofrece el ticket de la **venta vinculada** de la orden cuando existe (`POST /print/whatsapp-ticket`
    con `transaction`/`order` + el id de esa venta); si la orden no tiene venta, el botón se oculta y
    se explica que se genera con “Cobrar ahora”. Además, el `kind` del ticket lo decide el servidor
    según la transacción (`isOrder()`), no el `data_source_type`: la venta vinculada devuelve `kind=sale`.
17. **`GET /print/templates` filtra por un solo `context`, pero la web usa conjuntos.** Los controladores
    web piden las plantillas por `type` y **varios** contextos: `PointOfSaleController` → `pos` + `general`,
    `TransactionController` → `transaction` + `general`, `ServiceOrderController` → `service_order`,
    `ProductController` → `product` + `general`, `CustomerController` → `customer` + `general`. El endpoint
    móvil solo acepta un `context` por llamada, así que la app pide todas las plantillas del **tipo**
    (`GET /print/templates?type=…`) y aplica el conjunto de contextos en
    `PrintDocument.selectTemplates` (y `selectLabelTemplates`). Evidencia real con la suscripción de
    prueba (7 plantillas): los tickets son `general` (#3, #7) y `service_order` (#1, #5); la app
    selecciona `#3, #7` para una venta y `#1, #5` para una orden. Si se pidiera `context=pos` (como
    sugería el ejemplo del contrato) la lista llegaría **vacía** y el POS no podría imprimir.
18. **`/print/payload` (etiquetas) devuelve operaciones del plugin de escritorio**, no bytes. En la
    práctica la plantilla `etiqueta` produce **una sola** operación `EscribirTexto` cuyo argumento es el
    comando **TSPL completo** (`SIZE`, `GAP`, `CLS`, `TEXT`, `BARCODE`, `QRCODE`, `PRINT 1,1`). La app
    envía ese texto tal cual (UTF-8) a la impresora de etiquetas; las operaciones que no puede resolver
    (p. ej. `DescargarImagenDeInternetEImprimir`) se reportan en `LabelPayload.hasUnsupportedOperations`
    y se avisan, en lugar de imprimir una etiqueta incompleta en silencio.
19. En la etiqueta real de la suscripción de prueba el `BARCODE` viaja con el valor **vacío**
    (`BARCODE 23.97,89.43,"128",30,1,0,2,2,""`): es la plantilla configurada, no un campo que la app
    invente. Se reimprime tal cual lo que devuelve el servidor (revisar la plantilla en la web si se
    quiere un código con contenido).
20. **El corte de caja no tiene endpoint de impresión** (`cash_register_session` no es un
    `data_source_type` válido, contrato §6.3): el ticket se arma en el teléfono con el encoder ESC/POS
    local y el texto de WhatsApp se compone con el mismo formato de los demás tickets. Si más adelante
    se quiere plantilla del negocio para el corte, hay que añadir ese tipo en el backend.
21. El respaldo HTML (`/print/ticket-html`) se muestra para copiarlo porque el stack aprobado no incluye
    un paquete de compartir/PDF (`share_plus`, `printing`): generar el PDF o abrir la hoja de compartir
    del sistema queda como pendiente si el negocio lo necesita.

---

## 4. Notas del entorno de desarrollo (Windows)

Si la ruta del SDK de Flutter tiene **espacios**, el constructor de *native assets* de Flutter
falla al compilar el hook del paquete `objective_c` (dependencia transitiva de
`path_provider_foundation`, solo Apple). El error es literalmente la ruta cortada en el primer
espacio:

```
"C:\Users\windows" no se reconoce como un comando interno o externo,
Building native assets for package:objective_c failed.
Compilation of hook returned with exit code: 1.
```

En este equipo el `PATH` apunta a `C:\Users\windows 11\Desktop\flutter\bin` (con espacios) y existe
además `C:\flutter` con **el mismo Flutter 3.47.4** en una ruta sin espacios. Verificado en la
etapa 8: con el SDK de `Desktop\flutter` el build del APK muere en los *native assets*; con
`C:\flutter` el mismo commit compila limpio (`√ Built build\app\outputs\flutter-apk\app-debug.apk`).

Arreglo aplicado (no depende de la caché de pub, que puede seguir teniendo espacios):

| Pieza | Qué se hizo |
|---|---|
| VS Code (F5) | `.vscode/settings.json` → `"dart.flutterSdkPath": "C:\\flutter"` |
| Terminal | usar `C:\flutter\bin\flutter`, o poner `C:\flutter\bin` antes en el `PATH` |

`flutter doctor` sigue avisando que `flutter`/`dart` del `PATH` no viven en el checkout activo:
es justo el aviso que hay que atender.

### 4.1 Probar en un teléfono Android físico (túnel USB)

El servidor local publica la API en `https://ezyventas2.test/api/v1`, un dominio que **solo
resuelve en este equipo** (`hosts`) y cuyo Herd escucha **únicamente en `127.0.0.1`**. Desde el
Wi-Fi el teléfono no lo alcanza (`ping: unknown host ezyventas2.test`), así que la app se conecta
por un túnel inverso de `adb`:

```powershell
# 1) túnel: el 127.0.0.1:8443 del TELÉFONO llega al 127.0.0.1:443 del equipo
powershell -ExecutionPolicy Bypass -File tool\android_tunnel.ps1

# 2) correr la app con la URL del túnel y el Host del vhost de Herd
#    (o simplemente F5: .vscode/launch.json ya lo hace y crea el túnel solo)
flutter run -d <serial> `
  --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 `
  --dart-define=API_HOST_HEADER=ezyventas2.test
```

- Herd elige el sitio por el header `Host`, así que el túnel necesita `API_HOST_HEADER`
  (`AppConfig.apiHostHeader`); sin él la respuesta es el `404 Site not found` de Herd. Comprobado
  con `curl`, con `dart:io` y con **dio** (el cliente de la app): con `Host: ezyventas2.test` la
  API responde `401 {"message":"No autenticado."}` y sin él devuelve el HTML de Herd.
- El certificado autofirmado no estorba: `ApiClient` lo acepta **solo en debug**
  (`badCertificateCallback`, `ALLOW_CERTIFICATE`/`ALLOW_BAD_CERTIFICATE`).
- `.vscode/launch.json` trae tres configuraciones: **Android por USB (Herd local)** —la de F5,
  con `preLaunchTask` que crea el túnel—, la misma en modo *profile* (más fluida en el teléfono) y
  una sin túnel para cuando el teléfono pueda resolver el dominio real.
- Limitación del túnel: las imágenes que el servidor publica en su propio host
  (`https://ezyventas2.test/storage/...`) no se pueden cargar en el teléfono porque
  `Image.network` no envía el header `Host`; la app cae en su marcador (`errorBuilder`) sin
  romperse. No afecta a producción, donde `API_BASE_URL` es un dominio público con certificado
  válido.

### 4.2 Instalar la app en un teléfono Xiaomi/Redmi (MIUI/HyperOS)

`adb install` — y por tanto `flutter run` y `flutter test -d` — lo bloquea MIUI aunque «Depuración USB»
esté activa. Hacen falta **las dos** condiciones:

1. **Pantalla encendida y desbloqueada.** Con el teléfono en `mWakefulness=Dozing` MIUI no puede mostrar
   su diálogo de confirmación y cancela la instalación en el acto.
2. **Ajustes → Ajustes adicionales → Opciones de desarrollador → «Instalar vía USB» activado.** En
   HyperOS suele exigir la cuenta Mi iniciada; si no se puede activar, usa el camino alternativo de abajo.

Cuando falta cualquiera de las dos, el error es siempre el mismo:

```text
adb: failed to install build\app\outputs\flutter-apk\app-debug.apk:
Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]
```

Comprobaciones por `adb` (sin tocar el teléfono) que evitan perder tiempo:

| Comando | Para qué sirve |
|---|---|
| `adb shell getprop ro.product.brand` · `adb shell getprop ro.product.model` | identificar el modelo (`Redmi 2201116TG`, MIUI/HyperOS `V816`) |
| `adb shell dumpsys power \| findstr mWakefulness` | debe decir `Awake` antes de instalar (`Dozing` = pantalla apagada → cancelará) |
| `adb shell settings get secure install_non_market_apps` | `1` significa «orígenes desconocidos»; **no** cubre la restricción de USB |
| `adb shell id` · `adb shell getprop ro.debuggable` | `uid=2000(shell)` y `0`: no hay `adb root` ni `settings put` (falla con `WRITE_SECURE_SETTINGS`), así que la restricción **no** se puede saltar desde el equipo |

Camino alternativo si «Instalar vía USB» no se deja activar: publicar el APK y abrirlo desde el propio
teléfono. Esto **no** pasa por la restricción de USB, solo por «instalar apps de orígenes desconocidos»:

```powershell
adb push build\app\outputs\flutter-apk\app-debug.apk /sdcard/Download/ezyventas-debug.apk
# y en el teléfono: Archivos → Downloads → ezyventas-debug.apk → Instalar
```

> `flutter test integration_test/... -d <serial>` deja instalado un APK cuyo `main` es **la prueba**: si
> abres la app después, se vuelve a correr la prueba. Para dejar el teléfono listo para QA manual
> reinstala el build normal (`flutter build apk --debug --dart-define=...` + `adb install -r -t`) o usa F5.

---

## 5. Estructura

```
lib/
- main.dart / app.dart
- core/
  - api/         dio, interceptores, ApiException (message/errors/code/details), endpoints, providers
  - auth/        SessionStore, PermissionsService, AppTab
  - config/      AppConfig (API_BASE_URL, timeouts, locale)
  - printing/    BluetoothPrinterService, EscPosBuilder + Cp850, PrinterPreferences (etapa 6)
  - router/      go_router + StatefulShellRoute
  - theme/       Tesla UI: colores, tipografia, tema, severidades
  - utils/       Money, AppFormatters, JsonReader, SearchDebouncer, StatusCatalog, Uuid,
                 ExternalLinks (abre enlaces del sistema)
  - storage/     LocalCache (último valor cacheado de notificaciones)
  - widgets/     FieldLabel, EzyTextField, MoneyField, EzyButton, SectionCard, ...
- features/
  - auth/        login, splash, modelos de sesion, repositorio, controlador
  - account/     pestana Cuenta y sus pantallas (etapa 7): perfil, sucursal,
                 notificaciones, soporte y suscripcion + repositorio,
                 controladores y modelos
  - cash/        turno de caja: modelos, repositorio, controlador, apertura y corte (etapa 3)
  - catalog/     catalogo, detalle de producto y alta rapida al carrito
  - customers/   clientes + buscador del cobro
  - pos/         pestana Vender: carrito, cobro, apartado y pedido (etapa 3)
  - sales/       pestana Ventas: historial con filtros, detalle, abono, anulacion y
                 edicion de pagos (etapa 4)
  - service_orders/  pestana Ordenes: listado con filtros, stepper de estatus,
                 diagnostico con evidencias, alta y edicion (multipart), anticipos
                 y borrado (etapa 5)
  - printing/    plantillas, impresion ESC/POS y TSPL, respaldo HTML, WhatsApp y
                 el corte de caja en el dispositivo (etapa 6)
  - shell/       cascaron de 5 pestanas
```

---

## 6. Pendientes y limites de esta entrega

1. **Impresora física.** El entorno de desarrollo no tiene impresora térmica Bluetooth: el recorrido
   de bytes está verificado contra la API real (`531` bytes ESC/POS de una venta, `535` de una orden
   y el TSPL completo de una etiqueta) y con pruebas unitarias del encoder, pero **falta la prueba en
   un teléfono con impresora** (emparejar la térmica de 80 mm, imprimir el ticket, el corte y el pulso
   del cajón, y cortar el enlace a media impresión para ver el aviso).
2. **Etiquetas con imágenes.** `POST /print/payload` puede devolver
   `DescargarImagenDeInternetEImprimir`; el teléfono no rasteriza imágenes para TSPL, así que la app
   avisa y solo envía el texto/códigos de la plantilla.
3. **Respaldo HTML.** Se muestra y se copia; generar el PDF o abrir la hoja de compartir del sistema
   requiere un paquete fuera del stack aprobado (`share_plus`/`printing`).
4. **Reimprimir un corte anterior.** El ticket del corte se ofrece al cerrar el turno (cuando la app
   tiene el `summary` en memoria). No hay endpoint de impresión de un corte histórico.
5. **Fase 5 (offline).** No implementada, como pide esta entrega: no hay base local, cola de
   sincronización ni encoder ESC/POS de tickets automáticos. La capa de datos (repositorios/servicios)
   y el encoder local del corte quedan aislados para añadirla sin reescribir la UI. Lo único que ya
   sobrevive sin conexión es el **último valor cacheado de los contadores de notificaciones**
   (`LocalCache`), como pide §9b.5; el resto de la caché de sucursal se limpia al cambiar de sucursal.
6. **Lista de dispositivos con sesión abierta.** «Sesiones activas» permite **cerrar** las demás sesiones
   (`POST /profile/logout-other-devices`, con contraseña), pero el contrato §11b.4 deja la **lista** de
   dispositivos (`personal_access_tokens`) para una fase posterior: la app no inventa esa lista.
7. **Contraseña y cierre de otras sesiones con datos reales.** Las pruebas verifican el camino de error
   (`422 invalid_current_password`) para no cambiar la contraseña de las cuentas de prueba; el camino
   correcto queda por validar en un entorno desechable.
8. **Constancia fiscal en PDF.** El servidor acepta `pdf`, pero el stack aprobado no trae selector de
   archivos: la app solo sube imágenes (≤ 2 MB). El PDF se sube desde la web.
9. **Solicitar factura desde el teléfono.** Bloqueado por el hueco 24 (el historial no trae el `id` del
   pago). El método del repositorio ya está listo y probado contra el `404` real.
10. **Validación en teléfono físico.** Etapa 8 cierra el hueco de «solo se probó en el equipo»:
    `flutter analyze` limpio, `flutter test` (222 pruebas) y `integration_test/qa_device_test.dart`
    corriendo **en un teléfono** (login real, pestañas, catálogo, Cuenta y cierre de sesión, con
    propietario y empleado) contra la API por el túnel USB (§4.1), con el APK compilado e instalado en el
    Redmi (§4.2). Sigue fuera de alcance lo que depende de hardware que no está en el entorno (la
    impresora térmica, punto 1) y lo que exige un entorno desechable (contraseñas reales, punto 7).
