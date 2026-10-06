# 九合一安装文档

署名：我爱研究.ilovestudy  
版本：V1.0.1

九合一是客户端入口。八个入站协议还在，第 9 项是可选的 AimiliVPN 出口。功能菜单没有删，只收紧了一键安装和转发性能。这个仓库只放九合一，不和 AimiliVPN 的源码放在一起。

## 一键安装

在新的 Ubuntu/Debian 服务器上执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/hankinsus/ilovestudy-node-9/main/install.sh)
```

安装时只问两件事：

1. 是否同时安装 AimiliVPN。直接回车表示不装。
2. 域名。直接回车表示用服务器 IP。

不要在已经上线的机器上执行。已安装过的机器用 `vasma` 修改，不要重装。

从 AimiliVPN 的安装器里选择「同时安装九合一」也可以。两边都会互相询问，但不会来回套装。

## 内核和端口

一键默认用 **Xray**，不用 sing-box。

sing-box 的 DNS 分流会同时查 IPv6，规则和出口又经常不一致，结果是多一次解析、多一次失败。这台链路本身是 IPv4。一键安装改为 Xray，DNS 使用 `UseIPv4`，不再做域名分流。

| 项目 | 默认 | 原因 |
| --- | --- | --- |
| 节点 | Xray VLESS Reality **443** | 客户端只连一个端口，看起来是普通 HTTPS |
| 伪装域名 | **www.apple.com** | 固定企业域名，不再每次随机。要换成微软，在 `vasma` 里填 `www.microsoft.com` |
| 订阅 | **18443** | 不和 443 合用 |
| sing-box 节点 | **10001–39999** | 只有在 `vasma` 里另外安装 sing-box 协议时使用 |

443 不能同时当订阅端口。Reality 的 443 会把认不出来的 TLS 转给 www.apple.com，订阅请求拿不到节点列表。如果在 443 上放自己的证书来提供订阅，伪装就失效了。所以节点用 443，订阅用 18443。

18443 如果已经被占用，安装器会改到 18444–18480 里的空闲端口，并在结束时打印实际端口。

没有域名时，订阅使用自签 IP 证书，有效期按 100 年生成。公网 CA 不能签发永不过期的 IP 证书。有域名时，订阅和 AimiliVPN 面板使用 Let's Encrypt，大约 90 天，自动续期。

443 被占用时，节点端口会改到 10001–39999，避免安装失败。

## 联合安装时的流量

选择同时安装 AimiliVPN 后，九合一的出口是本机 `127.0.0.1:8500`，用户 `socks5`，密码 `ilovestudy`。伪装域名 www.apple.com 仍然直连，避免 Reality 握手绕进代理。

不装 AimiliVPN 时，流量直接从本机出去，不会去连一个不存在的 8500。

AimiliVPN 的管理页是 `https://IP或域名:8443/`。九合一不占用 8443 和 8500。

## 安装后修改

```bash
vasma
```

可以改端口、协议、订阅、用户和伪装域名。Hysteria2、TUIC 这类 UDP 协议不能放在 443 上，需要时在 `vasma` 里安装，端口会落在 10001–39999。VLESS Reality Vision 只能转发 TCP，不能带 UDP。

## 这次做了的性能修改

- 去掉菜单推广和全部上游教程链接。说明只保留这一份。
- Xray 空闲连接不主动断开，TCP keepalive 30 秒。
- DNS 只查 IPv4，减少 AAAA 失败造成的延迟。
- sing-box 如果以后从菜单安装，探测超时从 1 秒降到 300 毫秒，直连也只走 IPv4。
- 脚本更新只从本仓库拉取，不会装回带推广内容的上游脚本。

## 仓库

- https://github.com/hankinsus/ilovestudy-node-9
- https://github.com/ilovestudyus-sketch/ilovestudy-node-9

两个仓库内容相同。一键命令使用 hankinsus 这个地址。
