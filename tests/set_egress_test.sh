#!/usr/bin/env bash
# JIUHEYI_SET_EGRESS=direct：AimiliVPN 卸载时不进菜单调用，与菜单 11「卸载Socks5出站」一致。
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

grep -q '^if \[\[ -n "${JIUHEYI_SET_EGRESS:-}" \]\]; then$' "$script"
awk '
    /^removeXrayOutbound\(\)/ {p=1}
    /^addSingBoxWireGuardEndpoints\(\)|^# 初始化wireguard出站信息/ {p=0}
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
    /^jiuheyiSingboxMemLimit\(\)/ {r=0}
    r {print}
' "$script" | sed -e "s#/etc/v2ray-agent#$work/etc#g" -e "s#/opt/aimilivpn#$work/opt#g" >"$work/fns.sh"

echoContent() { shift; printf '%s\n' "$*"; }
jiuheyiXrayQueryStrategy() { printf 'UseIPv4'; }
jiuheyiPolicyJson() { printf '{}'; }
aimiliSocksAuthJson() { aimiliSocksUserJson='"socks5"'; aimiliSocksPassJson='"x"'; }
addXrayOutbound() { printf '{"outbounds":[{"protocol":"freedom","tag":"%s"}]}\n' "$1" >"${configPath:-$work/etc/xray/conf/}$1.json"; }
addSingBoxOutbound() { printf '{"outbounds":[{"type":"direct","tag":"%s"}]}\n' "$1" >"$work/etc/sing-box/conf/config/$1.json"; }
installAimiliDefaultOutbound() { printf '{"outbounds":[{"type":"socks","tag":"socks5_outbound","server":"127.0.0.1","server_port":8500}]}\n' >"$work/etc/sing-box/conf/config/socks5_outbound.json"; }
reloadCore() { echo reload >>"$work/reloads"; [[ -d "$work/etc/sing-box/conf/config" ]] && echo '{}' >"$work/etc/sing-box/conf/config.json"; return 0; }
# shellcheck disable=SC1091
source "$work/fns.sh"
type jiuheyiSetEgress >/dev/null
readInstallType() { :; }

xc="$work/etc/xray/conf"; sb="$work/etc/sing-box/conf/config"
no8500() { ! grep -rqs --include='*.json' '127.0.0.1.\{0,8\}8500\|"server_port": *8500\|"port": *8500' "$work/etc/xray/conf" "$work/etc/sing-box/conf"; }
reset() { rm -rf "$work/etc" "$work/reloads"; mkdir -p "$xc" "$sb"; }

# 1. Xray 全局（联合安装）
reset; coreInstallType=1; configPath="$xc/"; singBoxConfigPath=""
printf 'global\n' >"$work/etc/jiuheyi_dns_mode"
echo '{"dns":{"queryStrategy":"UseIPv6","servers":[{"address":"1.1.1.1","detour":"socks5_outbound"}]}}' >"$xc/00_dns.json"
echo '{"outbounds":[{"protocol":"socks","tag":"socks5_outbound","settings":{"servers":[{"address":"127.0.0.1","port":8500}]}}]}' >"$xc/zz_socks5_outbound.json"
echo '{"routing":{"rules":[{"type":"field","network":"tcp,udp","outboundTag":"socks5_outbound"}]}}' >"$xc/zz_egress.json"
echo '{"routing":{"rules":[]}}' >"$xc/09_routing.json"
jiuheyiSetEgress direct
[[ ! -e "$xc/zz_socks5_outbound.json" && ! -e "$xc/zz_egress.json" ]]
[[ "$(cat "$work/etc/jiuheyi_dns_mode")" == direct ]]
jq -e '.dns.queryStrategy=="UseIPv4"' "$xc/00_dns.json" >/dev/null
! grep -q socks5_outbound "$xc/00_dns.json"
[[ -f "$xc/z_direct_outbound.json" ]]
jq -e '.routing.rules|length>0' "$xc/09_routing.json" >/dev/null   # 回环规则已补
[[ -s "$work/reloads" ]]; no8500

# 2. Xray 指定域名（菜单 socks5_outbound.json + 09_routing 域名规则）
reset; printf 'socks5\n' >"$work/etc/jiuheyi_dns_mode"
echo '{"outbounds":[{"protocol":"socks","tag":"socks5_outbound","settings":{"servers":[{"address":"127.0.0.1","port":8500}]}}]}' >"$xc/socks5_outbound.json"
echo '{"routing":{"rules":[{"type":"field","domain":["example.com"],"outboundTag":"socks5_outbound"}]}}' >"$xc/09_routing.json"
jiuheyiSetEgress direct
[[ ! -e "$xc/socks5_outbound.json" ]]
! jq -e '.routing.rules[]|select(.outboundTag=="socks5_outbound")' "$xc/09_routing.json" >/dev/null
jq -e '.dns.queryStrategy' "$xc/00_dns.json" >/dev/null
no8500

# 3. sing-box 全局（带 .global 标记）
reset; coreInstallType=2; configPath=""; singBoxConfigPath="$sb/"
printf 'global\n' >"$work/etc/jiuheyi_dns_mode"
installAimiliDefaultOutbound; : >"$sb/socks5_outbound.global"
jiuheyiSetEgress direct
[[ ! -e "$sb/socks5_outbound.json" && ! -e "$sb/socks5_outbound.global" ]]
[[ -f "$sb/01_direct_outbound.json" ]]
no8500

# 4. sing-box 指定域名
reset; printf 'socks5\n' >"$work/etc/jiuheyi_dns_mode"
installAimiliDefaultOutbound
echo '{"route":{"rules":[{"domain":["example.com"],"outbound":"socks5_outbound"}]}}' >"$sb/socks5_01_outbound_route.json"
jiuheyiSetEgress direct
[[ ! -e "$sb/socks5_outbound.json" && ! -e "$sb/socks5_01_outbound_route.json" ]]
[[ -f "$sb/01_direct_outbound.json" ]]
no8500

# 5. 仍有 8500 出站 → 非 0
reset; coreInstallType=1; configPath="$xc/"; singBoxConfigPath=""
echo '{"outbounds":[{"protocol":"socks","tag":"other","settings":{"servers":[{"address":"127.0.0.1","port":8500}]}}]}' >"$xc/30_other.json"
if jiuheyiSetEgress direct; then echo "should fail"; exit 1; fi
# 6. 未知取值 → 非 0
if jiuheyiSetEgress bogus; then echo "should fail"; exit 1; fi
# 7. 全局（兼容 oneclick）
reset; jiuheyiSetEgress global
[[ -f "$xc/zz_socks5_outbound.json" && "$(cat "$work/etc/jiuheyi_dns_mode")" == global ]]

echo "set egress ok"
