# 九合一安装文档

署名：我爱研究.ilovestudy  
版本：V1.0.2

九合一是客户端入口。八个入站协议还在，第 9 项是可选的 AimiliVPN 出口。功能菜单没有删，只收紧了一键安装和转发性能。这个仓库只放九合一，不和 AimiliVPN 的源码放在一起。

## 一键安装

在新的 Ubuntu/Debian 服务器上执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ilovestudyus-sketch/ilovestudy-node-9/main/install.sh)
```

同一个脚本也会放在 https://github.com/hankinsus/ilovestudy-node-9 。当前这台环境的部署公钥还没有该仓库的写入权限，所以一键命令先用 ilovestudyus-sketch。hankinsus 仓库授权后，两个地址内容一致。

安装时只问两件事：

1. 是否同时安装 AimiliVPN。直接回车表示不装。
2. 域名。直接回车表示用服务器 IP。

不要在已经上线的机器上执行。已安装过的机器用 `vasma` 修改，不要重装。

从 AimiliVPN 的安装器里选择「同时安装九合一」也可以。两边都会互相询问，但不会来回套装。

## 内核和端口

一键默认用 **Xray**，不用 sing-box 当主转发。

sing-box 协议更多（Hysteria2、TUIC 都在它上面），但主路径仍用 Xray VLESS Reality：TCP、开销小、延迟低、客户端最稳。UDP 协议在丢包网络上更快，也更容易被掐，而且更吃 CPU。所以 Hysteria2、TUIC 继续只在 `vasma` 里按需装，不进一键。

后面的机器公网同时有 IPv4 和 IPv6。解析改成 **IPv4 优先，没有 IPv4 再用 IPv6**（Xray `UseIPv4v6`，sing-box `prefer_ipv4`）。不再只查 A 记录，也不再让 AAAA 抢在前面。11 里已经配好的 WARP、Socks5、自定义分流规则不动。要换这台机器的 DNS 模式，进 `vasma` 选 **19**。

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

## DNS

- 只装九合一：DNS **不分流**。在服务器本机解析，IPv4 优先，没有 IPv4 再用 IPv6，流量不进 8500。
- 同时安装 AimiliVPN：DNS **全局分流**。解析和访问都走 `127.0.0.1:8500`。伪装域名 www.apple.com 仍直连，避免 Reality 握手绕进代理。
- 以后要改：执行 `vasma`，选 **19.DNS模式**。11 里的分流工具继续管原来的规则，这次没有改它的功能。

AimiliVPN 的管理页是 `https://IP或域名:8443/`。九合一不占用 8443 和 8500。

## 安装后修改

```bash
vasma
```

可以改端口、协议、订阅、用户和伪装域名。Hysteria2、TUIC 这类 UDP 协议不能放在 443 上，需要时在 `vasma` 里安装，端口会落在 10001–39999。VLESS Reality Vision 只能转发 TCP，不能带 UDP。

## 这次做了的性能修改

- 去掉菜单推广和全部上游教程链接。说明只保留这一份。
- Xray 空闲连接不主动断开。`connIdle` 为 0。原先 `12_policy.json` 用随机 250–300 秒，而且文件名排在后面，会把这份保活盖掉。第一次执行 `vasma` 时如果策略还是旧的，会重载一次 Xray。
- TCP keepalive 仍是空闲 30 秒、间隔 15 秒。sing-box 入站如果还没有 `tcp_keep_alive`，同一次 `vasma` 会补上并重载一次。
- 新安装的直连出口是 IPv4 优先、必要时 IPv6。已经写在 11 里的分流规则不会被改写。
- 脚本更新只从本仓库拉取，不会装回带推广内容的上游脚本。

## 仓库

- https://github.com/hankinsus/ilovestudy-node-9
- https://github.com/ilovestudyus-sketch/ilovestudy-node-9

两个仓库内容相同。当前可安装的地址是 ilovestudyus-sketch。hankinsus 仓库补上写入权限后会放同一份脚本。
