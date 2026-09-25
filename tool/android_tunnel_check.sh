#!/system/bin/sh
# Verifica desde el TELEFONO que el tunel USB (adb reverse tcp:8443 tcp:443)
# llega a la API local. Se sube y se ejecuta asi:
#
#   adb push tool/android_tunnel_check.sh /data/local/tmp/
#   adb shell sh /data/local/tmp/android_tunnel_check.sh correo@negocio.com 'secreto'
#
# Ojo: Herd elige el sitio por el header `Host`, asi que la API responde 404
# (el HTML "Site not found" de Herd) si no se manda el Host del vhost.
# Es `mksh` (no bash): sin `set -u` y con `printf` en lugar de `echo -n`.

EMAIL="${1:-}"
PASSWORD="${2:-}"

BASE='https://127.0.0.1:8443/api/v1'
HOST_HEADER='ezyventas2.test'

printf '== tunel: %s con Host: %s ==\n' "$BASE" "$HOST_HEADER"

printf 'sin Host (Herd no sabe que sitio es): '
curl -sk -o /dev/null -w '%{http_code}\n' "$BASE/auth/me"

printf 'con Host, sin token (la API contesta): '
curl -sk -o /dev/null -w '%{http_code}\n' -H "Host: $HOST_HEADER" "$BASE/auth/me"

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  printf 'sin credenciales: no se prueba el login\n'
  exit 0
fi

printf 'login real: '
curl -sk -o /tmp/login.json -w '%{http_code}\n' \
  -X POST -H "Host: $HOST_HEADER" -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"device_name\":\"QA tunel USB\"}" \
  "$BASE/auth/login"

# Solo se imprime lo que interesa del cuerpo (sin el token completo).
head -c 400 /tmp/login.json | tr ',' '\n' | grep -E '"(name|email|is_subscription_owner|message)"' | head -5
rm -f /tmp/login.json
