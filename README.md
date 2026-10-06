# 九合一安装文档

署名：我爱研究.ilovestudy  
版本：V1.0.3

九合一是客户端入口。协议菜单没有删。一键只安装实测延迟低、带宽高的组合，其余协议仍在 `vasma` 里按需安装。11 分流菜单和已经写好的规则不动。

## 一键安装

在新的 Ubuntu/Debian 服务器上执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ilovestudyus-sketch/ilovestudy-node-9/main/install.sh)
```

同一个脚本也会放在 https://github.com/hankinsus/ilovestudy-node-9 。当前这台环境的部署公钥还没有该仓库的写入权限，所以一键命令先用 ilovestudyus-sketch。hankinsus 仓库授权后，两个地址内容一致。

安装开始前先选伪装域名：

1. 伪装域名和握手地址。直接回车是 **www.microsoft.com**。也可以选苹果、谷歌、Mozilla，或自己填。不要所有机器都用同一个。
2. 是否同时安装 AimiliVPN。直接回车表示不装。
3. 域名。直接回车表示用服务器 IP。

不要在已经上线的机器上执行。已安装过的机器执行 `vasma`，只补保活，不重装协议。

## 一键会装什么

不装全部 sing-box 协议。按实测只装这三组：

| 协议 | 内核 | 用途 |
| --- | --- | --- |
| VLESS Reality XHTTP | Xray | 主入口。443 空闲就用 443 |
| VLESS Reality gRPC | sing-box | 低延迟 TCP |
| Hysteria2 | sing-box | WiFi Calling 这类 UDP，用得多 |

TUIC、Vision、VMess 这些还在 `vasma` 的安装菜单里，不进一键。Hysteria2 和 gRPC 端口在 10001–39999，不占 443。

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

只装九合一时，默认不分流。同时安装 AimiliVPN 时，默认全局分流走 `127.0.0.1:8500`。伪装域名仍直连。

## 订阅

订阅默认 **18443**，不和 XHTTP 的 443 合用。18443 被占用时改到 18444–18480。没有域名时订阅用自签 IP 证书。

## 仓库

- https://github.com/ilovestudyus-sketch/ilovestudy-node-9
- https://github.com/hankinsus/ilovestudy-node-9

当前可安装的地址是 ilovestudyus-sketch。
