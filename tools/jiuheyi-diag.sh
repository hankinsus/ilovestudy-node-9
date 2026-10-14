#!/usr/bin/env bash
# 九合一 / AimiliVPN 只读诊断：不改任何配置、不重启服务。用法：bash jiuheyi-diag.sh > diag-$(hostname).txt 2>&1
# 在 US 和 JP 各跑一次，最好在客户端正在看 YouTube 时运行（ss 能看到正在用的连接）。
export LC_ALL=C
sec() { printf '\n===== %s =====\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

sec "机器"
uname -r; nproc; free -m | head -2; uptime
grep -m1 'model name' /proc/cpuinfo
grep -E '^(steal|cpu )' /proc/stat | head -1

sec "内核网络参数"
for k in net.ipv4.tcp_congestion_control net.ipv4.tcp_available_congestion_control net.core.default_qdisc \
         net.core.rmem_max net.core.wmem_max net.ipv4.tcp_rmem net.ipv4.tcp_wmem net.ipv4.udp_rmem_min \
         net.ipv4.tcp_slow_start_after_idle net.ipv4.tcp_notsent_lowat net.ipv4.tcp_mtu_probing \
         net.ipv4.tcp_fastopen net.ipv4.tcp_ecn net.ipv4.ip_forward; do
  printf '%-40s %s\n' "$k" "$(sysctl -n "$k" 2>/dev/null || echo '-')"
done
ls -l /etc/sysctl.d/ 2>/dev/null | grep -iE 'jiuheyi|bbr|aimili' || echo "(没有九合一 sysctl 文件)"
lsmod 2>/dev/null | grep -E '^tcp_bbr' || echo "(tcp_bbr 模块未单独加载，可能编进内核)"

sec "网卡 / MTU / 队列"
dev=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
echo "默认网卡: ${dev}"
ip -d link show "${dev}" 2>/dev/null | head -3
tc qdisc show dev "${dev}" 2>/dev/null
ip route get 8.8.8.8 2>/dev/null | head -1
have ethtool && ethtool -k "${dev}" 2>/dev/null | grep -E '^(tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload):'

sec "内核版本与服务"
[[ -x /etc/v2ray-agent/sing-box/sing-box ]] && /etc/v2ray-agent/sing-box/sing-box version 2>/dev/null | head -2
[[ -x /etc/v2ray-agent/xray/xray ]] && /etc/v2ray-agent/xray/xray version 2>/dev/null | head -1
grep -m1 '^jiuheyi_version=' /etc/v2ray-agent/install.sh 2>/dev/null
for u in sing-box xray aimilivpn nginx; do
  systemctl cat "$u" >/dev/null 2>&1 || continue
  echo "--- $u"
  systemctl show "$u" -p ActiveState -p NRestarts -p MemoryCurrent -p MemoryMax -p CPUUsageNSec -p Environment -p ActiveEnterTimestamp 2>/dev/null
  systemctl cat "$u" 2>/dev/null | grep -E '^(Environment|MemoryMax|CPUQuota|AllowedCPUs|Nice|LimitNOFILE)' | sort -u
done

sec "进程 CPU / 内存"
ps -eo pid,pcpu,pmem,rss,nlwp,etime,args --sort=-pcpu | grep -E 'sing-box|xray|proxy_server|vpngate_manager|openvpn|vpnclient|nginx' | grep -v grep | cut -c1-160
have top && top -bn1 | head -5

sec "sing-box 入站摘要"
if have jq && [[ -d /etc/v2ray-agent/sing-box/conf/config ]]; then
  for f in /etc/v2ray-agent/sing-box/conf/config/*inbounds*.json; do
    jq -c '.inbounds[]? | {type, tag, listen_port, flow: (.users[0].flow // null), mux: (.multiplex.enabled // false),
           ignore_bw: (.ignore_client_bandwidth // null), up: (.up_mbps // null), down: (.down_mbps // null),
           cc: (.congestion_control // null), alpn: (.tls.alpn // null), reality: (.tls.reality.enabled // false),
           sni: (.tls.server_name // null), tfo: (.tcp_fast_open // false)}' "$f" 2>/dev/null
  done
  jq -c '.outbounds[]? | {type, tag, server, server_port, domain_strategy}' /etc/v2ray-agent/sing-box/conf/config/socks5_outbound.json 2>/dev/null
  jq -c '.route.rules' /etc/v2ray-agent/sing-box/conf/config/sniff.json 2>/dev/null
  jq -c '.dns' /etc/v2ray-agent/sing-box/conf/config/00_dns.json 2>/dev/null
fi
sec "xray 入站摘要"
if have jq && [[ -d /etc/v2ray-agent/xray/conf ]]; then
  for f in /etc/v2ray-agent/xray/conf/*inbounds*.json; do
    jq -c '.inbounds[]? | {protocol, tag, port, net: .streamSettings.network, sec: .streamSettings.security,
           flow: (.settings.clients[0].flow // null), sniff: .sniffing.enabled}' "$f" 2>/dev/null
  done
fi

sec "监听端口"
ss -ltnupH 2>/dev/null | grep -E 'sing-box|xray|python|nginx' | awk '{print $1, $5, $7}' | sort -u

sec "客户端 TCP 连接（服务端监听端口上，已建立）"
ports=$(ss -ltnpH 2>/dev/null | grep -E 'sing-box|xray' | awk '{print $4}' | sed -E 's/.*://' | sort -un | tr '\n' ' ')
echo "端口: ${ports}"
filter=""
for p in ${ports}; do filter="${filter:+${filter} or }sport = :${p}"; done
if [[ -n "${filter}" ]]; then
  ss -tinH state established "( ${filter} )" 2>/dev/null > /tmp/jiuheyi-ss.txt
  echo "连接数: $(grep -c '^' /tmp/jiuheyi-ss.txt) 行（每个连接两行）"
  # 汇总：拥塞算法、RTT、cwnd、重传、发送速率
  awk '
    /cubic|bbr|reno/ {
      cc = ($1 ~ /^(cubic|bbr|reno)$/) ? $1 : cc
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^(cubic|bbr|reno)$/) cc = $i
        if ($i ~ /^rtt:/) { split(substr($i, 5), a, "/"); rtt += a[1]; n++ }
        if ($i ~ /^cwnd:/) cw += substr($i, 6)
        if ($i ~ /^retrans:/) { split(substr($i, 9), b, "/"); rt += b[2] }
        if ($i ~ /^mss:/) mss = substr($i, 5)
        if ($i == "delivery_rate") { dr = $(i+1); if (dr ~ /Mbps/) d += dr + 0; else if (dr ~ /Kbps/) d += (dr + 0) / 1000 }
      }
      ccs[cc]++
    }
    END {
      if (n) printf "连接 %d  平均RTT %.0fms  平均cwnd %.0f  累计重传 %d  mss %s  delivery_rate 合计 %.1f Mbps\n", n, rtt/n, cw/n, rt, mss, d
      for (c in ccs) printf "拥塞算法 %s: %d\n", c, ccs[c]
    }' /tmp/jiuheyi-ss.txt
  echo "--- 发送最多的 5 个连接（原始 ss -ti）"
  paste - - < /tmp/jiuheyi-ss.txt | awk '{for(i=1;i<=NF;i++) if($i ~ /^bytes_acked:/) print substr($i,13), $0}' | sort -rn | head -5 | cut -d' ' -f2- | cut -c1-400
fi

sec "UDP（Hysteria2 / TUIC）缓冲与丢弃"
ss -uanpH 2>/dev/null | grep -E 'sing-box|xray' | awk '{print $1, $2, $3, $4}' | head
awk '/^Udp:/ { if (!h) { split($0, k); h = 1 } else { split($0, v); for (i = 2; i in k; i++) if (k[i] ~ /InErrors|RcvbufErrors|SndbufErrors|InDatagrams|OutDatagrams/) printf "%s=%s ", k[i], v[i]; print "" } }' /proc/net/snmp

sec "TCP 全局计数（重传 / 丢包探测）"
if have nstat; then
  nstat -az 2>/dev/null | grep -E 'TcpRetransSegs|TcpOutSegs|TcpExtTCPLostRetransmit|TcpExtTCPLossProbes|TcpExtTCPSackRecovery|TcpExtTCPTimeouts|TcpExtTCPSynRetrans|TcpExtTCPFastOpen|TcpExtTCPRcvQDrop|TcpExtListenDrops'
else
  grep -E '^Tcp:' /proc/net/snmp
fi

sec "8500 本机出口探测（只读请求，各 5 次）"
auth=""
if have jq && [[ -f /opt/aimilivpn/vpngate_data/proxy_auth.json ]]; then
  auth="$(jq -r '((.user // "socks5") + ":" + (.password // "ilovestudy"))' /opt/aimilivpn/vpngate_data/proxy_auth.json 2>/dev/null)@"
fi
if ss -ltnH 2>/dev/null | grep -q ':8500 '; then
  for u in https://www.google.com/generate_204 https://www.youtube.com/generate_204; do
    for i in 1 2 3 4 5; do
      curl -s -o /dev/null --max-time 10 -x "socks5h://${auth}127.0.0.1:8500" -w "%{http_code} connect=%{time_connect}s tls=%{time_appconnect}s ttfb=%{time_starttransfer}s\n" "$u"
    done
  done
  echo "--- 8500 下载 15 秒（dl.google.com）"
  curl -s -o /dev/null --max-time 15 -x "socks5h://${auth}127.0.0.1:8500" -w "%{speed_download} B/s\n" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  echo "--- 本机网卡直连对照（不经 8500）"
  curl -s -o /dev/null --max-time 15 -w "%{speed_download} B/s\n" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
else
  echo "(本机没有 8500)"
fi
[[ -f /opt/aimilivpn/vpngate_data/active_iface.txt ]] && { i=$(cat /opt/aimilivpn/vpngate_data/active_iface.txt); echo "隧道网卡: $i"; ip link show "$i" 2>/dev/null | head -1; }

sec "近 1 小时内核日志异常次数"
for u in sing-box xray; do
  systemctl cat "$u" >/dev/null 2>&1 || continue
  printf '%s: error=%s timeout=%s buffer=%s\n' "$u" \
    "$(journalctl -u "$u" --since -1h --no-pager 2>/dev/null | grep -ci error)" \
    "$(journalctl -u "$u" --since -1h --no-pager 2>/dev/null | grep -ci timeout)" \
    "$(journalctl -u "$u" --since -1h --no-pager 2>/dev/null | grep -ci 'buffer size')"
done
journalctl -u sing-box --since -1h --no-pager 2>/dev/null | grep -iE 'error|buffer' | tail -5 | cut -c1-200
echo; echo "诊断完成（只读，未改任何配置）"
