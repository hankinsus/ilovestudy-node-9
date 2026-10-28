#!/usr/bin/env bash
# V1.1.18：Xray 版本锁。默认 v26.3.27；XRAY_VERSION 覆盖；latest 走原来的取最新逻辑；不再有任何地方直接取 Xray 的 latest。
# shellcheck disable=SC2034
set -e
cd "$(dirname "$0")/.."
fail() { echo "FAIL $*"; exit 1; }

# 1. 版本号与锁定变量
grep -q '^jiuheyi_version="V1.1.18"' install.sh || fail "version not V1.1.18"
grep -q '^XRAY_PINNED_VERSION="v26.3.27"' install.sh || fail "XRAY_PINNED_VERSION missing"

# 2. 取 Xray 版本的地方都走 jiuheyiXrayTargetTag；只有函数自己能调 jiuheyiLatestTag XTLS/Xray-core
n=$(grep -c 'jiuheyiLatestTag XTLS/Xray-core' install.sh)
[[ "$n" == "1" ]] || fail "jiuheyiLatestTag XTLS/Xray-core appears $n times (want 1, inside jiuheyiXrayTargetTag)"
! grep -n 'XTLS/Xray-core/releases/latest' install.sh | grep -v '^[0-9]*:\s*#' || fail "direct Xray releases/latest left"
for fn in installXray updateXray jiuheyiUpdateInstalledCores xrayVersionManageMenu; do
    body=$(sed -n "/^${fn}() {/,/^}/p" install.sh)
    [[ -n "$body" ]] || fail "no function $fn"
    grep -q 'jiuheyiXrayTargetTag\|jiuheyiXrayRollbackList' <<<"$body" || fail "$fn does not use the pin"
done

# 3. 行为
eval "$(sed -n '/^jiuheyiLatestTag() {/,/^}/p' install.sh)"
eval "$(sed -n '/^jiuheyiXrayTargetTag() {/,/^}/p' install.sh)"
eval "$(sed -n '/^jiuheyiXrayIsPinned() {/,/^}/p' install.sh)"
eval "$(sed -n '/^jiuheyiXrayRollbackList() {/,/^}/p' install.sh)"
curl() {
    if [[ "$*" == *"releases?per_page=5"* ]]; then echo '[{"tag_name":"v26.10.21","prerelease":false},{"tag_name":"v26.9.30","prerelease":true},{"tag_name":"v26.3.27","prerelease":false}]'
    elif [[ "$*" == *api.github.com* ]]; then echo '{"tag_name":"v26.10.21"}'
    else echo -n "https://github.com/XTLS/Xray-core/releases/tag/v26.10.21"; fi
}
unset XRAY_VERSION
XRAY_PINNED_VERSION="v26.3.27"
t=$(jiuheyiXrayTargetTag); [[ "$t" == "v26.3.27" ]] || fail "default pin got '$t'"
jiuheyiXrayIsPinned || fail "should be pinned"
export XRAY_VERSION="v26.7.28"
t=$(jiuheyiXrayTargetTag); [[ "$t" == "v26.7.28" ]] || fail "env override got '$t'"
export XRAY_VERSION="26.7.28"
t=$(jiuheyiXrayTargetTag); [[ "$t" == "v26.7.28" ]] || fail "env override without v got '$t'"
export XRAY_VERSION="latest"
t=$(jiuheyiXrayTargetTag); [[ "$t" == "v26.10.21" ]] || fail "XRAY_VERSION=latest got '$t'"
! jiuheyiXrayIsPinned || fail "latest should not be pinned"
unset XRAY_VERSION
XRAY_PINNED_VERSION="latest"
t=$(jiuheyiXrayTargetTag); [[ "$t" == "v26.10.21" ]] || fail "PINNED=latest got '$t'"
XRAY_PINNED_VERSION=""
t=$(jiuheyiXrayTargetTag); [[ "$t" == "v26.10.21" ]] || fail "PINNED empty got '$t'"

# 4. 回退菜单：锁定版本排第一，且去重；不锁时就是 GitHub 的稳定版
XRAY_PINNED_VERSION="v26.3.27"
l=$(jiuheyiXrayRollbackList | paste -sd,); [[ "$l" == "v26.3.27,v26.10.21" ]] || fail "rollback list pinned got '$l'"
XRAY_PINNED_VERSION="latest"
l=$(jiuheyiXrayRollbackList | paste -sd,); [[ "$l" == "v26.10.21,v26.3.27" ]] || fail "rollback list latest got '$l'"
echo PASS xray_pin
