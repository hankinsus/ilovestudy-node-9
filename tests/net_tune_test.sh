#!/usr/bin/env bash
# V1.1.1：sing-box GOMEMLIMIT 按内存给；长 RTT 网络参数写入 98-jiuheyi-net.conf，升级修复时也会调用
set -e
cd "$(dirname "$0")/.."
eval "$(sed -n '/^jiuheyiSingboxMemLimit() {/,/^}/p' install.sh)"
awk() { if [[ "$*" == *MemTotal* ]]; then echo "${FAKE_KB}"; else command awk "$@"; fi; }
for c in "480000 160MiB" "980000 320MiB" "2000000 512MiB"; do
  FAKE_KB=${c% *}; got=$(jiuheyiSingboxMemLimit); [[ "$got" == "${c#* }" ]] || { echo "FAIL mem $c got $got"; exit 1; }
done
unset -f awk
grep -q 'net.core.rmem_max = 16777216' install.sh || { echo "FAIL no rmem"; exit 1; }
grep -q 'tcp_slow_start_after_idle = 0' install.sh || { echo "FAIL no ssai"; exit 1; }
sed -n '/^jiuheyiMemoryTune() {/,/^}/p' install.sh | grep -q '^    jiuheyiNetTune$' || { echo "FAIL NetTune not called"; exit 1; }
sed -n '/^jiuheyiRepairAfterUpdate() {/,/^}/p' install.sh | grep -q 'jiuheyiMemoryTune' || { echo "FAIL repair path"; exit 1; }
grep -q "grep -qx 'Environment=GOMEMLIMIT=120MiB'" install.sh || { echo "FAIL old limit not upgraded"; exit 1; }
echo PASS net_tune
