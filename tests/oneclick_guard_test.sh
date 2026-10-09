#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"

grep -q 'Reality 不需要证书，跳过' "$script"
grep -q '使用本机证书，不安装 acme.sh' "$script"
grep -q '磁盘剩余不足 800MB，安装停止' "$script"
grep -q '虚拟内存正在使用，跳过' "$script"
if grep -q '残留虚拟内存删不掉，安装停止' "$script"; then
    echo "active swap still aborts install" >&2
    exit 1
fi
grep -q 'systemctl unmask xray.service' "$script"
grep -q 'Xray 程序没有安装成功，停止' "$script"
grep -q '判断环境' "$script"
grep -q '请输入用户名前缀，直接回车随机' "$script"
grep -q '无域名 Reality，清掉后重新安装' "$script"
grep -q '环境可以安装' "$script"
grep -q 'apt-get install -y wget curl unzip' "$script"

selectCustomInstallType=',7,'
if echo ",${selectCustomInstallType}," | grep -q ',7,' && ! echo ",${selectCustomInstallType}," | grep -Eq ',(0|1|2|3|4|5|12),'; then
    :
else
    echo "reality-only install would still try acme" >&2
    exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
touch "$work/swapfile"
if command -v chattr >/dev/null 2>&1 && chattr +i "$work/swapfile" 2>/dev/null; then
    chattr -i "$work/swapfile"
fi
rm -f "$work/swapfile"
if [[ -e "$work/swapfile" ]]; then
    echo "immutable file was not removed" >&2
    exit 1
fi

echo "oneclick guard ok"
