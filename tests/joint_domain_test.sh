#!/usr/bin/env bash
# 联合安装：initVar 不清空传入域名；伪装不再二次询问；复用 AimiliVPN 证书；Socks5 出站菜单认 zz_ 文件。
set -euo pipefail
F="$(cd "$(dirname "$0")/.." && pwd)/install.sh"
out=$(domain=a.example.com bash -c "eval \"\$(sed -n '/^initVar() {/,/^}/p' $F)\"; initVar; echo \$domain")
[[ "$out" == "a.example.com" ]] || { echo "initVar wiped domain"; exit 1; }
out=$(JIUHEYI_DOMAIN=b.example.com bash -c "unset domain; eval \"\$(sed -n '/^initVar() {/,/^}/p' $F)\"; initVar; echo \$domain")
[[ "$out" == "b.example.com" ]] || { echo "JIUHEYI_DOMAIN not used"; exit 1; }
grep -q 'JIUHEYI_CAMOUFLAGE_AUTO' "$F"
grep -q '复用 AimiliVPN 的' "$F"
grep -q 'aimilivpn-acme' "$F"
D=$(mktemp -d)
echo '{"outbounds":[{"settings":{"servers":[{"address":"127.0.0.1","port":8500}]}}]}' >"$D/zz_socks5_outbound.json"
echo '{"routing":{"rules":[{"type":"field","network":"tcp,udp","outboundTag":"socks5_outbound"}]}}' >"$D/zz_egress.json"
res=$(bash -c "echoContent(){ shift; echo -e \"\$*\"; }; eval \"\$(sed -n '/^showXrayRoutingRules() {/,/^}/p' $F)\"; coreInstallType=1 configPath=$D/ showXrayRoutingRules socks5_outbound" 2>&1)
grep -q '"outboundTag": "socks5_outbound"' <<<"$res" || { echo "rule missing"; echo "$res"; exit 1; }
grep -q '8500' <<<"$res"
! grep -q 'No such file' <<<"$res"
echo PASS
