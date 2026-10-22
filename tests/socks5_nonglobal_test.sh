#!/usr/bin/env bash
# 联合安装：只有 socks5 出站、没有域名分流文件，route.final 仍指向 socks5。
# 非全局：有 socks5_01_outbound_route.json 时不再设 final。zz_egress 去掉 tcp,udp 全走。
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

awk '
    /^jiuheyiSingboxSocks5IsGlobal\(\)/ {p=1}
    /^setStrategyRouting\(\)/ {p=0}
    p
    /^jiuheyiApplySocks5DomainRules\(\)/ {q=1}
    /^setSocks5OutboundRouting\(\)/ {q=0}
    q
' "$script" | sed "s#/etc/v2ray-agent#$work/etc#g" >"$work/fns.sh"
# shellcheck disable=SC1091
source "$work/fns.sh"

mkdir -p "$work/etc/sing-box/conf/config" "$work/etc/xray/conf"
printf '%s\n' '{"outbounds":[{"type":"socks","tag":"socks5_outbound","server":"127.0.0.1","server_port":8500,"version":"5","username":"socks5","password":"ilovestudy"}]}' >"$work/etc/sing-box/conf/config/socks5_outbound.json"
unset JIUHEYI_EGRESS || true
jiuheyiSingboxSocks5IsGlobal
setSniffRouting
grep -q '"final": "socks5_outbound"' "$work/etc/sing-box/conf/config/sniff.json"

printf '%s\n' '{"route":{"rules":[{"outbound":"socks5_outbound"}]}}' >"$work/etc/sing-box/conf/config/socks5_01_outbound_route.json"
if jiuheyiSingboxSocks5IsGlobal; then
    echo "domain route still treated as global"
    exit 1
fi
setSniffRouting
grep -q '"final"' "$work/etc/sing-box/conf/config/sniff.json" && { echo "non-global still sets final"; exit 1; }

configPath="$work/etc/xray/conf/"
export configPath
printf '%s\n' '{"routing":{"rules":[{"type":"field","ip":["127.0.0.0/8"],"outboundTag":"z_direct_outbound"},{"type":"field","network":"tcp,udp","outboundTag":"socks5_outbound"}]}}' >"$work/etc/xray/conf/zz_egress.json"
printf '%s\n' '{"dns":{"queryStrategy":"UseIPv4","servers":[{"address":"1.1.1.1","detour":"socks5_outbound"}]}}' >"$work/etc/xray/conf/00_dns.json"
mkdir -p "$work/etc"
printf '%s\n' global >"$work/etc/jiuheyi_dns_mode"
jiuheyiApplySocks5DomainRules '["geosite:netflix"]'
jq -e '.routing.rules[]|select(.network=="tcp,udp" and .outboundTag=="socks5_outbound")' "$work/etc/xray/conf/zz_egress.json" >/dev/null && { echo "catch-all remains"; exit 1; }
[[ "$(jq -r '.routing.rules[-1].domain[0]' "$work/etc/xray/conf/zz_egress.json")" == "geosite:netflix" ]]
[[ "$(jq -r '.routing.rules[0].outboundTag' "$work/etc/xray/conf/zz_egress.json")" == "z_direct_outbound" ]]
jq -e '.dns.servers[]?|select(type=="object" and .detour=="socks5_outbound")' "$work/etc/xray/conf/00_dns.json" >/dev/null && { echo "dns still detours"; exit 1; }
[[ "$(tr -d '[:space:]' <"$work/etc/jiuheyi_dns_mode")" == "socks5" ]]

awk '
    /^jiuheyiXraySocks5IsGlobal\(\)/ {p=1}
    /^# xray内核分流规则/ {p=0}
    p
' "$script" >"$work/global.sh"
# shellcheck disable=SC1091
source "$work/global.sh"
printf '%s\n' '{"routing":{"rules":[{"type":"field","domain":["example.com"],"outboundTag":"socks5_outbound"}]}}' >"$work/etc/xray/conf/09_routing.json"
printf '%s\n' '{"routing":{"rules":[{"type":"field","network":"tcp,udp","outboundTag":"socks5_outbound"}]}}' >"$work/etc/xray/conf/zz_egress.json"
jiuheyiXraySocks5IsGlobal
rm -f "$work/etc/xray/conf/09_routing.json"
jiuheyiXraySocks5IsGlobal
printf '%s\n' '{"routing":{"rules":[{"type":"field","domain":["example.com"],"outboundTag":"socks5_outbound"}]}}' >"$work/etc/xray/conf/zz_egress.json"
if jiuheyiXraySocks5IsGlobal; then
    echo "domain-only zz_egress marked global"
    exit 1
fi

echo "socks5 nonglobal ok"
