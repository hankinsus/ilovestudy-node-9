#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/install.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
log="$work/calls"

awk '
    /^jiuheyiDiskFreeBytes\(\)/ {p=1}
    /^jiuheyiRealityReady\(\)/ {p=0}
    p {print}
    /^jiuheyiPrepareMachine\(\)/ {q=1}
    /^jiuheyiOneClick\(\)/ {q=0}
    q {print}
' "$script" >"$work/fns.sh"

echoType='echo -e'
printN=''
export echoType printN
echoContent() { printf '%s\n' "${2:-}"; }
# shellcheck disable=SC1091
source "$work/fns.sh"

run_recover() {
    : >"$log"
    set +e
    jiuheyiRecoverDisk
    status=$?
    set -e
    return "$status"
}

swapon() {
    if [[ "${1:-}" == "--show=NAME" ]]; then
        printf '%s\n' "${JIUHEYI_SWAPFILE}"
        return 0
    fi
    if [[ "${1:-}" == "--show=SIZE" ]]; then
        printf '%s\n' 1073741824
        return 0
    fi
    printf 'swapon %s\n' "$*" >>"$log"
}
swapoff() {
    printf 'swapoff %s\n' "$*" >>"$log"
    return 137
}

export JIUHEYI_SWAPFILE="$work/active-swap"
touch "$JIUHEYI_SWAPFILE"
status=0
run_recover || status=$?
[[ "$status" == "0" ]]
[[ -e "$JIUHEYI_SWAPFILE" ]]
[[ ! -s "$log" ]]
jiuheyiPrepareMachine
[[ ! -s "$log" ]]

swapon() {
    if [[ "${1:-}" == "--show=NAME" || "${1:-}" == "--show=SIZE" ]]; then
        return 0
    fi
    printf 'swapon %s\n' "$*" >>"$log"
}
export JIUHEYI_SWAPFILE="$work/leftover-swap"
touch "$JIUHEYI_SWAPFILE"
status=0
run_recover || status=$?
[[ "$status" == "0" ]]
[[ ! -e "$JIUHEYI_SWAPFILE" ]]
[[ ! -s "$log" ]]

rm() { return 1; }
chattr() { return 0; }
export JIUHEYI_SWAPFILE="$work/stuck-swap"
touch "$JIUHEYI_SWAPFILE"
status=0
run_recover || status=$?
[[ "$status" == "0" ]]
[[ -e "$JIUHEYI_SWAPFILE" ]]
unset -f rm chattr

echo "swap skip ok"
