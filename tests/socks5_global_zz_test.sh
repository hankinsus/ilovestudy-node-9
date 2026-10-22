#!/usr/bin/env bash
# 菜单「设置 Socks5 全局转发」把填写的落地机写进 zz_socks5_outbound.json，并让 zz_egress 走它。
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

awk '
    /^jiuheyiWriteXraySocks5Global\(\)/ {p=1}
    /^setSocks5OutboundRoutingAll\(\)/ {p=0}
    p
' "$script" | sed "s#/etc/v2ray-agent#$work/etc#g" >"$work/fns.sh"
addXrayOutbound() { printf '%s\n' "$1" >"$work/added"; }
jiuheyiXrayQueryStrategy() { printf '%s' UseIPv4; }
jiuheyiRealityLoopbackRule() { printf '%s' '{"type":"field","ip":["127.0.0.0/8"],"outboundTag":"z_direct_outbound"}'; }
# shellcheck disable=SC1091
source "$work/fns.sh"

mkdir -p "$work/etc/xray/conf"
printf '%s\n' global >"$work/etc/jiuheyi_dns_mode"
printf '%s\n' '{}' >"$work/etc/xray/conf/socks5_outbound.json"
coreInstallType=1
configPath="$work/etc/xray/conf/"
socks5RoutingOutboundIP=127.0.0.1
socks5RoutingOutboundPort=8500
socks5RoutingOutboundUserName=socks5
socks5RoutingOutboundPassword='ilovestudy'
export coreInstallType configPath socks5RoutingOutboundIP socks5RoutingOutboundPort socks5RoutingOutboundUserName socks5RoutingOutboundPassword

jiuheyiWriteXraySocks5Global

[[ ! -e "$work/etc/xray/conf/socks5_outbound.json" ]]
[[ "$(jq -r '.outbounds[0].settings.servers[0].address' "$work/etc/xray/conf/zz_socks5_outbound.json")" == "127.0.0.1" ]]
[[ "$(jq -r '.outbounds[0].settings.servers[0].port' "$work/etc/xray/conf/zz_socks5_outbound.json")" == "8500" ]]
[[ "$(jq -r '.outbounds[0].settings.servers[0].users[0].user' "$work/etc/xray/conf/zz_socks5_outbound.json")" == "socks5" ]]
[[ "$(jq -r '.outbounds[0].settings.servers[0].users[0].pass' "$work/etc/xray/conf/zz_socks5_outbound.json")" == "ilovestudy" ]]
[[ "$(jq -r '.routing.rules[-1].network + " " + .routing.rules[-1].outboundTag' "$work/etc/xray/conf/zz_egress.json")" == "tcp,udp socks5_outbound" ]]
[[ "$(jq -r '.dns.servers[-1].detour' "$work/etc/xray/conf/00_dns.json")" == "socks5_outbound" ]]
[[ "$(tr -d '[:space:]' <"$work/etc/jiuheyi_dns_mode")" == "socks5" ]]
[[ "$(cat "$work/added")" == "z_direct_outbound" ]]

echo "socks5 global zz ok"
