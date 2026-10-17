#!/usr/bin/env bash
# 联合安装：initVar 不清空传入域名；伪装不再二次询问；复用 AimiliVPN 证书；Socks5 出站菜单认 zz_ 文件。
set -eu
F="$(cd "$(dirname "$0")/.." && pwd)/install.sh"
out=$(domain=a.example.com bash -c "eval \"\$(sed -n '/^initVar() {/,/^}/p' $F)\"; initVar; echo \$domain")
[[ "$out" == "a.example.com" ]] || { echo "initVar wiped domain"; exit 1; }
out=$(JIUHEYI_DOMAIN=b.example.com bash -c "unset domain; eval \"\$(sed -n '/^initVar() {/,/^}/p' $F)\"; initVar; echo \$domain")
[[ "$out" == "b.example.com" ]] || { echo "JIUHEYI_DOMAIN not used"; exit 1; }
grep -q 'JIUHEYI_CAMOUFLAGE_AUTO' "$F"
if grep -q '复用 AimiliVPN 的' "$F"; then echo "negative check failed: grep -q '复用 AimiliVPN 的' '$F'"; exit 1; fi
grep -q 'aimilivpn-acme' "$F"
D=$(mktemp -d)
echo '{"outbounds":[{"settings":{"servers":[{"address":"127.0.0.1","port":8500}]}}]}' >"$D/zz_socks5_outbound.json"
echo '{"routing":{"rules":[{"type":"field","network":"tcp,udp","outboundTag":"socks5_outbound"}]}}' >"$D/zz_egress.json"
res=$(bash -c "echoContent(){ shift; echo -e \"\$*\"; }; eval \"\$(sed -n '/^showXrayRoutingRules() {/,/^}/p' $F)\"; coreInstallType=1 configPath=$D/ showXrayRoutingRules socks5_outbound" 2>&1)
grep -q '"outboundTag": "socks5_outbound"' <<<"$res" || { echo "rule missing"; echo "$res"; exit 1; }
grep -q '8500' <<<"$res"
if grep -q 'No such file' <<<"$res"; then echo "negative check failed: grep -q 'No such file' <<<'$res'"; exit 1; fi
# 订阅地址：currentHost 为空但订阅 server_name 是域名 -> 用域名，不写死 IP
grep -q 'subHost="${subscribeDomain}"' $F
# V1.1.6：证书各自申请；V1.1.7：自己的 acme 目录在 /var/lib/jiuheyi-acme（卸载保留），申请失败才复制借用 AimiliVPN 同域名正式证书
if grep -q 'jiuheyiCertReusable\|jiuheyi-aimili-cert-reload' $F; then echo "negative check failed: grep -q 'jiuheyiCertReusable\|jiuheyi-aimili-cert-reload' $F"; exit 1; fi
grep -q '^JIUHEYI_ACME_HOME=/var/lib/jiuheyi-acme' $F
if sed -n '/^unInstall() {/,/^}/p' $F | grep -Eq 'rm .*(jiuheyi-acme|JIUHEYI_ACME_HOME)'; then echo 'uninstall removes acme home'; exit 1; fi
sed -n '/^installTLS() {/,/^}/p' $F | grep -q 'jiuheyiBorrowAimiliCert'
if sed -n '/^jiuheyiBorrowAimiliCert() {/,/^}/p' $F | grep -q 'ln -s'; then echo "negative check failed: sed -n '/^jiuheyiBorrowAimiliCert() {/,/^}/p' $F | grep -q '"; exit 1; fi
sed -n '/^renewalTLS() {/,/^}/p' $F | grep -q 'jiuheyiCertSelfHeal' 
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
if jiuheyiOwnCertValid $C/s.crt a.example.com; then echo "negative check failed: jiuheyiOwnCertValid $C/s.crt a.example.com"; exit 1; fi
if jiuheyiOwnCertValid $C/l.crt b.example.com; then echo "negative check failed: jiuheyiOwnCertValid $C/l.crt b.example.com"; exit 1; fi
# staging（issuer 含 (STAGING)）默认不算有效；JIUHEYI_ALLOW_STAGING_CERT=1 放行
openssl req -x509 -nodes -newkey rsa:2048 -days 60 -keyout $C/sca.key -out $C/sca.crt -subj "/O=(STAGING) Let's Encrypt/CN=(STAGING) Ersatz Edamame E1" >/dev/null 2>&1
openssl x509 -req -in $C/l.csr -CA $C/sca.crt -CAkey $C/sca.key -CAcreateserial -days 60 -extfile $C/ext -out $C/st.crt >/dev/null 2>&1
if jiuheyiOwnCertValid $C/st.crt a.example.com; then echo "staging accepted"; exit 1; fi
JIUHEYI_ALLOW_STAGING_CERT=1 jiuheyiOwnCertValid $C/st.crt a.example.com
# 借用：复制 AimiliVPN 有效证书（私钥匹配），写 .borrowed；私钥不匹配不借
eval "$(sed -n '/^jiuheyiKeyMatches() {/,/^}/p' $F)"
jiuheyiKeyMatches $C/l.crt $C/l.key
if jiuheyiKeyMatches $C/l.crt $C/s.key; then echo "negative check failed: jiuheyiKeyMatches $C/l.crt $C/s.key"; exit 1; fi
fn=$(sed -n '/^jiuheyiBorrowAimiliCert() {/,/^}/p' $F | sed "s#/var/lib/aimilivpn-acme#$C/aa#g; s#/etc/aimilivpn/tls#$C/at#g; s#/etc/v2ray-agent/tls#$C/vt#g")
eval "$fn"
mkdir -p $C/aa/a.example.com_ecc && cp $C/l.crt $C/aa/a.example.com_ecc/fullchain.cer && cp $C/s.key $C/aa/a.example.com_ecc/a.example.com.key
if jiuheyiBorrowAimiliCert a.example.com; then echo "borrowed mismatched key"; exit 1; fi
cp $C/l.key $C/aa/a.example.com_ecc/a.example.com.key
jiuheyiBorrowAimiliCert a.example.com
cmp -s $C/l.crt $C/vt/a.example.com.crt && [[ -f $C/vt/a.example.com.borrowed && ! -L $C/vt/a.example.com.crt ]]
rm -rf $C
echo PASS
