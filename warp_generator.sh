#!/bin/bash

# ==============================
# WARP Config Generator + Relay
# Relay: 83.143.112.121
# ==============================

RELAY_IP="83.143.112.121"
RELAY_PORT="2408"

# Проверка зависимостей
for dep in curl jq wg; do
  if ! command -v $dep &>/dev/null; then
    echo "[ERROR] Не найден: $dep — установите его и повторите"
    exit 1
  fi
done

priv="$(wg genkey | tr -d '\n')"
pub="$(printf "%s" "${priv}" | wg pubkey | tr -d '\n')"
api="https://api.cloudflareclient.com/v0i1909051800"

ins() { curl -s -H 'User-Agent: okhttp/3.12.1' -H 'Content-Type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "Authorization: Bearer $3" "${@:4}"; }

echo "[*] Регистрируем аккаунт WARP..."
response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%TZ)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")

id=$(echo "$response" | jq -r '.result.id')
token=$(echo "$response" | jq -r '.result.token')

if [ "$id" = "null" ] || [ -z "$id" ] || [ "$token" = "null" ] || [ -z "$token" ]; then
  echo "[ERROR] Регистрация не удалась:"
  echo "$response" | jq .
  exit 1
fi

echo "[*] Активируем WARP..."
response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')

peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')
client_ipv4=$(echo "$response" | jq -r '.result.config.interface.addresses.v4')
client_ipv6=$(echo "$response" | jq -r '.result.config.interface.addresses.v6')

if [ "$peer_pub" = "null" ] || [ -z "$peer_pub" ]; then
  echo "[ERROR] Не удалось получить данные от WARP"
  exit 1
fi

echo "[*] Генерируем конфиг с relay ${RELAY_IP}:${RELAY_PORT}..."

conf=$(cat <<-EOM
[Interface]
PrivateKey = ${priv}
S1 = 0
S2 = 0
Jc = 120
Jmin = 23
Jmax = 911
H1 = 1
H2 = 2
H3 = 3
H4 = 4
MTU = 1280
Address = ${client_ipv4}, ${client_ipv6}
DNS = 1.1.1.1, 2606:4700:4700::1111, 1.0.0.1, 2606:4700:4700::1001

[Peer]
PublicKey = ${peer_pub}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${RELAY_IP}:${RELAY_PORT}
EOM
)

echo ""
echo "✅ Готово!"
echo "=================================="
echo "${conf}"
echo "=================================="

conf_base64=$(echo -n "${conf}" | base64 -w 0)
echo ""
echo "📥 Скачать конфиг файлом:"
echo "https://immalware.vercel.app/download?filename=WARP.conf&content=${conf_base64}"
echo ""
echo "📌 Endpoint: ${RELAY_IP}:${RELAY_PORT} (через relay)"
echo "⚠️  Импортируйте в AmneziaVPN (не AmneziaWG!)"
