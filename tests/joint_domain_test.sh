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
# 订阅地址：currentHost 为空但订阅 server_name 是域名 -> 用域名，不写死 IP
grep -q 'subHost="${subscribeDomain}"' $F
# 18443 只复用同域名、非自签的 AimiliVPN 证书（V1.1.5：subject!=issuer 判自签，不用 openssl verify）
sed -n '/^jiuheyiInstallDefaultSubscribe() {/,/^}/p' $F | grep -q 'jiuheyiCertReusable /etc/aimilivpn/tls/fullchain.pem'
! sed -n '/^jiuheyiInstallDefaultSubscribe() {/,/^jiuheyiInstallDefaultSubscribe/p' $F | grep -v '^ *#' | grep -q 'openssl verify'
eval "$(sed -n '/^jiuheyiCertReusable() {/,/^}/p' $F)"
C=$(mktemp -d)
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -keyout $C/ca.key -out $C/ca.crt -subj "/CN=Test CA" >/dev/null 2>&1
openssl req -nodes -newkey rsa:2048 -keyout $C/l.key -out $C/l.csr -subj "/CN=a.example.com" >/dev/null 2>&1
printf 'subjectAltName=DNS:a.example.com\n' >$C/ext
openssl x509 -req -in $C/l.csr -CA $C/ca.crt -CAkey $C/ca.key -CAcreateserial -days 30 -extfile $C/ext -out $C/l.crt >/dev/null 2>&1
cat $C/l.crt $C/ca.crt >$C/full.pem
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -keyout $C/s.key -out $C/s.crt -subj "/CN=a.example.com" -addext "subjectAltName=DNS:a.example.com" >/dev/null 2>&1
jiuheyiCertReusable $C/full.pem a.example.com || { echo "CA-signed not reused"; exit 1; }
! jiuheyiCertReusable $C/s.crt a.example.com || { echo "self-signed reused"; exit 1; }
! jiuheyiCertReusable $C/full.pem b.example.com || { echo "wrong domain reused"; exit 1; }
! jiuheyiCertReusable $C/full.pem example.com || { echo "parent domain reused"; exit 1; }
grep -q 'jiuheyi-aimili-cert-reload' $F
rm -rf $C
echo PASS
