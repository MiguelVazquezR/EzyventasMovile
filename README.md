# EzyVentas - app movil (Flutter / Android)

Cliente Android de **EzyVentas**: punto de venta y ordenes de servicio contra la API REST
`/api/v1` del backend Laravel. Esta entrega es el **modo online** (todo se resuelve contra el
servidor). La fase offline (SQLite + cola de sincronizacion) **no** esta implementada: la capa
de datos ya esta aislada para anadirla sin reescribir la UI.

---

## 1. Como correr el proyecto

Requisitos: Flutter 3.47+ (Dart 3.13) y Android SDK con `minSdk 23`.

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
flutter test        # 82 tests: dinero, errores, sesión, permisos, catálogo, caja y cobro
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
```

---

## 2. Credenciales de prueba

| Rol | Uso |
|---|---|
| Propietario de negocio (usuario **sin roles**) | Flujo completo: todas las pestanas |
| Empleado con `pos.access` + `transactions.access` | Valida `403` y el ocultado de pestanas |

Las contrasenas **no** se guardan en el repositorio: se capturan en la pantalla de login.
**Nunca** se usa `ezyventas@gmail.com` (superadmin id 1): su bypass de permisos oculta errores
reales.

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

### Impresora termica
Se selecciona por Bluetooth con `flutter_blue_plus` y se recuerda el dispositivo; los bytes
ESC/POS llegan ya en Base64 desde `/print/bluetooth-payload` y se envian en bloques de 20 bytes
con 25 ms de pausa. **Aun no implementado**: la etapa de impresion (tickets, etiquetas, WhatsApp y
el ticket del corte) llega en la etapa 6; por eso el cobro y el corte solo muestran el folio y los
totales.

### Discrepancias del contrato detectadas (etapa 3)
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

---

## 4. Notas del entorno de desarrollo (Windows)

Si la ruta del usuario o del SDK tiene **espacios** (`C:\Users\windows 11\...`), el constructor
de *native assets* de Flutter falla al compilar el hook del paquete `objective_c` (dependencia de
`path_provider_foundation`, solo Apple):

```
"C:\Users\windows" no se reconoce como un comando interno o externo
Building native assets for package:objective_c failed.
```

Afecta a `flutter test` y a `flutter build`. Solucion local (sin tocar el proyecto):

```powershell
# 1) cache de pub sin espacios
$env:PUB_CACHE = 'C:\pubcache'

# 2) junctions a rutas sin espacios
New-Item -ItemType Junction -Path 'C:\flutter' -Target 'C:\Users\windows 11\Desktop\flutter'
New-Item -ItemType Junction -Path 'C:\ezv' -Target 'C:\Users\windows 11\Desktop\Apps moviles\ezyventas_app'

# 3) ejecutar desde el junction
cd C:\ezv
cmd /c "set PUB_CACHE=C:\pubcache && C:\flutter\bin\flutter.bat test"
```

En una ruta sin espacios, `flutter test` funciona sin nada de esto.

---

## 5. Estructura

```
lib/
- main.dart / app.dart
- core/
  - api/         dio, interceptores, ApiException (message/errors/code/details), endpoints, providers
  - auth/        SessionStore, PermissionsService, AppTab
  - config/      AppConfig (API_BASE_URL, timeouts, locale)
  - router/      go_router + StatefulShellRoute
  - theme/       Tesla UI: colores, tipografia, tema, severidades
  - utils/       Money, AppFormatters, JsonReader, StatusCatalog, Uuid
  - widgets/     FieldLabel, EzyTextField, MoneyField, EzyButton, SectionCard, ...
- features/
  - auth/        login, splash, modelos de sesion, repositorio, controlador
  - account/     pestana Cuenta
  - cash/        turno de caja: modelos, repositorio, controlador, apertura y corte (etapa 3)
  - catalog/     catalogo, detalle de producto y alta rapida al carrito
  - customers/   clientes + buscador del cobro
  - pos/         pestana Vender: carrito, cobro, apartado y pedido (etapa 3)
  - sales/       pestana Ventas (etapa 4)
  - service_orders/
  - shell/       cascaron de 5 pestanas
```