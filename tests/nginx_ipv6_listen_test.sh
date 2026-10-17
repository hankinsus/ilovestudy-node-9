#!/usr/bin/env bash
# nginx 对外端口（VMess HTTPUpgrade、订阅）同时监听 IPv4 和 IPv6；已装机器更新时补上，nginx -t 不过就还原
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fn() { sed -n "/^$1() {/,/^}/p" "$script"; }
{ echo 'echoContent() { shift; echo "$*"; }'; fn jiuheyiHasIPv6; fn jiuheyiNginxListenV6; fn jiuheyiNginxIPv6Repair; } >"$work/lib.sh"
# shellcheck disable=SC1091
. "$work/lib.sh"

[[ "$(JIUHEYI_FORCE_IPV6=1 jiuheyiNginxListenV6 10721 'so_keepalive=on ssl')" == "listen [::]:10721 so_keepalive=on ssl;" ]]
[[ "$(JIUHEYI_FORCE_IPV6=1 jiuheyiNginxListenV6 18443 ssl)" == "listen [::]:18443 ssl;" ]]
[[ -z "$(JIUHEYI_FORCE_IPV6=0 jiuheyiNginxListenV6 18443 ssl)" ]]

# 生成新配置时带上 [::]
grep -q 'nginxH2Conf="listen ${port} so_keepalive=on ssl;$(jiuheyiNginxListenV6 "${port}" "so_keepalive=on ssl")http2 on;"' "$script"
grep -q 'nginxH2Conf="listen ${port} http2 so_keepalive=on ssl;$(jiuheyiNginxListenV6 "${port}" "http2 so_keepalive=on ssl")"' "$script"
grep -q '    $(jiuheyiNginxListenV6 "${port}" ssl)' "$script"
grep -q '    jiuheyiNginxIPv6Repair || true' "$script"

# 已装机器（V1.1.7 生成的原样）
mkdir -p "$work/conf" "$work/bin"
printf 'server {\n\tlisten 10721 so_keepalive=on ssl;http2 on;\n\n\tserver_name a.example.com;\n}\n' >"$work/conf/sing_box_VMess_HTTPUpgrade.conf"
printf 'server {\n    listen 18443 ssl;\n    server_name a.example.com;\n}\n' >"$work/conf/subscribe.conf"
printf '#!/bin/sh\n[ "$1" = -t ] && exit ${NGINX_T_RC:-0}\nexit 0\n' >"$work/bin/nginx"
printf '#!/bin/sh\necho "$*" >>"%s/systemctl.log"\n' "$work" >"$work/bin/systemctl"
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" nginxConfigPath="$work/conf/" JIUHEYI_FORCE_IPV6=1
cp -a "$work/conf" "$work/orig"

NGINX_T_RC=1 jiuheyiNginxIPv6Repair >/dev/null
diff -r "$work/orig" "$work/conf" >/dev/null   # nginx -t 失败：原样还原
[[ -z "$(ls "$work/conf"/*.bak-ipv6 2>/dev/null)" ]]

jiuheyiNginxIPv6Repair >/dev/null
grep -qxF $'\tlisten 10721 so_keepalive=on ssl;listen [::]:10721 so_keepalive=on ssl;http2 on;' "$work/conf/sing_box_VMess_HTTPUpgrade.conf"
grep -qxF '    listen 18443 ssl;listen [::]:18443 ssl;' "$work/conf/subscribe.conf"
grep -q 'reload nginx' "$work/systemctl.log"
cp -a "$work/conf" "$work/once"
jiuheyiNginxIPv6Repair >/dev/null              # 再跑一次不重复添加
diff -r "$work/once" "$work/conf" >/dev/null

# 没有 IPv6 协议栈：不动
cp -a "$work/orig/." "$work/conf/"
JIUHEYI_FORCE_IPV6=0 jiuheyiNginxIPv6Repair >/dev/null
diff -r "$work/orig" "$work/conf" >/dev/null

echo "nginx ipv6 listen ok"
