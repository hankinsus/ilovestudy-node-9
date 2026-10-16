#!/usr/bin/env bash
# 联合安装：initVar 不清空传入域名；伪装不再二次询问；复用 AimiliVPN 证书；Socks5 出站菜单认 zz_ 文件。
set -euo pipefail
F="$(cd "$(dirname "$0")/.." && pwd)/install.sh"
out=$(domain=a.example.com bash -c "eval \"\$(sed -n '/^initVar() {/,/^}/p' $F)\"; initVar; echo \$domain")
[[ "$out" == "a.example.com" ]] || { echo "initVar wiped domain"; exit 1; }
out=$(JIUHEYI_DOMAIN=b.example.com bash -c "unset domain; eval \"\$(sed -n '/^initVar() {/,/^}/p' $F)\"; initVar; echo \$domain")
[[ "$out" == "b.example.com" ]] || { echo "JIUHEYI_DOMAIN not used"; exit 1; }
grep -q 'JIUHEYI_CAMOUFLAGE_AUTO' "$F"
! grep -q '复用 AimiliVPN 的' "$F"
grep -q 'aimilivpn-acme' "$F"
D=$(mktemp -d)
echo '{"outbounds":[{"settings":{"servers":[{"address":"127.0.0.1","port":8500}]}}]}' >"$D/zz_socks5_outbound.json"
echo '{"routing":{"rules":[{"type":"field","network":"tcp,udp","outboundTag":"socks5_outbound"}]}}' >"$D/zz_egress.json"
res=$(bash -c "echoContent(){ shift; echo -e \"\$*\"; }; eval \"\$(sed -n '/^showXrayRoutingRules() {/,/^}/p' $F)\"; coreInstallType=1 configPath=$D/ showXrayRoutingRules socks5_outbound" 2>&1)
grep -q '"outboundTag": "socks5_outbound"' <<<"$res" || { echo "rule missing"; echo "$res"; exit 1; }
grep -q '8500' <<<"$res"
! grep -q 'No such file' <<<"$res"
# 订阅地址：currentHost 为空但订阅 server_name 是域名 -> 用域名，不写死 IP
grep -q 'subHost="${subscribeDomain}"' $F
# V1.1.6：证书各自独立——不再引用 AimiliVPN 证书；九合一 acme 证书在自己的 cert-home；续期只续自己的
! grep -q '/etc/aimilivpn/tls' $F || { echo "still references aimili cert"; exit 1; }
! grep -q 'jiuheyiCertReusable\|jiuheyi-aimili-cert-reload' $F
grep -q '^JIUHEYI_ACME_HOME=/etc/v2ray-agent/tls/acme' $F
sed -n '/^jiuheyiIssueDomainCert() {/,/^}/p' $F | grep -q -- '--cert-home "${JIUHEYI_ACME_HOME}"'
sed -n '/^renewalTLS() {/,/^}/p' $F | grep -q 'jiuheyiRenewOwnCerts'
eval "$(sed -n '/^jiuheyiOwnCertValid() {/,/^}/p' $F)"
C=$(mktemp -d)
openssl req -x509 -nodes -newkey rsa:2048 -days 60 -keyout $C/ca.key -out $C/ca.crt -subj "/CN=Test CA" >/dev/null 2>&1
openssl req -nodes -newkey rsa:2048 -keyout $C/l.key -out $C/l.csr -subj "/CN=a.example.com" >/dev/null 2>&1
printf 'subjectAltName=DNS:a.example.com\n' >$C/ext
openssl x509 -req -in $C/l.csr -CA $C/ca.crt -CAkey $C/ca.key -CAcreateserial -days 60 -extfile $C/ext -out $C/l.crt >/dev/null 2>&1
openssl req -x509 -nodes -newkey rsa:2048 -days 60 -keyout $C/s.key -out $C/s.crt -subj "/CN=a.example.com" -addext "subjectAltName=DNS:a.example.com" >/dev/null 2>&1
jiuheyiOwnCertValid $C/l.crt a.example.com || { echo "own CA cert not valid"; exit 1; }
! jiuheyiOwnCertValid $C/s.crt a.example.com
! jiuheyiOwnCertValid $C/l.crt b.example.com
rm -rf $C
echo PASS
