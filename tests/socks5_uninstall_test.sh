#!/usr/bin/env bash
# 菜单 11 卸载 Socks5 出站：全局分流在 zz_*，不能只删 socks5_outbound.json。
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

awk '
    /^removeXrayOutbound\(\)/ {p=1}
    /^removeSingBoxConfig\(\)/ {p=0}
    p {print}
    /^unInstallRouting\(\)/ {u=1}
    /^unInstallSniffing\(\)/ {u=0}
    u {print}
    /^jiuheyiRemoveSocks5Outbound\(\)/ {s=1}
    /^removeSocks5Routing\(\)/ {s=0}
    s {print}
    /^jiuheyiApplyDnsMode\(\)/ {q=1}
    /^jiuheyiTuneXray\(\)/ {q=0}
    q {print}
    /^jiuheyiRealityLoopbackRule\(\)/ {r=1}
    /^jiuheyiMemoryTune\(\)/ {r=0}
    r {print}
' "$script" | sed -e "s#/etc/v2ray-agent#$work/etc#g" -e "s#/opt/aimilivpn#$work/opt#g" >"$work/fns.sh"

echoContent() { shift; printf '%s\n' "$*"; }
jiuheyiXrayQueryStrategy() { printf 'UseIPv4'; }
jiuheyiPolicyJson() { printf '{}'; }
addXrayOutbound() { printf '%s\n' "$1" >>"$work/added"; }
addSingBoxOutbound() { printf '%s\n' "$1" >>"$work/added-sb"; }
# shellcheck disable=SC1091
source "$work/fns.sh"

conf="$work/etc/xray/conf"
mkdir -p "$conf" "$work/etc/sing-box/conf/config"
coreInstallType=1
configPath="${conf}/"
singBoxConfigPath=""
export coreInstallType configPath singBoxConfigPath

# 全局分流：zz_* + 模式 global。卸载后文件没了，模式改为 direct，更新不会写回。
printf '%s\n' global >"$work/etc/jiuheyi_dns_mode"
printf '%s\n' '{"outbounds":[{"protocol":"socks","tag":"socks5_outbound","settings":{"servers":[{"address":"127.0.0.1","port":8500,"users":[{"user":"socks5","pass":"ilovestudy"}]}]}}]}' >"$conf/zz_socks5_outbound.json"
printf '%s\n' '{"routing":{"domainStrategy":"AsIs","rules":[{"type":"field","network":"tcp,udp","outboundTag":"socks5_outbound"}]}}' >"$conf/zz_egress.json"
printf '%s\n' '{"routing":{"rules":[{"type":"field","network":"tcp,udp","outboundTag":"socks5_outbound"}]}}' >"$conf/09_routing.json"
printf '%s\n' '{"outbounds":[{"protocol":"socks","tag":"socks5_outbound"}]}' >"$conf/socks5_outbound.json"
printf '%s\n' '{"outbounds":[{"type":"socks","tag":"socks5_outbound","server":"127.0.0.1","server_port":8500}]}' >"$work/etc/sing-box/conf/config/socks5_outbound.json"

jiuheyiRemoveSocks5Outbound

[[ ! -e "$conf/zz_socks5_outbound.json" ]]
[[ ! -e "$conf/zz_egress.json" ]]
[[ ! -e "$conf/socks5_outbound.json" ]]
[[ ! -e "$work/etc/sing-box/conf/config/socks5_outbound.json" ]]
[[ "$(tr -d '[:space:]' <"$work/etc/jiuheyi_dns_mode")" == "direct" ]]
[[ -f "$work/etc/xray/conf/00_dns.json" ]]
grep -q 'socks5_outbound' "$work/etc/xray/conf/00_dns.json" && { echo "dns still detours to socks5"; exit 1; }
jq -e '.routing.rules[]?|select(.outboundTag=="socks5_outbound")' "$conf/09_routing.json" >/dev/null 2>&1 && { echo "09_routing still has socks5"; exit 1; }
grep -qx z_direct_outbound "$work/added"

# 只有菜单安装的出站、没有全局分流：删出站，不改 DNS 模式。
rm -f "$work/added" "$work/etc/xray/conf/00_dns.json"
printf '%s\n' direct >"$work/etc/jiuheyi_dns_mode"
printf '%s\n' '{"outbounds":[{"protocol":"socks","tag":"socks5_outbound"}]}' >"$conf/socks5_outbound.json"
cp "$conf/socks5_outbound.json" "$work/before-dns" || true
jiuheyiRemoveSocks5Outbound
[[ ! -e "$conf/socks5_outbound.json" ]]
[[ "$(tr -d '[:space:]' <"$work/etc/jiuheyi_dns_mode")" == "direct" ]]
[[ ! -e "$work/etc/xray/conf/00_dns.json" ]]

echo "socks5 uninstall ok"
