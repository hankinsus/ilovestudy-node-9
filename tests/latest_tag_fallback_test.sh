#!/usr/bin/env bash
# V1.1.0：API 限流时取标签走跳转地址；EXIT 时恢复 8443
set -e
cd "$(dirname "$0")/.."
eval "$(sed -n '/^jiuheyiLatestTag() {/,/^}/p' install.sh)"
curl() { if [[ "$*" == *api.github.com* ]]; then echo '{"message":"API rate limit exceeded"}'; else echo -n "https://github.com/XTLS/Xray-core/releases/tag/v9.9.9"; fi; }
t=$(jiuheyiLatestTag XTLS/Xray-core); [[ "$t" == "v9.9.9" ]] || { echo "FAIL fallback got '$t'"; exit 1; }
curl() { if [[ "$*" == *api.github.com* ]]; then echo '{"tag_name":"v1.2.3"}'; else echo -n x; fi; }
t=$(jiuheyiLatestTag XTLS/Xray-core); [[ "$t" == "v1.2.3" ]] || { echo "FAIL api got '$t'"; exit 1; }
! grep -q 'releases/latest | jq -r .tag_name)' install.sh || { echo "FAIL raw API call left"; exit 1; }
grep -q "^trap 'jiuheyiRestoreAimiliNginx" install.sh || { echo "FAIL no EXIT trap"; exit 1; }
echo PASS latest_tag_fallback
