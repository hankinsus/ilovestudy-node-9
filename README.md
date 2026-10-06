# 九合一安装文档

署名：我爱研究.ilovestudy  
版本：V1.0.4

九合一是客户端入口。客户端环境不一样，用的协议也不一样，所以一键按所选内核安装该内核的全部协议。11 分流菜单和已经写好的规则不动。

## 一键安装

在新的 Ubuntu/Debian 服务器上执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ilovestudyus-sketch/ilovestudy-node-9/main/install.sh)
```

同一个脚本也在 https://github.com/hankinsus/ilovestudy-node-9 。

只问三件事，没有第四个问题：

1. 内核。直接回车是 **Xray**，安装全部 6 个协议。选 2 是 **sing-box**，安装全部 11 个协议。单独安装九合一时还有 **3.自定义**，进入原来的任意组合。从 AimiliVPN 拉起时不出现自定义。
2. 域名。全部协议安装需要域名，不能空。
3. 伪装域名。Reality 的伪装域名和握手地址用同一个。直接回车是 **www.microsoft.com**。也可以选苹果、谷歌、Mozilla，或自己填。不要所有机器都用同一个。

不再询问是否同时安装 AimiliVPN。只有环境变量 `JIUHEYI_WITH_AIMILI=y` 时才会顺带安装。

不要在已经上线的机器上执行。已安装过的机器执行 `vasma`，只补保活，不重装协议。

## 会装什么

Xray 的 6 个协议，按原始安装：

| 协议 | 端口 |
| --- | --- |
| VLESS+TLS+Vision+TCP | 节点端口 443。TLS、VMess、Trojan、WS 走 Nginx 回落 |
| VLESS+TLS+WS | 443 回落 |
| VMess+TLS+WS | 443 回落 |
| Trojan+TLS | 443 回落 |
| VLESS+Reality+Vision | 原始默认也是 443。和 TLS 不能同时监听 443，所以 Reality 改到 10001–39999 |
| VLESS+Reality+XHTTP | 10001–39999，避开 443 和 Reality |

sing-box 的 11 个协议，按原始安装，各自使用 10001–39999 的端口，不占用 443：

VLESS+Vision+TCP、VLESS+TLS+WS、VMess+TLS+WS、Trojan+TLS、Hysteria2、VLESS+Reality+Vision、VLESS+Reality+gRPC、TUIC、Naive、VMess+TLS+HTTPUpgrade、anytls。

一次只装一个内核。选 Xray 会清掉 sing-box，选 sing-box 会清掉 Xray。这是原始安装的行为。

## 保活

连接要一直保持，不能空闲大约 300 秒就被拆掉。

- Xray `connIdle` 为 0，自己不按空闲时间断开。`12_policy.json` 和 `00_policy.json` 内容相同，避免后面的文件把保活盖掉。
- 主动保活是 TCP keepalive：空闲 30 秒就探测，间隔 15 秒。不等到 300 秒。
- sing-box 入站同样 30 秒 / 15 秒。UDP 超时放到 24 小时，避免 WiFi Calling 被清掉。
- Hysteria2、TUIC 每 15 秒发心跳，空闲超时 24 小时。

已经装好的机器：执行一次 `vasma`。只有策略或保活还是旧的，才会重载一次 Xray 或 sing-box。11 里的分流规则不会被改。

## DNS

菜单 **19** 可以选解析方式，默认是 IPv4 和 IPv6 同时，IPv4 优先：

- 4. 仅 IPv4
- 5. 仅 IPv6
- 6. 同时，IPv4 优先

1 和 2 仍是不分流 / 全局分流。3 进入原来的自定义分流。11 里已经按 IPv4、IPv6 分开写的出站和规则不会被 19 改掉。

只装九合一时，默认不分流。`JIUHEYI_WITH_AIMILI=y` 或从 AimiliVPN 拉起时，默认全局分流走 `127.0.0.1:8500`。伪装域名仍直连。

## 订阅

订阅默认 **18443**，不和节点 443 合用。18443 被占用时改到 18444–18480。

## 仓库

- https://github.com/ilovestudyus-sketch/ilovestudy-node-9
- https://github.com/hankinsus/ilovestudy-node-9
