#!/usr/bin/env bash
# V1.1.2：菜单 18 修复每次重启内核并打印“已重启 … 端口在听”、网络参数和内存限制
set -e
cd "$(dirname "$0")/.."
f=$(sed -n '/^jiuheyiRepairAfterUpdate() {/,/^}/p' install.sh)
grep -q '已重启 ${core}，端口在听' <<<"$f" || { echo "FAIL no restart print"; exit 1; }
grep -q 'jiuheyiShowTuneSummary' <<<"$f" || { echo "FAIL no summary"; exit 1; }
grep -q 'JIUHEYI_REPAIR_ONLY=1 bash /etc/v2ray-agent/install.sh' install.sh || { echo "FAIL menu18 does not run repair"; exit 1; }
eval "$(sed -n '/^jiuheyiShowTuneSummary() {/,/^}/p' install.sh)"
echoContent() { echo "$2"; }
out=$(jiuheyiShowTuneSummary); grep -q '网络参数：拥塞' <<<"$out" || { echo "FAIL summary output: $out"; exit 1; }
! grep -q "api.github.com/repos/XTLS/Xray-core/releases/latest | jq" install.sh || { echo "FAIL raw API left"; exit 1; }
echo PASS repair_print
