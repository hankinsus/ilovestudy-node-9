#!/usr/bin/env bash
# 8500 出站账号：有 AimiliVPN 的 proxy_auth.json 就用它，没有就用 socks5 / ilovestudy；Xray 和 sing-box 都一样，UDP 也走 8500。
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

awk '
    /^aimiliSocksAuthJson\(\)/ {p=1}
    /^tuneJiuheyiRuntime\(\)/ {p=0}
    p {print}
    /^jiuheyiApplyDnsMode\(\)/ {q=1}
    /^jiuheyiTuneXray\(\)/ {q=0}
    q {print}
' "$script" | sed -e "s#/etc/v2ray-agent#$work/etc#g" -e "s#/opt/aimilivpn#$work/opt#g" >"$work/fns.sh"

jiuheyiSingboxDomainStrategy() { printf 'prefer_ipv4'; }
jiuheyiXrayQueryStrategy() { printf 'UseIPv4'; }
jiuheyiPolicyJson() { printf '{}'; }
JIUHEYI_EGRESS=aimili
export JIUHEYI_EGRESS
# shellcheck disable=SC1091
source "$work/fns.sh"

sb="$work/etc/sing-box/conf/config/socks5_outbound.json"
xr="$work/etc/xray/conf/zz_socks5_outbound.json"
eg="$work/etc/xray/conf/zz_egress.json"

check() {
    local want_user="$1" want_pass="$2"
    installAimiliDefaultOutbound
    jiuheyiApplyDnsMode global
    [[ "$(jq -r '.outbounds[0].username' "$sb")" == "$want_user" ]]
    [[ "$(jq -r '.outbounds[0].password' "$sb")" == "$want_pass" ]]
    [[ "$(jq -r '.outbounds[0].server_port' "$sb")" == "8500" ]]
    [[ "$(jq -r '.outbounds[0].domain_strategy' "$sb")" == "prefer_ipv4" ]]
    [[ "$(jq -r '.outbounds[0].settings.servers[0].users[0].user' "$xr")" == "$want_user" ]]
    [[ "$(jq -r '.outbounds[0].settings.servers[0].users[0].pass' "$xr")" == "$want_pass" ]]
    [[ "$(jq -r '.outbounds[0].settings.servers[0].port' "$xr")" == "8500" ]]
    [[ "$(jq -r '.routing.rules[-1].network + " " + .routing.rules[-1].outboundTag' "$eg")" == "tcp,udp socks5_outbound" ]]
}

check socks5 ilovestudy
echo "default account ok"

mkdir -p "$work/opt/vpngate_data"
# shellcheck disable=SC2016
printf '%s' '{"user": "alice", "password": "p\"w$x"}' >"$work/opt/vpngate_data/proxy_auth.json"
# shellcheck disable=SC2016
check alice 'p"w$x'
echo "panel account ok"

printf '%s' '{"user": "", "password": ""}' >"$work/opt/vpngate_data/proxy_auth.json"
check socks5 ilovestudy
echo "empty file falls back ok"
echo "aimili_socks_auth_test passed"
