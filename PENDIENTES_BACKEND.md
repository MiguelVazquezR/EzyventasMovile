# Pendientes del backend detectados por la app móvil

Documento de traspaso **app móvil (Flutter) → API (Laravel)**. Todo lo de aquí salió de usar la app
contra la **API real** (Herd local por el túnel USB de `adb`), no de suposiciones: cada punto trae la
evidencia observada, qué se pide y el criterio para darlo por cerrado.

- App móvil: `ezyventas_app` (Flutter 3.47.4, `com.ezyventas.app`), API `https://ezyventas2.test/api/v1`
  (Host `ezyventas2.test`).
- Contrato de referencia: `01-contrato-api-v1.md` — las secciones §N se citan tal como aparecen ahí.
- Origen: `README.md` del repo móvil («Discrepancias y hallazgos» de las etapas 3-8 y «Pendientes y
  límites»). Este documento es el extracto **accionable para el backend**; el número del hallazgo
  original se indica en cada punto cuando aplica.
- Lo que **no** es del backend (limitaciones del teléfono, del stack aprobado o de la propia app) está
  en la sección E, para que no se toque por error.
- **Cómo usarlo:** cópialo al repo de la API (p. ej. `docs/pendientes-app-movil.md`) y dáselo al agente
  como **único** punto de partida, junto con el contrato `01-contrato-api-v1.md`. Los puntos ya están
  priorizados (P0 → P2) y con el orden de trabajo en la sección F.

## 0. Cómo se reproduce y cómo se verifica

```bash
# API local: Herd elige el sitio por el header Host
curl -sk -H "Host: ezyventas2.test" -H "Accept: application/json" \
  https://127.0.0.1/api/v1/...            # desde el teléfono: https://127.0.0.1:8443/api/v1/...

# token real
curl -sk -H "Host: ezyventas2.test" -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"email":"...","password":"...","device_name":"QA"}' \
  https://127.0.0.1/api/v1/auth/login
```

Pruebas reales del lado móvil que hay que volver a correr al cerrar cada punto (las lanza el equipo
móvil; el backend solo necesita el entorno arriba con la base de datos de prueba):

```bash
flutter test test/live/api_smoke_test.dart \
  --dart-define=LIVE_API_EMAIL=... --dart-define=LIVE_API_PASSWORD=... \
  --dart-define=LIVE_PRINTING=true --dart-define=LIVE_SALES_LAYAWAY=true

flutter test integration_test/qa_device_test.dart -d <serial> \
  --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 \
  --dart-define=API_HOST_HEADER=ezyventas2.test \
  --dart-define=LIVE_API_EMAIL=... --dart-define=LIVE_API_PASSWORD=... \
  --dart-define=LIVE_PRINTER_NAME=MP210 --plain-name impresora
```

## 1. Prioridad

| Prioridad | Puntos | Por qué |
|---|---|---|
| **P0 — dinero / integridad de datos** | A1-A6 | Se descubrió con una cadena real de apartado → abono → edición → borrado → cancelación: deja saldos, deudas y totales desfasados (`customers.balance`, `remaining_due`, `addDebt`) |
| **P1 — funciones que la app ya espera** | B1-B5, D1, D5 | Sin esto el teléfono no imprime el ticket completo (logo), ni la etiqueta con imagen, ni el WhatsApp de una orden; tampoco puede facturar un pago, usar la plantilla del negocio en el corte ni capturar campos personalizados al alta |
| **P2 — contrato vs realidad** | B6, C1-C8, D2-D4, D6-D8 | No rompen nada hoy (la app trae rodeos documentados), pero el contrato miente o falta un campo que la web sí usa |
| **Sin acción del backend** | E | Limitaciones del móvil o del stack aprobado |

Regla transversal: **antes de cambiar semántica de una respuesta, revisar quién la consume en la web**
(`ShoppingCart.vue`, `TransactionCancellationModal.vue`, `EditPaymentModal.vue`, `PointOfSaleController`,
`TransactionController`, `ProductController`, `CustomerController`, `ServiceOrderController`). El arreglo
correcto es el que deja móvil y web de acuerdo, no el que solo satisface al móvil.

## A. Dinero e integridad de datos (P0)

### A1. Borrar o editar un abono no revierte la deuda del cliente — **P0** (hallazgo 8)

**Evidencia contra la API real** (`LIVE_SALES_LAYAWAY=true`), cadena completa sobre un apartado de $140
del cliente `Juanito P` (saldo inicial $0.00): abono de $1 → edición del pago a $1.50 → **borrado del
pago** → abono de $2 → cancelación con reembolso en efectivo. Resultado: la venta queda `reembolsado` y
el stock se devuelve, pero el cliente termina con **+$1.00 de saldo a favor**, exactamente el importe del
pago borrado. Cada corrida deja ese $1 en el cliente de prueba (hoy se ajusta a mano desde la web:
*Clientes → ficha → ajustar saldo*).

**Causa observada**
`TransactionPaymentEditService::delete()` revierte la cuenta bancaria, el saldo **usado como pago**
(`saldo`) y el movimiento de caja del turno; el `PUT` solo concilia el banco. Ninguno de los dos revierte
el `payDebt` que el abono escribió en `customers.balance`, y al cancelar el servidor perdona
`total - total_paid` sin contar el pago borrado.

**Qué se pide**
1. Al **borrar** un pago, revertir en `customers.balance` el efecto del `payDebt` (operación simétrica:
   `addDebt`/`payDebt`, con el mismo redondeo y dentro de la misma transacción de base de datos).
2. Al **editar** un pago, recalcular ese efecto (no solo el banco).
3. Cubrir los dos casos que pueden duplicar la reversión: venta **con deuda** y pago hecho **con saldo a
   favor** (`saldo`).
4. Prueba automatizada del ciclo completo (apartado → abono → editar → borrar → cancelar con reembolso)
   que afirme `customers.balance == 0.00` y la coherencia de `total_paid` / `remaining_due`.

**Criterio de aceptación:** la cadena de arriba deja el saldo del cliente en `0.00` (hoy `+1.00`) y ningún
otro flujo de pago cambia de comportamiento (los pagos que nadie toca siguen conciliando igual).

### A2. `remaining_due` no se pone a 0 al cancelar/reembolsar — **P0** (hallazgo 9)

**Evidencia:** `remaining_due` es `max(0, total - total_paid)`, así que una venta `reembolsado` sigue
reportando saldo en `GET /transactions` (visto: `V-005 reembolsado … saldo=$138.00`). La app oculta el
saldo pendiente en ventas anuladas; la web lo muestra tal cual.

**Qué se pide:** `remaining_due = 0` cuando el estatus es `cancelado` o `reembolsado` (son ventas
anuladas), o documentarlo explícitamente en §8 y avisar en la web. Si se toca, revisar también
`pending_balance` / `is_paid` para que cuenten la misma historia.

**Criterio de aceptación:** `GET /transactions` y `GET /transactions/{id}` devuelven `remaining_due: 0`
(consistente con `is_paid`) en cualquier venta anulada.

### A3. El saldo a favor se aplica solo, sin `use_balance` — **P0** (hallazgo 10)

**Evidencia:** en la primera corrida de la prueba, el cliente tenía $1 a favor y `POST /pos/layaway` lo
usó **sin** que el request enviara `use_balance` (el contrato §7.3 lo describe como acción explícita del
cajero).

**Qué se pide:** respetar `use_balance` (`true` = aplicar saldo, `false`/ausente = no tocar
`customers.balance`), igual en `/pos/checkout`, `/pos/layaway` y `/pos/store-order`. Si el negocio
prefiere el comportamiento automático, **cambiar el contrato** y decirlo, pero que la app y la web usen
la misma regla (hoy la app ya envía `use_balance` y el ticket de abono reporta lo que el servidor aplicó).

**Criterio de aceptación:** con `use_balance` ausente o `false`, el saldo del cliente queda **igual**;
con `use_balance: true`, se aplica y el ticket lo refleja.

### A4. Sobrepago: un camino lo rechaza y el otro lo recorta — **P0** (hallazgo 5)

**Evidencia:** `POST /transactions/{id}/payments` responde `422` «El monto total del pago excede el saldo
pendiente.» (`TransactionPaymentService::applyPaymentToTransaction`), mientras `/pos/checkout` **recorta**
el pago al total. El contrato §8 no documenta el `422`.

**Qué se pide:** una sola regla. Recomendado: rechazar en los dos caminos con el mismo `message` y
documentarlo en §8 y en el catálogo de códigos de error (§12); si se prefiere recortar, documentarlo y
avisar a la app (hoy valida el monto antes de enviar, así que un cambio la deja mandando de más sin
saberlo).

**Criterio de aceptación:** ambos caminos responden igual ante un monto mayor al saldo y la respuesta
está en el contrato.

### A5. Dos fórmulas distintas de totales en POS — **P0** (hallazgos 2 y 3)

**Evidencia:** `POST /pos/store-order` calcula `subtotal` con `item.price` (precio **con** descuento)
mientras el flujo de venta usa `original_price`; además el ejemplo del contrato §7 es inconsistente
consigo mismo (`unit_price: 135`, `quantity: 2`, `discount: 15`, `subtotal: 270`, `total: 270`, cuando la
regla escrita `total = subtotal - total_discount` daría 240).

**Qué se pide:** unificar y documentar la regla que ya usa el POS web (`ShoppingCart.vue`):
`subtotal = Σ(precio de lista × cantidad)`, `total = subtotal − Σ(descuento por unidad × cantidad)`, en
las tres operaciones (venta, apartado, pedido) — y corregir el ejemplo del contrato.

**Criterio de aceptación:** el mismo carrito con descuentos da el **mismo** `subtotal`/`total` en los tres
botones y coincide con lo que cobra la web.

### A6. Borrar una orden de servicio no revierte stock ni deuda — **P0** (hallazgo 13)

**Evidencia:** `DeleteServiceOrderAction` borra la orden **y su venta vinculada**, pero no devuelve el
stock de las refacciones ni revierte la deuda que el alta generó con `addDebt` en el cliente. La prueba de
humo por eso usa un **servicio** como concepto y una orden **sin cliente**, y solo consume stock real con
`LIVE_SERVICE_ORDERS_STOCK=true`.

**Qué se pide:** decidir y ejecutar — revertir stock y saldo al borrar (lo coherente con «la acción no se
puede deshacer») **o** documentar que el borrado no revierte efectos y avisar en la web y en la app. Hoy
la app solo puede decir «esta acción no se puede deshacer», que es cierto para la orden pero no para el
inventario ni el saldo.

**Criterio de aceptación:** una orden con una refacción y un cliente, borrada, deja stock y
`customers.balance` como estaban (o el contrato documenta lo contrario y la app lo avisa con ese texto).

## B. Impresión (P1)

### B1. El logo de la plantilla no viaja en el ESC/POS del ticket — **P1** (hallazgo 35)

**Evidencia:** la plantilla `ticket_venta` del negocio de prueba tiene logo
(`https://ezyventas.com/storage/6376/Aponte-phone-logo.png`) y el respaldo HTML **sí** lo incluye
(`<img src="…/Aponte-phone-logo.png">`), pero `POST /print/bluetooth-payload` devuelve un payload **solo
de texto**: 427 bytes con la plantilla 3 (58 mm) y 611 con la 7 (80 mm), con **cero** apariciones de los
comandos de imagen de ESC/POS (`GS v 0`, `ESC *`, `GS ( L`, `GS 8 L`) y sin ningún campo de imagen en el
JSON (`commands_base64`, `paperWidth`). El ticket impreso sale sin logo.

**Qué se pide:** el servidor debe **rasterizar** el logo de la plantilla (descargarlo, convertirlo a mono
1 bit y escalarlo al ancho de papel) e insertar los comandos de imagen en el payload — igual que ya hace
con las etiquetas, donde llega una operación de imagen. Alternativa aceptable: devolver el raster aparte
(JPEG/PNG base64 + ancho) para que el cliente lo componga, pero entonces hay que documentar el contrato y
el móvil tendría que implementarlo.

**Criterio de aceptación:** el payload de una venta (y de una orden) contiene el raster del logo y el
teléfono lo imprime: **ticket con logo**. Nota de red: la descarga de la imagen ocurre en el servidor, no
en el teléfono (el dominio `.test` no resuelve desde el dispositivo).

### B2. `/print/payload` (etiquetas) devuelve operaciones que el teléfono no puede resolver — **P1** (hallazgo 18 y pendiente 2)

**Evidencia:** la plantilla `etiqueta` produce una operación `EscribirTexto` cuyo argumento es el TSPL
completo (`SIZE`, `GAP`, `CLS`, `TEXT`, `BARCODE`, `QRCODE`, `PRINT 1,1`) y **eso** el teléfono lo envía
tal cual. Pero si la plantilla incluye una imagen, la respuesta trae
`DescargarImagenDeInternetEImprimir`, que es una operación **del plugin de escritorio**: el teléfono no
rasteriza imágenes para TSPL, así que solo puede avisar (`LabelPayload.hasUnsupportedOperations`).

**Qué se pide:** resolver las imágenes en el servidor y devolver lo que un cliente ligero puede imprimir:
`BITMAP` TSPL ya rasterizado (mono 1 bit) dentro del mismo texto, o bytes listos. Si no se va a soportar,
marcarlo explícitamente en la respuesta (p. ej. `unsupported_operations` documentado en §6) para que
ningún cliente intente lo imposible.

**Criterio de aceptación:** una etiqueta con logo se imprime **completa** desde el teléfono sin
operaciones no soportadas.

### B3. `POST /print/whatsapp-ticket` no arma el ticket de una orden de servicio — **P1** (hallazgo 16)

**Evidencia:** `PrintController::whatsappTicket` resuelve el origen con `PrintDataSourceResolver` y, si
**no** es una `Transaction`, responde `200` con `ticket: null` (`customer_phone: null`). Real:
`[live] WhatsApp service_order=3 ticket=null telefono=sin telefono`. En cambio `service_order` **sí**
funciona en `/print/bluetooth-payload` y `/print/ticket-html`, así que la inconsistencia es del endpoint.

**Qué se pide:** armar el texto de WhatsApp también para una orden de servicio (o responder un error
explícito en vez de `200` con `ticket: null`, que es lo que hace que el cliente crea que salió bien y no
tenga nada que enviar). Revisar de paso por qué el `kind` se decide con `isOrder()` de la transacción
(`data_source_type=order` devuelve `kind=sale` cuando la venta está vinculada).

**Criterio de aceptación:** `POST /print/whatsapp-ticket` con `data_source_type=order` +
`data_source_id` de una orden devuelve `ticket` no nulo y el teléfono puede abrir WhatsApp con ese texto.

### B4. `GET /print/templates` filtra por un solo `context` y la web usa conjuntos — **P1** (hallazgo 17)

**Evidencia:** los controladores web piden plantillas por `type` y **varios** contextos:
`PointOfSaleController` → `pos` + `general`; `TransactionController` → `transaction` + `general`;
`ServiceOrderController` → `service_order`; `ProductController` → `product` + `general`;
`CustomerController` → `customer` + `general`. El endpoint acepta **un** `context` por llamada, así que la
app pide todas las del tipo (`?type=…`) y filtra en el cliente. Con la suscripción de prueba (7
plantillas: tickets `general` #3 y #7, `service_order` #1 y #5) el rodeo funciona, pero `?context=pos`
—como sugiere el ejemplo del contrato— devolvería la lista **vacía** y el POS no podría imprimir.

**Qué se pide:** aceptar varios contextos (`?context[]=pos&context[]=general`, o `context=pos,general`)
**sin** romper lo actual (un solo `context` y `?type=` deben seguir funcionando igual), y corregir el
ejemplo del contrato §6 para que use el mismo conjunto que la web.

**Criterio de aceptación:** pedir `pos`+`general` devuelve la unión; pedir un solo contexto o solo `type`
devuelve exactamente lo de hoy.

### B5. El corte de caja no tiene endpoint de impresión — **P1** (hallazgo 20)

**Evidencia:** `cash_register_session` **no** es un `data_source_type` válido (§6.3), así que el corte que
el cajero cierra a diario no puede usar la plantilla del negocio: el teléfono lo arma con su propio
encoder ESC/POS (`CashCutRenderer` + CP850, la misma página de códigos que usa el servidor) y el texto de
WhatsApp se compone con el formato de los demás tickets.

**Qué se pide (decisión de negocio, no solo código):**
1. añadir `cash_register_session` como origen válido de `/print/bluetooth-payload`,
   `/print/ticket-html` y `/print/whatsapp-ticket` (con su plantilla en la web) — así el corte sale con el
   formato del negocio;
2. y/o un endpoint para **reimprimir un corte histórico** (hoy el ticket solo se puede generar al cerrar
   el turno, cuando el `summary` está en memoria).

**Criterio de aceptación:** con el nuevo tipo, el corte del turno se imprime desde el teléfono usando la
plantilla configurada; sin él, se documenta como límite aceptado.

### B6. La plantilla de etiqueta sale con el código de barras vacío — **P2** (hallazgo 19)

**Evidencia:** en la etiqueta real de la suscripción de prueba el `BARCODE` viaja sin valor:
`BARCODE 23.97,89.43,"128",30,1,0,2,2,""`. Es **la plantilla configurada**, no un campo que la app
invente (la app reimprime tal cual lo que devuelve el servidor).

**Qué se pide:** revisar la plantilla / los datos que la alimentan y rellenar el valor del código (p. ej.
folio o SKU). Opcional: exponer en la respuesta con qué valor se resolvió cada variable, para que un
cliente pueda avisar «esta etiqueta sale sin código» en vez de imprimirla incompleta en silencio.

**Criterio de aceptación:** la etiqueta de una venta de prueba sale con el código de barras con contenido.

## C. Contrato vs realidad (P2 — documentar o corregir)

### C1. `§6.1` documenta `user_id` obligatorio en `POST /cash-register-sessions` (hallazgo 1)

El contrato lo marca obligatorio, pero `OpenCashRegisterSessionRequest` real **no** lo acepta ni lo exige
(el servidor usa el usuario del token). La app no lo envía. → Quitar `user_id` del contrato (o aceptarlo
como opcional y validar que coincida con el token, si algún día debe permitirse abrir turno por otro).

### C2. El estatus de la suscripción llega en masculino (hallazgo 23)

§11b.5 documenta `activa` / `expirada` / `suspendida` (y las reglas de color hablan de esos textos), pero
el enum real (`App\Enums\SubscriptionStatus`) usa `activo` / `expirado` / `suspendido` y la respuesta real
es `"status": "activo"`. La app modela los valores **reales** y pinta `status_data.label` + `is_expired` /
`days_left`. → Alinear: o el contrato se corrige (más simple, cero riesgo para clientes existentes) o el
enum cambia (rompe a quien compare cadenas). Decidir y dejar escrito.

### C3. `§9` `POST /service-orders` y `create_customer` (hallazgos 11 y 12)

`create_customer` es `required|boolean` **siempre**, incluso cuando se elige un cliente existente, y el
ejemplo `curl` del contrato **no** lo envía (`422` «El campo create customer es obligatorio.»). La app lo
manda en todas las altas (`true`/`false`; en multipart `1`/`0`, porque Laravel no acepta la cadena
`"true"` en un campo de formulario). Además el `message` del cambio de estatus es «Estatus de la orden
actualizado correctamente.», no el «Estatus actualizado a "Terminado".» que ilustra el contrato.
→ (a) relajar a `required_without:customer_id` o `sometimes|boolean` para que el ejemplo del contrato
funcione; (b) dejar el `message` como está y corregir el ejemplo; (c) documentar que en `multipart` los
booleanos viajan `1`/`0`.

### C4. `§11b.4` `profile_photo_url` no es la foto del usuario (hallazgo 22)

La cuenta de prueba responde `has_photo: false` y aun así
`profile_photo_url: "https://ui-avatars.com/api/?name=J+A&…"` (accesor `HasProfilePhoto` de Jetstream).
El contrato lo describe como «URL de la foto», así que un cliente que confíe en ese campo pinta el avatar
de un servicio externo que no es del negocio (y en el teléfono queda como un marcador al no resolver el
host). La app decide con `has_photo`. → Documentar en §11b.4 que `profile_photo_url` puede ser un
placeholder y que **`has_photo` es el campo que decide**, o devolver `null` cuando `has_photo` es `false`
(más limpio para todos los clientes).

### C5. `§8` `GET /transactions/{id}` no expone `customer_id` en la raíz (hallazgo 6)

Solo viaja `customer: {id, name, balance, credit_limit}` o `null`, pero la web
(`TransactionCancellationModal.vue`) decide si el reembolso puede ir a saldo con `transaction.customer_id`.
La app usa `customer != null` (y `customer.id`). → Añadir `customer_id` en la raíz (más simple y
consistente) o documentar en §8 que el cliente se detecta por el objeto `customer`.

### C6. `§8` editar un pago: la API acepta 5 métodos y la web ofrece 4 (hallazgo 7)

`PUT /transactions/{id}/payments/{paymentId}` acepta los 5 métodos de `PaymentMethod` (incluye `saldo` e
`intercambio`), pero `EditPaymentModal.vue` solo ofrece 4 (sin `intercambio`). La app ofrece los 4 de la
web **más** el método actual cuando es `intercambio`, para no perderlo al guardar. → Documentar la
diferencia (o alinear la web). No es un bug, es una trampa para el próximo cliente.

### C7. `promised_at` es fecha con hora en `America/Mexico_City` (hallazgo 15)

La app la envía como `YYYY-MM-DD` (medianoche local) para que la fecha mostrada sea la elegida por el
usuario y no se corra un día por la zona horaria. → Dejarlo escrito en §9 para que ningún cliente mande
una hora y observe el desplazamiento.

### C8. El `403` de la suscripción no es `owner_only` (hallazgo 26)

`SubscriptionRequest::authorize` devuelve `false` para un empleado, así que el cuerpo es «Tu usuario no
tiene permiso para esta acción.» y **no** el `owner_only` del catálogo de códigos (§12). La app muestra el
`message` tal cual y oculta la opción del menú con `is_subscription_owner = false`, pero un cliente que
distinga «no contratado» de «sin permiso» no puede hacerlo con este código. → Corregir el authorize para
emitir el código documentado (o actualizar §12 y el catálogo).

## D. Datos y endpoints que la app necesita para cerrar funciones (P1/P2)

### D1. El historial de la suscripción no incluye el `id` del pago — **P1** (hallazgo 24, pendiente 9)

**Evidencia:** `history[].payment` trae `folio`, `status`, `paid_at` y `can_request_invoice`, pero **no**
`id`, y `POST /subscription/payments/{paymentId}/request-invoice` exige ese id. Real:
`[live] última versión: v12 … puedeFactura=true idPago=null`. La app ya tiene el método completo
(`AccountRepository.requestInvoice`, probado contra el `404` de un id inexistente) y **solo** muestra
«Solicitar factura» cuando el servidor lo incluya; mientras, el historial explica que la factura se pide
desde la web.

**Qué se pide:** añadir `id` (el del pago) a cada elemento de `history[].payment`.

**Criterio de aceptación:** con un pago aprobado y `can_request_invoice: true`, la app obtiene
`idPago != null` y puede solicitar la factura desde el teléfono (hoy es imposible: no hay camino).

### D2. Los pagos `pending`/`rejected` tampoco son facturables — **P2** (hallazgo 25)

El historial solo expone `pending_payment` / `last_rejected_payment` (esos sí traen `id`, pero no son
aprobados y el servidor responde `403 payment_not_approved`). → Con D1 esto queda resuelto para los
aprobados; conviene documentar explícitamente que **solo** un pago aprobado es facturable y con qué
código se rechaza.

### D3. `GET /notifications` no distingue por módulo contratado — **P2** (hallazgo 28)

Los cuatro contadores llegan **siempre**; `pending_orders` solo se calcula si la tienda en línea está
activa. La app pinta los cuatro y explica en «Novedades» y «Pedidos pendientes» que su gestión es de la
web, en vez de inventar pantallas. → Enviar una bandera por módulo (p. ej. `modules: { online_store:
true, … }` o `enabled` por contador) para que el cliente sepa qué ocultar sin adivinar.

### D4. `GET /transactions` acepta un solo `status` y `expiring_debts` agrupa dos — **P2** (hallazgo 29)

`expiring_debts` mezcla `apartado` **y** `pendiente`, y el listado de ventas solo acepta **un** `status`
por llamada (§8), así que «Deudas por vencer» abre el historial **sin filtro** (con el texto de la
categoría explicando qué cuenta). «Entregas próximas» sí abre filtrado por `por_entregar`. → Aceptar
varios estatus (`?status[]=apartado&status[]=pendiente`) manteniendo el `status` único actual, y decirlo en
§8.

### D5. No hay endpoint para listar los campos personalizados antes de crear una orden — **P1** (hallazgo 14)

`custom_field_definitions` solo viaja dentro del detalle (`GET /service-orders/{id}`): no existe una ruta
que liste las definiciones **antes** de dar de alta, así que la app puede capturar y editar campos
personalizados en la **edición** (donde ya conoce las definiciones) pero no en el **alta** — y no se
inventan campos. → Añadir `GET /service-orders/custom-fields` (o incluir
`custom_field_definitions` en el índice / en un `meta`), y documentarlo en §9.

**Criterio de aceptación:** la app puede dibujar los campos personalizados al crear una orden, no solo al
editarla.

### D6. `PUT /branch/switch/{id}` cambia la sucursal para **todos** los dispositivos — **P2** (hallazgo 31)

Escribe `users.branch_id`, así que el cambio **no** es solo del teléfono que lo pide: la web y los demás
dispositivos del mismo usuario ven la otra sucursal. La app lo advierte en la confirmación («Verás la
información de esa sucursal en este dispositivo, igual que en la web») y por eso la prueba real deja la
cuenta como estaba. → Decidir: (a) sucursal por sesión/token (lo que el texto sugiere), o (b) documentar
en §11b que es global y seguir así. Hoy el texto de la app es el compromiso correcto, pero depende de
esta decisión.

### D7. `POST /transactions/{id}/cancel` no acepta un motivo escrito — **P2** (hallazgo 4)

`CancelTransactionRequest` solo admite `action`, `refund_method`, `bank_account_id` y `client_uuid`, pero
el plan de trabajo pedía «cancelar/reembolsar con motivo». La app muestra una confirmación explícita (qué
pasa con el dinero, cuánto se paga, aviso de caja/cliente) y no manda ningún campo nuevo. → Si el negocio
quiere el motivo, aceptar `reason`/`notes` (opcional, guardado en la transacción) y añadirlo a §8; si no,
dejar escrito que no existe.

### D8. Lista de dispositivos con sesión abierta — **P2** (pendiente 6)

«Sesiones activas» ya permite **cerrar** las demás (`POST /profile/logout-other-devices`, con contraseña),
pero §11b.4 deja la **lista** de dispositivos (`personal_access_tokens`) para una fase posterior y la app
no la inventa. → Confirmar si entra en esta entrega (`GET /profile/sessions` con `id`, `device_name`,
`last_used_at`, `current`) o se documenta como fuera de alcance.

## E. Lo que **no** es del backend (no tocar)

| Punto | Por qué no |
|---|---|
| Constancia fiscal en **PDF** (hallazgo 27, pendiente 8) | El servidor ya acepta `pdf,jpg,jpeg,png,webp`; el stack aprobado de la app no trae selector de archivos, así que el teléfono solo sube imágenes (≤ 2 MB). El PDF se sube desde la web. **Sin acción.** |
| Respaldo **HTML** del ticket (hallazgo 21, pendiente 3) | La app lo muestra y lo copia; generar PDF o abrir la hoja de compartir requiere un paquete fuera del stack aprobado. **Sin acción.** |
| Permisos **BLE** en Android 12+ (hallazgo 32), impresora **BLE vs clásica** (33) | Del teléfono y del plugin (`flutter_blue_plus`); ya resuelto en la app. **Sin acción.** |
| **MIUI** no deja `adb input` ni `pm grant` (hallazgo 34) | Restricción del equipo de pruebas. **Sin acción.** |
| **Medios por el túnel** (hallazgo 36) e **identidad visual** (37) | Corregido en la app (`ServerImage`, `BrandLogo`, ícono). Ojo: el hallazgo 36 significa que **cualquier URL absoluta al host `.test` en una respuesta no se puede cargar desde el teléfono**; si el backend añade campos con URLs, conviene documentar que el cliente debe reescribir el origen. |
| Fase **offline** (pendiente 5) y contraseñas reales (7) | Fuera del alcance de esta entrega (requiere base local / entorno desechable). |
| `PUT /profile` acepta JSON **y** multipart (hallazgo 30) | El contrato exige `multipart/form-data` pero la API acepta JSON cuando no hay foto (verificado: `200` con el mismo `message`). → Solo **documentarlo** en §11b (la app envía multipart solo con foto). |

## F. Orden de trabajo sugerido

1. **Reconocimiento (sin tocar código).** Leer `01-contrato-api-v1.md` (§6, §6.1, §6.3, §7, §7.2, §7.3, §8,
   §9, §11b.4, §11b.5, §12). Ubicar y leer los archivos citados aquí (`TransactionPaymentEditService`,
   `TransactionPaymentService::applyPaymentToTransaction`, `DeleteServiceOrderAction`,
   `PrintController`, `PrintDataSourceResolver`, `PrintEncoderService`, `SubscriptionRequest::authorize`,
   `App\Enums\SubscriptionStatus`, `OpenCashRegisterSessionRequest`, `CancelTransactionRequest`,
   `ShoppingCart.vue`, `TransactionCancellationModal.vue`, `EditPaymentModal.vue`) y **correr la suite de
   pruebas existente** para guardar la línea base (comando real del repo: `php artisan test`, `composer
   test` o el que traiga `composer.json`).
2. **P0 de dinero, uno por punto, en este orden: A1 → A2 → A3 → A4 → A5 → A6.** Cada uno: prueba que
   reproduce el fallo (en rojo), arreglo, prueba en verde, commit atómico. Si un punto necesita decisión
   de negocio (A3, A4, A6), **preguntar antes** de cambiar semántica.
3. **P1 de impresión: B1 → B3 → B4 → B2** (B1 es el que más valor tiene: el logo del ticket).
4. **P1 de datos: D1 → D5.**
5. **P2 de contrato: C1-C8 en un solo commit de documentación** + el punto de `PUT /profile` de la
   sección E. Sin cambios de comportamiento: o se corrige el contrato, o se corrige el código, pero
   nunca se dejan los dos diciendo cosas distintas.
6. **P2 restantes (D2-D8)** según la decisión que se tome; los que queden fuera se documentan como
   «fuera de alcance» en el contrato, no en silencio.
7. **Cierre:** volver a correr la suite completa y entregar el reporte.

## G. Reglas del encargo

- **Un punto = un commit.** Mensajes en español, en el estilo del repo (`Endpoint: qué se arregla y por
  qué`), con la evidencia en el cuerpo.
- **Prueba primero:** ningún cambio de comportamiento sin una prueba automatizada que falle antes y pase
  después. Los P0 (dinero) necesitan prueba de integración con la base de datos, no solo unitaria.
- **No romper la web:** antes de cambiar semántica, revisar los consumidores web citados en el punto
  (los controladores y modales de Vue). Si el arreglo cambia lo que la web recibe, ajustarla en el mismo
  commit.
- **Contrato y código siempre de acuerdo:** todo cambio de request/response se refleja en
  `01-contrato-api-v1.md` en el mismo commit (campos, tipos, códigos de error, ejemplos).
- **Respuestas consistentes:** `message` en español para el usuario final, `errors` por campo en los
  `422`, y los `code` del catálogo §12 cuando el flujo lo necesite.
- **Nada a medias:** sin migraciones sin correr, sin `dd()`/`dump()`, sin archivos temporales, sin
  dependencias nuevas sin justificar.
- **Si algo no se puede hacer**, decirlo con la razón y proponer la alternativa — no dejar el punto
  «silenciosamente» hecho a medias.

## H. Reporte final (formato pedido)

| Punto | Estado | Archivos (código / contrato / pruebas) | Commit | Evidencia |
|---|---|---|---|---|
| A1 | hecho / preguntado / fuera de alcance | … | `abc1234` | prueba que fallaba antes y pasa ahora, salida de `php artisan test` |
| … | | | | |

Y al final: qué quedó **sin** hacer, qué **decisiones** esperan respuesta del negocio, y el comando exacto
que el equipo móvil debe correr para revalidar cada punto en el teléfono (§0).









