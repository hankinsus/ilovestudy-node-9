#!/usr/bin/env bash
# V1.1.18：VMess 订阅/分享链接都带 aes-128-gcm（vmess JSON scy、Clash cipher、sing-box security），旧字段保留；
# VLESS/Reality/Trojan 的 fp 仍是 chrome；小火箭提示函数存在且在菜单/订阅里被调用。
set -e
cd "$(dirname "$0")/.."
fail() { echo "FAIL $*"; exit 1; }

grep -q '^jiuheyi_version="V1.1.18"' install.sh || fail "version not V1.1.18"
command -v jq >/dev/null || fail "jq needed"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/default" "$work/clashMeta" "$work/sing-box"

# 取出函数，把订阅目录换成临时目录后在子 shell 里跑
extract() { sed -n "/^$1() {/,/^}/p" install.sh; }
{
    extract jiuheyiShadowrocketTip
    extract defaultBase64Code | sed "s#/etc/v2ray-agent/subscribe_local#$work#g"
} >"$work/fn.sh"
[[ -s "$work/fn.sh" ]] || fail "functions not found"

run_type() {
    # $1=type；输出到 $work/out_$1.txt
    # shellcheck disable=SC2034
    (
        echoContent() { shift; printf '%b\n' "$*"; }
        getPublicIP() { echo 203.0.113.9; }
        # shellcheck disable=SC1091
        source "$work/fn.sh"
        currentHost=example.com
        currentRealityPublicKey=PBK1 currentRealityXHTTPPublicKey=PBK2 currentRealityMldsa65Verify=
        xrayVLESSRealityServerName=www.apple.com xrayVLESSRealityXHTTPServerName=www.apple.com
        coreInstallType=1
        defaultBase64Code "$1" 443 "tester-$1" 0b2827c6-1562-4f0b-8ff6-96c210bf831a example.com /ws
    ) >"$work/out_$1.txt" 2>&1 || { cat "$work/out_$1.txt"; fail "defaultBase64Code $1 failed"; }
}

check_vmess() {
    local t=$1 net=$2
    rm -f "$work"/default/* "$work"/clashMeta/* "$work"/sing-box/*
    run_type "$t"
    # 订阅文件里的 vmess:// base64 JSON
    local line json
    line=$(grep -h '^ *vmess://' "$work"/default/* | head -1 | sed 's/^ *vmess:\/\///')
    [[ -n "$line" ]] || fail "$t: no vmess link in default sub"
    json=$(echo "$line" | base64 -d)
    [[ "$(jq -r .scy <<<"$json")" == "aes-128-gcm" ]] || fail "$t: scy missing in vmess json: $json"
    # 旧字段保留
    [[ "$(jq -r .aid <<<"$json")" == "0" ]] || fail "$t: aid lost"
    [[ "$(jq -r .method <<<"$json")" == "none" ]] || fail "$t: legacy method lost"
    [[ "$(jq -r .net <<<"$json")" == "$net" ]] || fail "$t: net != $net"
    [[ "$(jq -r .v <<<"$json")" == "2" ]] || fail "$t: v lost"
    # 菜单里显示的通用 json 和订阅里的一致含 scy
    grep -q '"scy":"aes-128-gcm"' "$work/out_$t.txt" || fail "$t: menu json has no scy"
    # Clash
    grep -q '^    cipher: aes-128-gcm$' "$work"/clashMeta/* || fail "$t: clash cipher not aes-128-gcm"
    ! grep -q '^    cipher: \(none\|auto\)$' "$work"/clashMeta/* || fail "$t: clash cipher still none/auto"
    grep -q '^    alterId: 0$' "$work"/clashMeta/* || fail "$t: clash alterId lost"
    # sing-box
    [[ "$(jq -r '.[0].security' "$work"/sing-box/*)" == "aes-128-gcm" ]] || fail "$t: sing-box security"
    [[ "$(jq -r '.[0].alter_id' "$work"/sing-box/*)" == "0" ]] || fail "$t: sing-box alter_id lost"
    # 小火箭提示
    grep -q 'aes-128-gcm' <(grep '小火箭' "$work/out_$t.txt") || fail "$t: no shadowrocket vmess tip"
}
check_vmess vmessws ws
check_vmess vmessHTTPUpgrade httpupgrade

# 订阅里所有 vmess 生成点都处理：不再有 "aid":0 后面不带 scy 的 JSON，也没有 cipher: none/auto，sing-box vmess 不再用 auto
n=$(grep -c 'aid\\":0,\\"v\\":2' install.sh || true)
[[ "$n" == "0" ]] || fail "$n vmess json without scy left"
! grep -n '^    cipher: \(none\|auto\)$' install.sh || fail "clash vmess cipher none/auto left"
! grep -n 'type\\":\\"vmess.*security\\":\\"auto' install.sh || fail "sing-box vmess auto left"

# fp：VLESS/Reality/Trojan 链接、clash、sing-box 的 fp 都还是 chrome
! grep -n -E 'fp=(ios|safari|firefox|random|chrome[0-9])' install.sh | grep -v '^[0-9]*:\s*#' || fail "link fp not chrome"
! grep -n -E 'client-fingerprint: (ios|safari|firefox|random)' install.sh || fail "clash fp not chrome"
run_reality() {
    rm -f "$work"/default/* "$work"/clashMeta/* "$work"/sing-box/*
    run_type "$1"
    grep -q 'fp=chrome' "$work"/default/* || fail "$1: link fp != chrome"
    grep -q 'client-fingerprint: chrome' "$work"/clashMeta/* || fail "$1: clash fp != chrome"
    # sing-box 没有 XHTTP，vlessXHTTP 不写 sing-box 订阅
    if [[ "$1" != "vlessXHTTP" ]]; then
        [[ "$(jq -r '.[0].tls.utls.fingerprint' "$work"/sing-box/*)" == "chrome" ]] || fail "$1: sing-box fp != chrome"
    fi
    grep '小火箭' "$work/out_$1.txt" | grep -q 'Chrome140' || fail "$1: no shadowrocket reality tip"
}
run_reality vlessReality
run_reality vlessXHTTP

# 订阅展示处也提示
body=$(extract subscribe)
grep -q 'jiuheyiShadowrocketTip vmess' <<<"$body" || fail "subscribe menu has no tip"
grep -q 'jiuheyiShadowrocketTip reality' <<<"$body" || fail "subscribe menu has no reality tip"

echo "vmess_scy_test OK"
