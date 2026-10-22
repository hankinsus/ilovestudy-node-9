#!/usr/bin/env bash
# 规则列表：IP 白名单插到屏蔽规则前面。
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

grep -q '15.规则列表' "$script"
grep -q '5.添加IP白名单' "$script"
grep -q '7.卸载屏蔽域名IP' "$script"
grep -q '8.卸载白名单域名IP' "$script"
grep -q '9.卸载全部' "$script"

awk '
    /^addXrayIPRouting\(\)/ {p=1}
    /^# 添加 sing-box IP 屏蔽路由规则/ {p=0}
    p
    /^unInstallRouting\(\)/ {q=1}
    /^# 卸载嗅探/ {q=0}
    q
' "$script" >"$work/fns.sh"
mkdir -p "$work/xray"
cat >>"$work/fns.sh" <<EOF
echoContent() { :; }
configPath="$work/xray/"
printf '%s\n' '{"routing":{"rules":[{"type":"field","ip":["geoip:cn"],"outboundTag":"blackhole_ip_out"}]}}' >"\$configPath/09_routing.json"
addXrayIPRouting allow_ip_direct_outbound outboundTag "1.1.1.1" top
[[ "\$(jq -r '.routing.rules[0].outboundTag' "\$configPath/09_routing.json")" == "allow_ip_direct_outbound" ]]
[[ "\$(jq -r '.routing.rules[0].ip[0]' "\$configPath/09_routing.json")" == "1.1.1.1" ]]
[[ "\$(jq -r '.routing.rules[1].outboundTag' "\$configPath/09_routing.json")" == "blackhole_ip_out" ]]
EOF
bash "$work/fns.sh"

echo "rule list ok"
