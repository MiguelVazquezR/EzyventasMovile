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
flutter test        # 46 tests: dinero, errores, sesion, permisos y login
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
con 25 ms de pausa (etapa de impresion).

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
  - api/         dio, interceptores, ApiException, endpoints, providers
  - auth/        SessionStore, PermissionsService, AppTab
  - config/      AppConfig (API_BASE_URL, timeouts, locale)
  - router/      go_router + StatefulShellRoute
  - theme/       Tesla UI: colores, tipografia, tema, severidades
  - utils/       Money, AppFormatters, JsonReader, StatusCatalog, Uuid
  - widgets/     FieldLabel, EzyTextField, EzyButton, SectionCard, ...
- features/
  - auth/        login, splash, modelos de sesion, repositorio, controlador
  - account/     pestana Cuenta
  - cash/        sesion de caja (capa de datos lista para la etapa 3)
  - pos/         pestana Vender
  - sales/       pestana Ventas
  - service_orders/
  - shell/       cascaron de 5 pestanas
```