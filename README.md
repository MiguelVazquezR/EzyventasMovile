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
flutter test        # 282 tests (9 omitidas: las live sin credenciales): dinero, errores, sesion,
                    # permisos, catalogo, caja, cobro, ventas, ordenes, impresion (las
                    # `operations` del servidor -> bytes ESC/POS/TSPL, el comprobante del corte,
                    # plantillas y su filtro por contexto, la hoja de impresion, el controlador de
                    # la impresora -permisos de Android 12+, lista de dispositivos y estados del
                    # envio- y el troceado del envio por MTU) y cuenta (sucursal, notificaciones,
                    # soporte, perfil y suscripcion), mas config (reescritura de las URLs de medios
                    # por el tunel USB, `ServerImage` y su cadena de origenes), texto plano a partir
                    # del HTML de las descripciones (`HtmlText`) y el logotipo de marca (`BrandLogo`:
                    # asset segun el tema y respaldo sin asset)
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

**Impresora térmica real (etapa 8).** El último escenario del mismo archivo conecta la térmica del
teléfono y le manda el ticket ESC/POS que arma el servidor. `LIVE_PRINTER_NAME` es el nombre **tal
como lo anuncia la impresora** (`MP210`, `BY-480BT_05AC`, …); sin ese define el escenario solo
enumera en el log lo que ve el teléfono (`IMPRESORA VISTA | … | emparejada=… | rssi=…`) y se
**omite**, para poder identificar la impresora antes de imprimir.

```bash
flutter test integration_test/qa_device_test.dart -d <serial> \
  --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 \
  --dart-define=API_HOST_HEADER=ezyventas2.test \
  --dart-define=LIVE_API_EMAIL=propietario@negocio.com \
  --dart-define=LIVE_API_PASSWORD=secreto \
  --dart-define=LIVE_PRINTER_NAME=MP210 \
  --plain-name impresora
```

> La **primera** vez que la app busca impresoras Android pide el permiso de «dispositivos cercanos»
> (lo dispara el escaneo): hay que **aceptarlo en la pantalla del teléfono**. MIUI no deja concederlo
> desde el equipo (`adb shell pm grant` responde `SecurityException: … GRANT_RUNTIME_PERMISSIONS`),
> así que el diálogo se acepta a mano una vez y queda concedido para las siguientes corridas.

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
  conectar/cambiar/olvidar (botones en **azul Bluetooth**), selector de plantilla, interruptor de
  **abrir cajón**, `Imprimir ticket`/`Imprimir etiqueta` (según el documento) y `Enviar por WhatsApp`
  (**verde**). La hoja **no** ofrece respaldo HTML: el botón se quitó porque el endpoint devolvía
  error en el servidor real y la operación se hace a mano desde la web.
- **Ticket** (`POST /print/bluetooth-payload`): `commands_base64` → `Uint8List` → bloques de 20 bytes.
  Si la impresora se desconecta a media impresión se avisa y se permite reimprimir; el ticket **no**
  se marca como impreso (no hay reimpresión automática).
- **Etiquetas** (`POST /print/payload`): se envía el comando TSPL completo de la operación
  `EscribirTexto`; si la plantilla trae imágenes que el teléfono no puede rasterizar, se avisa.
- **Respaldo HTML** (`POST /print/ticket-html`): sigue en la capa de datos (lo cubren las pruebas de
  parser y el escenario live de impresión), pero la **UI ya no lo ofrece**.
- **WhatsApp** (`POST /print/whatsapp-ticket`): el ticket lo arma el servidor y la app lo convierte al
  **mismo texto que la web** (`WhatsAppMessageBuilder`, réplica de `useWhatsAppTicket.js` para
  `sale`, `abono`, `order` y `order_payment`), abre una vista previa y lanza
  `https://wa.me/{customer_phone}?text=…` (con el prefijo 52 en teléfonos de 10 dígitos); sin teléfono
  abre `https://wa.me/?text=…` para elegir el contacto.
- **Dónde se ofrece**: al cobrar (carrito), al abonar una venta o un pedido (con el ticket que devolvió
  la operación), al **cerrar caja**, y desde el detalle de venta/pedido y de orden de servicio (ahí sí,
  con etiquetas: la venta vinculada puede imprimir su etiqueta). El detalle de **producto** ya no
  ofrece `Imprimir etiqueta`.
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

### Corrida real del 20 sep 2026 — impresora térmica (etapa 8, teléfono físico)

Mismo archivo, escenario `impresora`: abre el detalle de una venta real, conecta la **térmica
Bluetooth** del teléfono y le manda el ticket ESC/POS que arma el servidor.

```bash
flutter test integration_test/qa_device_test.dart -d EE95QSVKORE6WCL7 \
  --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 \
  --dart-define=API_HOST_HEADER=ezyventas2.test \
  --dart-define=LIVE_API_EMAIL=jean@apontephone.com \
  --dart-define=LIVE_API_PASSWORD=•••••• \
  --dart-define=LIVE_PRINTER_NAME=MP210 \
  --plain-name impresora
```

| Escenario | Qué comprueba en el dispositivo real | Resultado |
|---|---|---|
| Búsqueda **sin** nombre de impresora | Que el teléfono ve lo que la app lista: emparejadas del sistema + escaneo BLE | Pasa (omitida con evidencia): **24 emparejadas** primero y después las del escaneo, entre ellas **`MP210`** (`DC:0D:51:3B:77:6E`, `rssi=-62`, `emparejada=false`, `guardada=false`) y una TV y una banda; el resto de las emparejadas son audífonos y bocinas |
| Impresión real (`LIVE_PRINTER_NAME=MP210`) | Conexión GATT, característica de escritura y envío del ticket del servidor | `POST /print/bluetooth-payload` con `{template_id: 3, data_source_type: transaction, data_source_id: 24, open_drawer: false}` → la app avisa «Ticket enviado a la impresora.» y **el ticket sale impreso** |
| Estado del adaptador en la hoja | Badge `CONECTADA`, «Impresora conectada: MP210» y el selector cerrándose solo al conectar | Pasa: la impresora queda **guardada** en el teléfono, así que la corrida siguiente reconecta con «Conectar impresora» sin volver a escanear |

### Pruebas de impresión que quedan a mano

MIUI no deja automatizar toques desde el equipo (hallazgo 34), así que estas se hacen en el teléfono:

| Prueba | Cómo |
|---|---|
| **Corte de caja** (con `GET /cash-register-sessions/{id}/receipt`; las `operations` las arma el servidor, contrato §6.3) | Caja → `Hacer corte` → completar el arqueo → `Finalizar turno`; el corte se ofrece al cerrar (imprimir o WhatsApp) y se puede **reimprimir** después desde la misma pantalla |
| **Etiqueta** con aviso del servidor | Imprimir una etiqueta de producto: si el servidor responde `unsupported_operations` o `warnings` (código de barras rellenado, imagen que no pudo resolver), la hoja lo avisa en vez de imprimir a medias |
| **Pulso del cajón** | En la hoja del ticket, activar `Abrir el cajón al imprimir` (`open_drawer` del `POST /print/bluetooth-payload`): con el cajón conectado a la impresora, `Imprimir ticket` debe abrirlo |
| **Corte del enlace a media impresión** | Apagar la impresora mientras sale un ticket: la app avisa «Se perdió la conexión con la impresora.» y deja reimprimir (no reintenta sola) |

La **etiqueta TSPL** no se puede probar con la impresora del equipo (es térmica de recibos): ese
recorrido sigue verificado con las pruebas del encoder y con el `POST /print/payload` real.

### Corrida real del 21 sep 2026 — contrato nuevo (A1-A6, B1-B6, D1-D5) y dispositivos

La API cerró todo `PENDIENTES_BACKEND.md` (P0/P1/P2) y el contrato quedó con el changelog punto por
punto (§14). La app se adaptó a lo nuevo —**sin rodeos**: el corte ya no se arma en el teléfono, las
etiquetas se mandan tal cual y se avisan los `warnings`, y las pantallas usan los campos nuevos— y se
volvió a correr **todo** contra la API real (`https://ezyventas2.test/api/v1`, cuentas de §2):

```bash
# Caja y cobro (se une al turno abierto, vende y resume el corte)          → 1/1 en verde
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=••• \
  --dart-define=LIVE_POS=true --plain-name caja

# Ventas + apartado completo (historial, filtros, pagos, cancelación)      → 1/1 en verde
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=••• \
  --dart-define=LIVE_SALES=true --dart-define=LIVE_SALES_LAYAWAY=true --plain-name ventas

# Impresión: plantillas, ESC/POS, TSPL, HTML, WhatsApp y el corte          → 1/1 en verde
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=••• \
  --dart-define=LIVE_PRINTING=true --plain-name impresi

# Órdenes de servicio (alta con foto, estatus, diagnóstico, anticipo…)     → 1/1 en verde
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=••• \
  --dart-define=LIVE_SERVICE_ORDERS=true --plain-name diagn

# Cuenta (notificaciones + `modules`), suscripción y sucursal              → 1/1 cada una
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=••• \
  --dart-define=LIVE_ACCOUNT=true --plain-name notificaciones
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=••• \
  --dart-define=LIVE_ACCOUNT=true --plain-name plan

# Super admin y empleado (pestañas, permisos y el 403 real)               → 1/1 cada una
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=ezyventas@gmail.com --plain-name login
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=daniel@apontephone.com \
  --dart-define=LIVE_EXPECT_OWNER=false --dart-define=LIVE_EXPECT_FORBIDDEN_PATH=/subscription --plain-name login
flutter test test/live/api_smoke_test.dart --dart-define=LIVE_API_EMAIL=daniel@apontephone.com \
  --dart-define=LIVE_EXPECT_OWNER=false --dart-define=LIVE_ACCOUNT=true --plain-name plan
```

| Punto | Evidencia real de la corrida |
|---|---|
| **A1/A3** saldo del cliente y `use_balance` | `[live] apartado V-005 estatus=apartado total=$70.00 saldo=$70.00` → `[live] apartado con pagos iniciales=0.0` → `[live] pago borrado pagado=$0.00 saldo=$70.00` → `[live] saldo del cliente tras la cadena completa: $0.00 (antes de la cadena $0.00)` |
| **A2** ventas anuladas sin saldo | `[live] V-004 reembolsado Juanito babanas total=$70.00 saldo=$0.00` |
| **A4** sobrepago (regla única) | `[live] venta folio=V-003 … total=$70.00 pagado=$70.00 saldo=$0.00 cambio=$0.00` (la app ya calculaba el cambio solo con efectivo) |
| **A5** una fórmula de totales | La venta y el apartado de una línea de $70 dan `total=$70.00` con `saldo`/`pagado` coherentes en `/pos/checkout`, `/pos/layaway` y `GET /transactions` |
| **B1/B5** impresión del servidor | `[live] ESC/POS venta=27 plantilla=3 bytes=8739 papel=58mm` (con el logo rasterizado) y `[live] corte del turno abierto #16 plantilla=Corte de caja (incorporada) operaciones=1 bytes=491 papel=80mm avisos=[]` |
| **B2/B6** etiqueta TSPL | `[live] TSPL plantilla=4 producto=6 operaciones=1 noResueltas=[] avisos=[Barcode: la plantilla no resolvió un valor, se usó «P-6».]` y el comando real `BARCODE 23.976377952756,89.43188976378,"128",30,1,0,2,2,"P-6"` |
| **B3** WhatsApp | `[live] WhatsApp kind=sale telefono=3312650047 lineas=19` y `[live] WhatsApp de un cliente: 422 no_whatsapp_ticket Este documento no tiene ticket de WhatsApp.` |
| **B4** plantillas por tipo | `[live] plantillas=7 … tickets=4 etiquetas=3` y `[live] la app selecciona para una venta: #3, #7` |
| **D1** factura de la suscripción | `[live] última versión: v12 2026-06-19 11:36:54.000 total=$439.00 estatus=Aprobado puedeFactura=true idPago=37` |
| **D3** módulos contratados | `[live] notificaciones: total=0 deudas=0 entregas=0 novedades=0 pedidos=0 tiendaEnLinea=false` |
| **D4** varios estatus | `[live] deudas por vencer tras crear el apartado: total=1 estatus=apartado incluyeElApartado=true` (+ `422 claves=status.0` con un estatus inventado) |
| **D5** campos personalizados | `[live] campos personalizados del módulo=0` (200 con lista vacía; el dibujado con definiciones está cubierto por `service_order_form_screen_test.dart`) |
| **Permisos** | Super admin: `␣permisos=85␣pestanas=Vender | Órdenes | Caja | Ventas | Cuenta`. Empleado: `permisos=53`, mismas pestañas y `403 en /subscription: Tu usuario no tiene permiso para esta acción.` |
| **A6** borrar una orden devuelve el stock | Se comprueba con `LIVE_SERVICE_ORDERS_STOCK=true` (la prueba agrega una refacción, borra la orden y exige el stock previo) |

> Nota de la corrida: había un **turno abierto** (#16, de una sesión anterior) que bloqueaba todas las
> terminales de la sucursal (`available_cash_registers: []`). La app ofrece «Unirme» justo para eso, así
> que las pruebas ahora **se unen** a ese turno en vez de abandonar el escenario (y no lo cierran: no es
> suyo). Si prefieres partir de cero, se cierra desde la app/web y la prueba abre su propio turno.

Y en el **teléfono** (Redmi 2201116TG, MIUI/HyperOS, túnel USB de §4.1) el escenario de impresora:

```bash
flutter test integration_test/qa_device_test.dart -d EE95QSVKORE6WCL7 \
  --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 \
  --dart-define=API_HOST_HEADER=ezyventas2.test \
  --dart-define=LIVE_API_EMAIL=••• --dart-define=LIVE_API_PASSWORD=••• \
  --dart-define=LIVE_PRINTER_NAME=MP210 --plain-name impresora
# 01:01 +1: All tests passed!
```

| Qué se comprobó | Resultado real |
|---|---|
| Login y venta reales por el túnel | `POST /auth/login`, `GET /transactions/27` y `GET /print/templates?type=ticket_venta` por `https://127.0.0.1:8443/api/v1` (con `Host: ezyventas2.test`) |
| Conexión con la térmica (BLE) | `[printer] conectada "MP210" mtu=248 bloque=245 B conRespuesta=true sinRespuesta=true` y el aviso «Ticket enviado a la impresora.» |
| Velocidad del ticket con el **logo** (8 739 B) | `[printer] 8739 bytes en 36 bloques de 245 (mtu=248, sinRespuesta=false) en 3406 ms` (antes ~11 s con 20 B/25 ms) y **el ticket salió impreso, con el logo**, en la térmica del equipo |
| Estado de la impresora en la hoja | Badge `CONECTADA` y «Impresora conectada: MP210» (la impresora queda guardada, así que reconecta sin escanear) |

> Antes de esta corrida, con el **Bluetooth del teléfono apagado** la prueba fallaba en el paso 2 con
> el texto real de la app (`El Bluetooth está apagado`), que no es ninguno de los dos estados que la
> prueba acepta: es un fallo del entorno, no de la app (queda documentado aquí para no confundirlo).

### Revisión de UI/UX de la prueba manual (21 sep 2026)

Cambios pedidos en la revisión manual, pantalla por pantalla. Se mantiene la identidad de marca
(**naranja primario** y superficies oscuras); fuera de eso, esta pasada se tomó la libertad de
reacomodar tamaños, formas y colores para que cada acción se reconozca de un golpe.

| Pantalla | Cambio |
|---|---|
| **Login** | Check **«Mantener la sesión abierta»** (marcado por defecto): sin marcarlo, `POST /auth/login` guarda el token **solo en memoria** (`SessionStore.saveSession(persist: false)`) y al cerrar la app se vuelve a pedir la contraseña. Se quitó la URL base de la API que se imprimía en modo debug y en su lugar hay un enlace directo a `https://ezyventas.com/login` (`url_launcher` → navegador del teléfono). |
| **Vender** | Buscador en pastilla con el icono de la marca, chips de categoría rellenos de naranja al estar activos, tarjetas con borde naranja y precio en naranja cuando hay promoción, stock en **verde**/**rojo**, y barra del carrito con filete y contador (`3 productos · 5 artículos`). |
| **Detalle de producto** | Descripción en **texto plano** (`HtmlText.toPlain`: el servidor la guarda como texto enriquecido, `<p>dsfg</p>`). Se quitó la sección `Etiqueta` / `Imprimir etiqueta`. |
| **Carrito** | Total destacado arriba en una franja de la marca, sección `PRODUCTOS`, franja de color por producto, stepper con el `+` en naranja, `Cobrar` más alto (56 px), `Apartar` en azul y `Pedido` con borde. Se dejó de llamar «línea» al producto. |
| **Impresión** | Fuera `Ver respaldo HTML` (devolvía error del servidor; ver más abajo). Botón principal `Imprimir ticket`/`Imprimir etiqueta` según el documento y más alto, **Buscar/Conectar/Cambiar impresora en azul Bluetooth** y **Enviar por WhatsApp en verde**. |
| **Orden de servicio** | Las evidencias ya se ven: era el certificado autofirmado (ver §4.1). Además, si la miniatura del servidor no existe se cae a la **foto original** y tocar una evidencia la abre a pantalla completa con zoom. |
| **Notificaciones** | **Sí estaba desarrollada**: la campana lee `GET /notifications` (`expiring_debts`, `upcoming_deliveries`, `unread_updates`, `pending_orders`) y `Cuenta → Notificaciones` las explica y navega. Lo que faltaba era **refrescar**: ahora el cascarón vuelve a pedir los contadores cada vez que la app pasa a primer plano (`AppShell` con `WidgetsBindingObserver`), así que un apartado que vence o un pedido que entra mientras el teléfono está guardado se ve sin reiniciar la app. Comprobado contra la API real con la cuenta del propietario: `{"expiring_debts":1,…,"total":1}` (el mismo aviso que muestra la web). |

**Respaldo HTML.** `POST /print/ticket-html` respondía `Ocurrió un error en el servidor.` en la
corrida real, así que el botón se quitó de la hoja (y se borró el widget `ticket_html_sheet.dart`).
La capa de datos y sus pruebas se conservan: si el backend lo arregla, solo hay que volver a pintar
el botón.



32. **El plugin de Bluetooth solo pide los permisos al escanear, y la hoja pedía primero las
    emparejadas (app, corregido).** `flutter_blue_plus` resuelve `BLUETOOTH_SCAN` /
    `BLUETOOTH_CONNECT` dentro de `startScan` (`ensurePermissions` → `requestPermissions`), pero
    `getBondedDevices` **no** los pide: en Android 12+ sin permiso concedido el sistema lanza
    `SecurityException`, que la app no traducía (capturaba solo `PrinterException`) y la hoja de
    impresión se quedaba con el indicador girando. Ahora `PrinterController.loadDevices` lista las
    emparejadas dentro de su propio `try`, escanea (lo que dispara el diálogo del sistema) y
    **reintenta** la lista —emparejadas primero, como antes— y `BluetoothPrinterService` traduce los
    fallos del plugin (`PrinterException.missingPermission`, «No se pudo usar el Bluetooth del
    teléfono: …»). Cubierto por `test/features/printing/application/printer_controller_test.dart`.
33. **La impresora térmica del equipo es BLE; la emparejada por clásico no sirve.** El listado del
    sistema mostraba una térmica emparejada por `[BR/EDR]` (`BY-480BT_05AC`), que **no** se anunciaba
    en el escaneo BLE; la app imprime por GATT, así que la válida es la que sí se anuncia (`MP210`).
    Por eso el escenario acepta el nombre por `--dart-define` y, sin él, **enumera** los dispositivos
    (`IMPRESORA VISTA | …`) en lugar de imprimir a ciegas.
34. **MIUI no deja conceder permisos ni inyectar toques desde el equipo.** `adb shell pm grant
    com.ezyventas.app android.permission.BLUETOOTH_SCAN` responde
    `SecurityException: … GRANT_RUNTIME_PERMISSIONS` (igual que la inyección de `adb input` con
    `INJECT_EVENTS`), así que el diálogo de «dispositivos cercanos» se acepta **una vez** en la
    pantalla del teléfono y queda concedido para las corridas siguientes. En la corrida se aceptó a
    mano y el escaneo devolvió resultados en la misma pasada.
35. **La imagen de la plantilla del ticket no viaja en el ESC/POS (backend).** La plantilla
    `ticket_venta` del negocio tiene logo (`https://ezyventas.com/storage/6376/Aponte-phone-logo.png`)
    y el respaldo HTML **sí** lo incluye (`<img src="…/Aponte-phone-logo.png">`), pero
    `POST /print/bluetooth-payload` devuelve un payload **solo de texto**: 427 bytes con la
    plantilla 3 (58 mm) y 611 con la 7 (80 mm), con **cero** apariciones de los comandos de imagen
    de ESC/POS (`GS v 0`, `ESC *`, `GS ( L` y `GS 8 L`) y sin ningún campo de imagen en el JSON
    (`commands_base64`, `paperWidth`). Ningún cliente ESC/POS puede imprimir lo que no recibe: el
    servidor debe **rasterizar** el logo dentro del payload (como hace con las etiquetas, que llegan
    como operación `DescargarImagenDeInternetEImprimir` y el teléfono no puede resolver). Queda como
    límite de esta entrega (pendiente 1) y es lo que explica que el ticket impreso salga sin logo
    aunque la plantilla lo tenga.
36. **Las imágenes del servidor no cargaban en el teléfono (app, corregido).** Los medios llegan con
    URL absoluta al host local (`https://ezyventas2.test/storage/6/iphone.png`) y ese dominio no
    resuelve en el teléfono (`ping: unknown host ezyventas2.test`), así que `Image.network` caía
    siempre en su marcador. `ServerImage` + `AppConfig.mediaUri` / `mediaHeaders` reescriben el
    origen al del túnel y mandan el `Host` de Herd solo cuando `API_HOST_HEADER` está definido.
    Verificado en el dispositivo con la reja del catálogo.

37. **La app no tenía identidad visual propia (app, corregido).** El login y el splash anunciaban la
    marca con un círculo ámbar y `Icons.shopping_cart_outlined`, y el ícono del lanzador seguía siendo
    el de Flutter. Ahora `BrandLogo` (`lib/core/widgets/brand_logo.dart`) pinta el logotipo real —
    `assets/images/white_logo.png` en el tema oscuro y `black_logo.png` en el claro, con
    `errorBuilder` que cae al wordmark de texto— en el login y en el splash, y
    `tool/app_icons.ps1` genera el ícono de Android desde el arte de `assets/images/ezyventas_icon.jfif`:
    los cinco `mipmap-*/ic_launcher.png` con la esquina redondeada del arte recortada a 145/1024 (las
    esquinas quedan transparentes) y el **ícono adaptativo** de API 26+ con fondo `#14191D` y el arte
    al 80 % en `ic_launcher_foreground.png`, dentro de la zona segura de cualquier máscara (§4.3).
    Verificado en el Redmi (20 sep 2026): captura del login con el logotipo y del cajón de apps con el
    ícono nuevo.

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
24. **El historial de la suscripción no incluía el `id` del pago — CORREGIDO por el backend (D1,
    2026-09-20).** `history[].payment` traía `folio`, `status`, `paid_at` y `can_request_invoice`, pero
    **no** `id`, y `POST /subscription/payments/{paymentId}/request-invoice` exige ese id: la app no podía
    pedir la factura de un pago desde el teléfono (evidencia original:
    `[live] última versión: v12 … puedeFactura=true idPago=null`). Ahora el id viaja en el historial y la
    app muestra «Solicitar factura» cuando el pago está aprobado y aún sin factura. Verificado el 21 sep
    2026: `[live] última versión: v12 2026-06-19 11:36:54.000 total=$439.00 estatus=Aprobado
    puedeFactura=true idPago=37`.
25. **Pagos `pending` / `rejected`: no son facturables** (D2, documentado el 2026-09-20). Su id sí viaja
    (`pending_payment` / `last_rejected_payment`), pero el servidor rechaza la factura con
    `403 payment_not_approved` («Solo puedes solicitar facturas de pagos aprobados.»), que ya está en el
    catálogo de códigos (contrato §12). La app solo ofrece la acción cuando
    `can_request_invoice = true` y muestra el `message` del servidor si lo rechaza.
26. **El `403` de la suscripción usa el mensaje genérico de permisos.** `SubscriptionRequest::authorize`
    devuelve `false` para un empleado, así que el cuerpo es «Tu usuario no tiene permiso para esta
    acción.» y **no** el `owner_only` que documenta el catálogo de códigos (§12 del contrato). La app
    muestra el `message` tal cual y oculta la opción del menú cuando `is_subscription_owner = false`.
27. **El stack aprobado no incluye un selector de archivos**, así que la constancia de situación fiscal se
    sube como **imagen** (cámara/galería, ≤ 2 MB) y no como PDF (el servidor sí acepta
    `pdf,jpg,jpeg,png,webp`). La pantalla lo explica y el envío del PDF queda para la web (pendiente 8).
28. **`GET /notifications` no distinguía por módulo contratado — CORREGIDO por el backend (D3,
    2026-09-20).** Los cuatro contadores llegan siempre (un usuario sin `transactions.access` los recibe
    en `0`) y `pending_orders` solo se calcula si la tienda en línea está contratada, así que la app
    mostraba un cero que no podía explicar. La respuesta incluye ahora `modules` (`{"online_store":
    bool}`) y la app **oculta** el contador del módulo que el negocio no tiene contratado
    (`NotificationCounters.isCategoryVisible`). Verificado el 21 sep 2026:
    `[live] notificaciones: total=0 deudas=0 entregas=0 novedades=0 pedidos=0 tiendaEnLinea=false` (la
    pantalla no pinta «Pedidos pendientes»).
29. **`expiring_debts` agrupa dos estatus y el listado solo aceptaba uno — CORREGIDO por el backend (D4,
    2026-09-20).** El contador suma `apartado` **y** `pendiente`, y `GET /transactions` aceptaba un solo
    `status`, así que «Deudas por vencer» abría el historial **sin filtro**. Ahora la API acepta varios
    (`?status[]=apartado&status[]=pendiente`, notación con corchetes; la app la manda así porque PHP se
    queda con el último valor de una clave repetida) y un valor desconocido sigue respondiendo `422` con
    `errors["status.0"]`. Verificado el 21 sep 2026 con un apartado **real**, creado por la propia prueba
    (V-005, $70, `Juanito babanas`): `[live] deudas por vencer tras crear el apartado: total=1
    estatus=apartado incluyeElApartado=true`, y con un estatus inventado:
    `[live] estatus inválido: 422 claves=status.0 El estatus seleccionado no es válido.`
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
(`theme_mode`). La marca la pinta `BrandLogo` con los logotipos de `assets/images/` (blanco sobre
el tema oscuro, negro sobre el claro) y el ícono del lanzador se genera con `tool/app_icons.ps1`
(ver §4.3).

### Impresora termica (etapa 6)
`lib/core/printing/`:
- `bluetooth_printer_service.dart`: conexión GATT con `flutter_blue_plus`, búsqueda de la
  característica escribible (primero los servicios conocidos `0000af30…`, `49535343…`,
  `00001101…`) y **aviso `Se perdió la conexión con la impresora.`** si el enlace cae a media
  impresión (el ticket nunca queda a medias sin avisar).
- **Velocidad de envío (21 sep 2026).** El contrato §10 describe el procedimiento de la **web**
  (`useBluetoothPrinter.js`: bloques de **20 bytes con 25 ms** de pausa ≈ 800 B/s), y así estaba la
  app. Con eso, el ticket real de la plantilla #3 —que lleva el **logo del negocio** rasterizado como
  bitmap ESC/POS (`GS v 0`), **8 739 bytes** medidos— tardaba ~11 s en llegar a la impresora: el texto
  salía al instante y **el logo tardaba una eternidad**, porque el 96 % del documento es el bitmap.
  Ahora:

    | Pieza | Antes | Ahora |
    |---|---|---|
    | Tamaño de bloque | 20 B fijos | `MTU - 3` (`requestMtu(512)` al conectar, acotado a 512) |
    | Ritmo | pausa fija de 25 ms por bloque | el **ACK** de cada bloque con `write` (con respuesta) |
    | `writeWithoutResponse` | siempre | solo si la característica **no** admite `write`; ahí se deja una pausa de 10 ms (sin ACK no hay control de flujo) |
    | Ticket con logo (8.7 KB) | ~11 s | **3.4 s** medidos (36 bloques de 245 B con ACK; el MTU de la MP210 es 248) |

  El troceado es puro y está probado sin impresora (`chunkSizeFor` / `chunkRanges` en
  `test/core/printing/bluetooth_printer_service_test.dart`: sin huecos, sin bytes repetidos y con el
  último bloque corto), y el teléfono registra en el log lo que realmente usó:
  `[printer] 8739 bytes en 36 bloques de 245 (mtu=248, sinRespuesta=false) en 3406 ms`.

  Lo que queda en el cronómetro es la **latencia de cada ACK** (~94 ms con el intervalo de conexión
  negociado): si algún día hace falta más, la palanca es `requestConnectionPriority(high)` (Android;
  probado aparte, no se dejó por prudencia: acortar el intervalo en un módulo BLE barato puede
  desestabilizar el enlace, y con 3.4 s el ticket ya sale sin que el usuario note el bitmap).
- `printer_preferences.dart`: guarda el identificador de la impresora y la plantilla elegida por
  tipo. Se usa `flutter_secure_storage` porque el stack aprobado **no** incluye `shared_preferences`
  y el almacén seguro ya estaba en la app (sesión y tema).
- `print_operations_encoder.dart` (contrato §10): traduce las `operations` del servidor a bytes de
  impresora. `TextoSegunPaginaDeCodigos` → selección de tabla (`ESC t n`, `cp850` → `ESC t 2`) + los
  bytes ESC/POS que **ya armó** el servidor byte por byte; `EscribirTexto` → el texto TSPL tal cual en
  UTF-8 (la etiqueta con su `BITMAP` y su `BARCODE` rellenos); `AbrirCajon` → el pulso `ESC p`. Lo que
  el teléfono no puede emitir queda en `EncodedPrintOperations.ignored` y la UI lo avisa en vez de
  imprimir a medias. `EscPosTextExtractor` saca el texto legible del ESC/POS para previsualizar o
  compartir.
- `esc_pos_builder.dart` + `cp850.dart`: encoder ESC/POS **local** con la página de códigos **CP850**
  (la misma que usa `PrintEncoderService` en el servidor). Ya **no** lo usa ningún documento: el corte
  de caja se imprime con las `operations` del servidor (contrato §6.3) y el ticket también. Queda
  aislado (con sus pruebas) como base del respaldo sin conexión de la fase 5 (contrato §10,
  «Impresión sin conexión»); si la app no llega a necesitarlo, se puede borrar.
- **Permisos de Android 12+ (ver hallazgo 32).** El plugin **solo** pide `BLUETOOTH_SCAN` /
  `BLUETOOTH_CONNECT` al **escanear** (`startScan`); el listado de emparejadas
  (`getBondedDevices`) **no** los pide y sin ellos el sistema lanza `SecurityException`. Por eso
  `PrinterController.loadDevices` lista las emparejadas dentro de su propio `try`, escanea (lo que
  dispara el diálogo del sistema) y reintenta la lista; además traduce cualquier fallo del plugin
  (`PrinterException.missingPermission`, «No se pudo usar el Bluetooth del teléfono: …») en lugar de
  dejar la hoja de impresión con el indicador girando.

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
5. **Sobrepago: cada camino lo trataba distinto — CORREGIDO por el backend (A4, 2026-09-20).**
    `POST /transactions/{id}/payments` rechazaba con `422` "El monto total del pago excede el saldo
    pendiente." mientras `/pos/checkout` recortaba el pago al total. El servidor aplica ahora **una
    sola regla** (contrato §7): en **efectivo** el sobrante es el cambio que devuelve `change`; con
    cualquier otro método, un pago mayor al saldo se rechaza. La app ya implementaba esa misma regla
    en `CartState.change` («solo cuando todos los pagos son en efectivo»), así que no hubo que tocar
    nada: verificado el 21 sep 2026 con la venta `V-003` (`cambio=$0.00`, pago exacto) y con los
    abonos de la prueba de apartado.
6. `GET /transactions/{id}` no expone `customer_id` en la raiz (solo `customer: {id, name, balance,
   credit_limit}` o `null`), pero la web (`TransactionCancellationModal.vue`) decide si el reembolso
   puede ir a saldo con `transaction.customer_id`. La app usa `customer != null` (y `customer.id`).
7. `PUT /transactions/{id}/payments/{paymentId}` acepta los 5 metodos de `PaymentMethod` (incluye
   `saldo` e `intercambio`), pero el modal web (`EditPaymentModal.vue`) solo ofrece 4 (sin
   `intercambio`). La app ofrece los 4 de la web mas el metodo actual cuando es `intercambio`, para
   no perderlo al guardar.
8. **Conciliacion del cliente al editar/borrar un abono — CORREGIDO por el backend (A1, 2026-09-20).**
    Era el fallo mas caro que encontro la app: `DELETE /transactions/{id}/payments/{paymentId}` no
    revertia el `payDebt` que el abono habia escrito en `customers.balance`
    (`TransactionPaymentEditService::delete()` conciliaba el banco, el saldo *usado como pago* y el
    movimiento de caja, pero no la deuda del cliente; el `PUT` solo el banco), y al cancelar el
    servidor perdonaba `total - total_paid` sin contar el pago borrado. Evidencia original
    (`LIVE_SALES_LAYAWAY=true`): apartado de $140 → abono de $1 → edicion a $1.50 → borrado → abono de
    $2 → cancelacion con reembolso; el cliente terminaba con **+$1.00 a favor** (el importe del pago
    borrado) en cada corrida, y se ajustaba a mano desde la web. El servidor hace ahora la operacion
    simetrica (`payDebt` ↔ `addDebt`, `useBalance` ↔ `addRefund`). **Verificado el 21 sep 2026**
    (apartado `V-005` de $70 del cliente `Juanito babanas`):
    `[live] saldo del cliente tras la cadena completa: $0.00 (antes de la cadena $0.00)`. La prueba ya
    no caracteriza el desfase: **exige** el saldo intacto.
9. **`remaining_due` en ventas anuladas — CORREGIDO por el backend (A2, 2026-09-20).** Antes era
    `max(0, total - total_paid)`, asi que una venta `reembolsado` seguia reportando saldo en
    `GET /transactions` (`V-005 reembolsado ... saldo=$138.00`); ahora `remaining_due` (y por tanto
    `pending_balance` / `is_paid`) es **0** en `cancelado` y `reembolsado`. Verificado el 21 sep 2026:
    `[live] V-004 reembolsado Juanito babanas total=$70.00 saldo=$0.00`. La app mantiene
    `TransactionSummary.hasPendingBalance` (oculta el saldo en ventas anuladas) por si un servidor
    viejo lo sigue reportando: con el servidor actual el resultado es el mismo.
10. **El saldo a favor se aplicaba sin `use_balance` — CORREGIDO por el backend (A3, 2026-09-20).**
    `POST /pos/layaway` (y el cobro) consumian el saldo del cliente cuando la venta quedaba con deuda
    aunque no se enviara `use_balance`; el contrato §7.3 lo describe como accion explicita del cajero.
    Ahora el saldo **solo** se aplica con `use_balance: true`. Verificado el 21 sep 2026: la app envia
    `use_balance: false` y el apartado se crea sin pagos iniciales
    (`[live] apartado V-005 estatus=apartado total=$70.00 saldo=$70.00`, `pagos iniciales=0.0`); la
    prueba lo **exige** (`no debe aplicarse sin use_balance`).
11. `POST /service-orders` exige `create_customer` **siempre** (`required|boolean`), tambien cuando se
    elige un cliente existente; el contrato §9 lo marca como \"required boolean\" pero el ejemplo de
    `curl` **no** lo envia, y el `422` responde \"El campo create customer es obligatorio.\". La app lo
    manda en **todas** las altas (`true`/`false`; en multipart `1`/`0` porque Laravel no acepta la
    cadena `"true"` en un campo de formulario). Detectado por la prueba real contra la API.
12. El `message` del cambio de estatus es \"Estatus de la orden actualizado correctamente.\", no el
    \"Estatus actualizado a “Terminado”.\" que ilustra el contrato §9. La app muestra el `message` del
    servidor tal cual (nunca compone el texto) y, para el `422`, prioriza `errors.status[0]`.
13. **Borrar una orden de servicio no revertía stock ni deuda — CORREGIDO por el backend (A6,
    2026-09-20).** `DeleteServiceOrderAction` borraba la orden y su venta vinculada, pero dejaba el
    stock de las refacciones consumido y la deuda del cliente (`addDebt` del alta) en pie. Ahora
    revierte ambos efectos. Verificado el 21 sep 2026 con `LIVE_SERVICE_ORDERS_STOCK=true`: la prueba
    agrega un producto real como concepto, borra la orden y **exige** que el stock vuelva al valor
    previo (`[live] stock de la refacción tras borrar la orden: … (antes …)`).
14. **Campos personalizados al crear una orden — CORREGIDO por el backend (D5, 2026-09-20).** Antes
    `custom_field_definitions` solo viajaba dentro del detalle (`GET /service-orders/{id}`), asi que la
    app podia capturarlos al **editar** pero no al **crear**. Ahora existe
    `GET /service-orders/custom-fields` (contrato §9) con las mismas definiciones del modulo
    (`module = service_orders`), y el formulario de alta las dibuja con **el mismo renderizador** que
    la edicion (`ServiceOrderCustomFieldsSection`); si la llamada falla, avisa que se pueden capturar
    al editar en vez de bloquear el alta. Verificado el 21 sep 2026: el endpoint responde `200` con
    `campos personalizados del módulo=0` en la suscripcion de prueba (no tiene ninguno definido), asi
    que la lista vacia se comporta como antes (sin seccion); el dibujado con definiciones reales esta
    cubierto por `service_order_form_screen_test.dart`.
15. `promised_at` es una fecha con hora en el backend (`America/Mexico_City`): la app la envia como
    `YYYY-MM-DD` (medianoche local) para que la fecha mostrada sea la elegida por el usuario y no se
    corra un dia por la zona horaria.

### Discrepancias y hallazgos (etapa 6)

16. **`POST /print/whatsapp-ticket` no armaba el ticket de una orden de servicio — CORREGIDO por el
    backend (B3, 2026-09-20).** `PrintController::whatsappTicket` resolvía el origen con
    `PrintDataSourceResolver` y, si **no** era una `Transaction`, respondía `200` con `ticket: null`
    (`customer_phone: null`). Evidencia original (`LIVE_SERVICE_ORDERS=true` + `LIVE_PRINTING=true`):
    `[live] WhatsApp service_order=3 ticket=null telefono=sin telefono`. Ahora
    `WhatsAppTicketService` arma el ticket de la orden (`kind: service_order`) y un origen que **no**
    puede producir ticket (`product`, `customer`) responde `422 no_whatsapp_ticket` en vez de un `200`
    vacío. Verificado el 21 sep 2026: `[live] WhatsApp de un cliente: 422 no_whatsapp_ticket Este
    documento no tiene ticket de WhatsApp.` (la app ya no puede creer que envió algo) y
    `[live] WhatsApp kind=sale telefono=3312650047 lineas=19` para una venta real. El `kind` lo sigue
    decidiendo el documento resuelto, no el `data_source_type` pedido, así que en el detalle de una
    orden la app ofrece el ticket de su **venta vinculada**.
17. **`GET /print/templates` filtraba por un solo `context` — CORREGIDO por el backend (B4,
    2026-09-20).** La web siempre pide **conjuntos** (`PointOfSaleController` → `pos` + `general`,
    `TransactionController` → `transaction` + `general`, …) y el endpoint móvil solo aceptaba uno.
    Ahora acepta varios a la vez (`?context[]=pos&context[]=general`, `?context=pos,general`; un
    contexto desconocido responde `422` con `errors.context.N`). La app **sigue** pidiendo por `type`
    (`GET /print/templates?type=ticket_venta`) y aplicando el conjunto de contextos en
    `PrintDocument.selectTemplates` / `selectLabelTemplates`: así una sola llamada trae las plantillas
    de todos los contextos de ese tipo y quedan cacheadas para imprimir sin conexión (contrato §10).
    Verificado el 21 sep 2026 con la suscripción de prueba (7 plantillas, 4 de ticket y 3 de etiqueta):
    `[live] la app selecciona para una venta: #3, #7` (las dos de contexto `general`, 58 y 80 mm).
18. **Etiquetas con imagen: se imprimían incompletas — CORREGIDO por el backend (B2, 2026-09-20).**
    `POST /print/payload` devolvía la operación **del plugin de escritorio**
    `DescargarImagenDeInternetEImprimir`, que el teléfono no puede ejecutar (exige descargar la imagen y
    rasterizarla con GD). Ahora el servidor descarga la imagen, la rasteriza a 1 bit y la inserta en el
    mismo texto TSPL como `BITMAP x,y,ancho_en_bytes,alto,0,<hex>` (limitada al ancho de la etiqueta), y
    lo que no pueda resolver lo declara en el campo nuevo `unsupported_operations` (`"Image: <url>"`).
    La app manda el texto TSPL tal cual en UTF-8 a la impresora de etiquetas y **avisa** cuando
    `unsupported_operations` o `warnings` vienen con algo, en vez de imprimir a medias en silencio
    (`LabelPayload.warningNotice`). Verificado el 21 sep 2026: la plantilla #4 resuelve **una sola**
    operación `EscribirTexto` con el comando completo (`noResueltas=[]`); el `BITMAP` solo aparece si la
    plantilla trae una imagen, y ninguna de las tres etiquetas de la suscripción de prueba la tiene (esa
    parte queda cubierta por `PrintingApiTest` en el backend, no por esta corrida).
19. **La etiqueta salía con el código de barras vacío — CORREGIDO por el backend (B6, 2026-09-20).**
    El `BARCODE` de la plantilla real viajaba con el valor vacío
    (`BARCODE 23.97,89.43,"128",30,1,0,2,2,""`). Ahora, si el valor se resuelve a cadena vacía, el
    servidor lo rellena con el identificador del documento (`products.sku`, o `P-<id>`; `folio` de la
    venta o la orden; `C-<id>` de un cliente) y lo declara en `warnings`. Verificado el 21 sep 2026
    (producto #6): `[live] … avisos=[Barcode: la plantilla no resolvió un valor, se usó «P-6».]` y el
    comando real `BARCODE 23.976377952756,89.43188976378,"128",30,1,0,2,2,"P-6"`.
20. **El corte de caja no se podía imprimir (ni reimprimir) — CORREGIDO por el backend (B5,
    2026-09-20).** `cash_register_session` no era un `data_source_type` válido (contrato §6.3), así que
    el corte se armaba en el teléfono con el encoder ESC/POS local y el de un turno cerrado días atrás
    era **irrecuperable**. Ahora `GET /cash-register-sessions/{id}/receipt` devuelve el corte listo para
    (re)imprimir: `session`, `summary` con las cifras congeladas del cierre, la plantilla usada y las
    `operations` en el mismo formato que §10; además `data_source_type = cash_register_session` funciona
    en `/print/bluetooth-payload`, `/print/payload` y `/print/ticket-html`. La plantilla se resuelve
    `template_id` → plantilla del negocio con contexto `cash_register` → **incorporada** del servidor
    (`template.builtin = true`, `template.id = null`, así que no hay `template_id` que mandar). La app
    **borró** su renderizador local (`cash_cut_renderer.dart` + `cash_cut_document.dart`) y ahora
    imprime las `operations` del comprobante tal cual (`CashCutReceipt` + `PrintOperationsEncoder`), con
    el respaldo de `/print/bluetooth-payload` cuando la plantilla es del negocio y trae una imagen (el
    servidor la rasteriza; el teléfono no). Verificado el 21 sep 2026 sobre el turno **abierto** #16:
    `[live] corte del turno abierto #16 plantilla=Corte de caja (incorporada) operaciones=1 bytes=491
    papel=80mm avisos=[]`, y el corte del turno **cerrado** en la prueba de caja (`LIVE_POS=true`).
    `PrintOperationsEncoder` traduce `TextoSegunPaginaDeCodigos` a `ESC t 2` (CP850) y concatena los
    bytes que armó el servidor, así que la app ya no tiene tablas de códigos propias para el corte.
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
- **Imágenes del servidor por el túnel.** Los medios llegan con URL absoluta al host del servidor
  (`https://ezyventas2.test/storage/6/iphone.png`) y ese dominio **no resuelve en el teléfono**
  (comprobado en el dispositivo: `ping: unknown host ezyventas2.test`), así que la imagen caía
  siempre en el marcador de la pantalla. `ServerImage` (`lib/core/widgets/server_image.dart`)
  recorre **en orden** los intentos que arma `AppConfig.mediaRequests` —el origen de la API
  (`https://127.0.0.1:8443`) con el `Host` con el que Herd elige el sitio y, si fallara, la URL tal
  cual— y se usa en el catálogo, el detalle de producto, las evidencias de órdenes y la foto de
  perfil. Sin `API_HOST_HEADER` (producción) la URL se descarga tal cual y **no** se añade ningún
  header; los hosts externos (`ui-avatars.com`, `placehold.co`) nunca se reescriben, y una ruta
  relativa (`/storage/…`) se resuelve contra el origen de la API.
- **El certificado autofirmado también afectaba a las imágenes.** `ApiClient` aceptaba el
  certificado en debug, pero `Image.network` usa el `HttpClient` del motor: **todas** las imágenes
  del servidor (la del `Iphone 20`, las evidencias de una orden) fallaban mientras la API
  respondía, y solo se veían las que vienen de hosts con certificado válido (`placehold.co`,
  `ui-avatars.com`). `main.dart` inyecta `debugNetworkImageHttpClientProvider` con
  `badCertificateCallback` **solo en debug** (`kDebugMode && ALLOW_BAD_CERTIFICATE`), igual que la
  API; en release se ignora.

#### Pruebas manuales en el teléfono (túnel + APK ya configurado)

Para usar la app **a mano** en el teléfono contra la API local (sin depender de F5) se dejan las dos
piezas puestas y verificadas:

```powershell
# 1) túnel (idempotente: quita el registro viejo y lo vuelve a crear)
powershell -ExecutionPolicy Bypass -File tool\android_tunnel.ps1
#    -> en el TELÉFONO, https://127.0.0.1:8443 llega al Herd del equipo (127.0.0.1:443)

# 2) comprobar DESDE el teléfono que la API responde (el teléfono trae `curl` en /system/bin)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb push tool\android_tunnel_check.sh /data/local/tmp/
& $adb shell sh /data/local/tmp/android_tunnel_check.sh correo@negocio.com 'secreto'
#    sin Host -> 404 (el "Site not found" de Herd) · con Host, sin token -> 401 · login real -> 200

# 3) instalar la app apuntando al túnel (build DEBUG, ver aviso abajo)
flutter build apk --debug `
  --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 `
  --dart-define=API_HOST_HEADER=ezyventas2.test
adb install -r -t build\app\outputs\flutter-apk\app-debug.apk
```

- **Tiene que ser `--debug`.** El certificado autofirmado de Herd se acepta **solo** con
  `kDebugMode` (`ApiClient`: `if (kDebugMode && AppConfig.allowBadCertificate)`), así que un APK de
  **profile/release apuntado al túnel falla la conexión** (fallo de certificado). El `flutter run
  --profile` del `launch.json` sirve para medir fluidez, no para el túnel con Herd.
- El `Host` viaja por `API_HOST_HEADER`; sin él Herd no sabe qué sitio es y devuelve su HTML de `404`.
- `adb reverse` **se pierde** si el teléfono se reconecta, se reinicia el servidor `adb` o cambia el
  modo USB: si la app deja de conectar, vuelve a correr el paso 1 (y el 2 para confirmar). Ojo también
  con el estado raro que se ve al volver a crear un túnel ya existente (figura en `adb reverse --list`
  pero no llega): por eso el script **quita y crea**.
- El script `tool\android_tunnel_check.sh` se ejecuta con el `sh` de Android (`mksh`), así que va en
  **LF**: el repo lo fuerza con `.gitattributes` (`*.sh text eol=lf`). Si lo editas en Windows y lo
  subes con CRLF, `curl` recibe las URLs con `\r` y todo responde `000` sin explicar por qué
  (`adb shell dos2unix /data/local/tmp/android_tunnel_check.sh` lo arregla en el teléfono).

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

### 4.3 Identidad visual: logotipo e ícono de la app

Los archivos de marca viven en `assets/images/`:

| Archivo | Uso |
|---|---|
| `white_logo.png` (734x335, fondo transparente) | Logotipo para **fondos oscuros** (el tema por defecto) y para la pantalla de carga nativa (`tool/launch_logo.ps1`) |
| `black_logo.png` (726x351) | Logotipo para fondos claros |
| `ezyventas_icon.jpg` (685x685) | Arte del **ícono de la app** (lo consume `tool/app_icons.ps1`); sustituye al anterior `ezyventas_icon.jfif`, ya borrado |
| `isologo.png` (228x207) | Isologo suelto, para piezas que necesiten solo la «E» |

`BrandLogo` (`lib/core/widgets/brand_logo.dart`) elige el PNG según el `Brightness` del tema y cae al
wordmark de texto si el asset no llega al bundle; lo usan el login y el splash. En `pubspec.yaml`
los logotipos se declaran **uno a uno** para no empaquetar el arte del ícono ni el isologo, que solo
hacen falta al generar.

El ícono del lanzador se regenera desde el arte con **System.Drawing** (sin Photoshop ni ninguna
herramienta externa):

```powershell
powershell -ExecutionPolicy Bypass -File tool\app_icons.ps1
```

- Escribe los cinco PNG *legacy* (`mipmap-{mdpi…xxxhdpi}\ic_launcher.png`, 48 -> 192 px) recortados
  con la esquina redondeada del arte (radio 145 sobre 1024, un poco **por dentro** del redondeo
  original para que no quede borde blanco): las esquinas salen transparentes y el launcher pinta lo
  suyo.
- Escribe el **ícono adaptativo** de Android 8+ (`mipmap-anydpi-v26/ic_launcher.xml`): fondo
  `#14191D` (`values/ic_launcher_background.xml`) y el arte al 80 % centrado en
  `mipmap-*\ic_launcher_foreground.png` (108 -> 432 px). Esa escala deja la «E» y el nombre dentro
  de la zona segura (66 %) de cualquier máscara, así que ni el círculo de Android puro ni el
  *squircle* de MIUI recortan nada importante.
- Los dos XML se escriben en ASCII (sin BOM) y el script es idempotente: si cambia el arte, vuelve a
  correrlo y recompila (`flutter build apk --debug` + `adb install -r -t`). También acepta
  `-CornerRadius`, `-BackgroundColor` y `-ForegroundScale`.

### 4.4 Pantalla de carga nativa (el "estado de carga" desde el arranque)

Hasta esta entrega el arranque mostraba la ventana de Android **en negro** (el
`?android:colorBackground` del `NormalTheme`/`LaunchTheme` de la plantilla) hasta que Flutter pintaba
su primer frame, y solo entonces aparecía el splash con el logotipo y el indicador giratorio. Ahora el
tema de lanzamiento es de la marca, así que el usuario ve el logo **desde el primer instante**:

| Archivo | Qué pinta |
|---|---|
| `res/values/colors.xml` | `launch_background` = `#FF1A1A1A`, el mismo fondo del tema oscuro de la app (`EzySurfaces.dark.background`) |
| `res/drawable/launch_background.xml` y `res/drawable-v21/…` | Fondo de marca + el logotipo **centrado** (`@drawable/launch_logo`) |
| `res/values/styles.xml` y `res/values-night/styles.xml` | `LaunchTheme` y `NormalTheme` con ese fondo (y sin destello al cerrar el splash) |
| `res/values-v31/styles.xml` | En Android 12+ el sistema dibuja su propio splash: `windowSplashScreenBackground` = fondo de marca y `windowSplashScreenAnimatedIcon` = `@mipmap/ic_launcher` (el icono ya actualizado) |

`launch_logo.png` (736x336 px en `drawable-xxxhdpi` = 184x84 dp, el mismo tamaño que el `BrandLogo`
del splash de Flutter) se genera con **System.Drawing** desde `white_logo.png`:

```powershell
powershell -ExecutionPolicy Bypass -File tool\launch_logo.ps1
```

El paso del splash nativo al de Flutter es continuo: mismo fondo, mismo logotipo en el mismo tamaño y
el indicador giratorio que añade `SplashScreen`. `main()` sigue esperando
`initializeDateFormatting('es_MX')` antes de `runApp`, pero eso es un mapa ya compilado en la app (unos
milisegundos), no una petición: lo que se veía era el fondo negro de la ventana nativa.

**Verificación real (21 sep 2026, en el Redmi).** Se comprobó en el APK instalado que el tema de
lanzamiento ya no pinta negro: `values/colors.xml` → `launch_background=#FF1A1A1A`,
`drawable/launch_background.xml` (y `drawable-v21`) → color + `launch_logo` centrado, `values-v31` →
`windowSplashScreenBackground=@color/launch_background` e icono = `@mipmap/ic_launcher`; el icono nuevo
(`assets/images/ezyventas_icon.jpg`, ya sin el `.jfif` viejo) está en los cinco `mipmap-*` con el tamaño
correcto (48/192/432 px y el arte de la app en el cajón).

Lo que **queda** en el cronómetro de un arranque en frío es el motor de Flutter, no el tema: midiendo
con `adb exec-out screencap` cada ~0.6 s desde `am start`, en un build **debug** el primer frame de la
app tarda ~4.8 s (el motor arranca con JIT y sin AOT); el tramo oscuro previo es la superficie de
Flutter todavía vacía. En **release** ese tramo es mucho menor (el AOT no compila en caliente), así que
la comprobación definitiva del "ya no se ve negro" se hace con un APK de release: en este entorno el
build de release (`assembleRelease` con R8 sobre un APK de depuración de 214 MB) no terminó dentro del
tiempo de la sesión y quedó pendiente. Si al abrir la app todavía se nota el tramo oscuro, el siguiente
paso es mantener visible el splash nativo hasta el primer frame (`io.flutter.embedding.android.
BackgroundMode = transparent` en el manifiesto), que no se aplicó para no cambiar el rendimiento del
arranque sin medirlo.

La pantalla ya cargada se verificó igual (histograma de la captura, sin subir imágenes): el login ocupa
la pantalla completa con el fondo y los paneles del tema — **59.2 % `#232323`, 29.7 % `#1A1A1A` y
1.9 % del naranja de marca `#F68C0F`** — y **0 %** de negro puro; el `#1A1A1A` coincide con el
`launch_background`, así que el paso del splash nativo al de Flutter no cambia de color.

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

1. **Impresora física.** El recorrido de bytes está verificado contra la API real (`531` bytes ESC/POS
   de una venta, `535` de una orden y el TSPL completo de una etiqueta), con pruebas unitarias del
   encoder y, desde la corrida del 20 sep 2026, con una **térmica Bluetooth real** en el teléfono
   (`MP210`): conexión GATT, `POST /print/bluetooth-payload` (plantilla 3 de la venta 24) y el aviso
   «Ticket enviado a la impresora.» (ver «Corrida real del 20 sep 2026 — impresora térmica»). Falta
   probar en hardware el **corte de caja** (bytes que arma el teléfono), el **pulso del cajón** y el
   caso de **cortar el enlace a media impresión**: esa parte necesita apagar la impresora a mano
   porque MIUI no deja automatizar toques desde el equipo (hallazgo 34). El **logo de la plantilla**
   tampoco se imprime: el payload ESC/POS del servidor no trae ninguna imagen (hallazgo 35), así que
   depende del backend rasterizarlo.
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
    `flutter analyze` limpio, `flutter test` (241 pruebas) y `integration_test/qa_device_test.dart`
    corriendo **en un teléfono** (login real, pestañas, catálogo, Cuenta y cierre de sesión, con
    propietario y empleado; el recorrido de POS, caja, ventas, órdenes e impresión y, desde esta
    corrida, la **impresora térmica real** con el ticket ESC/POS que arma el servidor) contra la API
    por el túnel USB (§4.1), con el APK compilado e instalado en el Redmi (§4.2). Sigue fuera de
    alcance lo que exige un entorno desechable (contraseñas reales, punto 7) y lo que necesita
    apagar la impresora a mano (el corte de caja, el pulso del cajón y el corte de enlace, punto 1).
