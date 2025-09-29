#!/bin/bash

# color
underLine='\033[4m'
aoiBlue='\033[36m'
blue='\033[34m'
yellow='\033[33m'
green='\033[32m'
red='\033[31m'
plain='\033[0m'

clear
# 检查是否是 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "错误：请使用 root 用户执行此脚本。"
    exit
fi

echo "-----------------------------------------------------------------"
echo -e "此脚本由 ${aoiBlue}DigVPS.COM${plain} 编写"
echo -e "${aoiBlue}VPS 评测网站${plain}: https://digvps.com/"
echo "-----------------------------------------------------------------"

debian_version="trixie"

echo -en "\n${aoiBlue}开始安装 Debian $debian_version...${plain}\n"

echo -en "\n${aoiBlue}设置主机名:${plain}\n"
read -p "请输入 [默认 digvps]:" HostName
if [ -z "$HostName" ]; then
    HostName="digvps"
fi

echo -ne "\n${aoiBlue}设置 root 密码${plain}\n"
read -p "请输入 [直接回车生成随机密码]: " passwd
if [ -z "$passwd" ]; then
# 密码长度
    PASSWORD_LENGTH=16

    # 生成密码
    passwd=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c $PASSWORD_LENGTH)

    echo -e "生成的密码: ${red}$passwd${plain}"
fi

echo -ne "\n${aoiBlue}设置 SSH 端口${plain}\n"
read -p "请输入 [默认 22]: " sshPORT
if [ -z "$sshPORT" ]; then
    sshPORT=22
fi

echo -ne "\n${aoiBlue}是否启用 BBR${plain}\n"
read -p "请输入 y/n [默认 y]: " enableBBR
if [[ -z "$enableBBR" || "$enableBBR" =~ ^[Yy]$ ]]; then
    echo -ne "${aoiBlue}使用高级（激进）TCP 调优？${plain}\n"
    read -p "y/n [默认 n]: " enableBBRAdv

    # 安装系统内的目标文件
    bbr_path="/etc/sysctl.d/99-sysctl.conf"

    # 最小安全设置（选择 BBR 时总是启用）
    BBR_MIN_CONTENT="'net.core.default_qdisc = fq' 'net.ipv4.tcp_congestion_control = bbr'"

    # 高级可选设置（可切换）
    BBR_ADV_CONTENT="'net.ipv4.tcp_rmem = 8192 262144 536870912' \
                     'net.ipv4.tcp_wmem = 4096 16384 536870912' \
                     'net.ipv4.tcp_adv_win_scale = -2' \
                     'net.ipv4.tcp_collapse_max_bytes = 6291456' \
                     'net.ipv4.tcp_notsent_lowat = 131072' \
                     'net.ipv4.ip_local_port_range = 1024 65535' \
                     'net.core.rmem_max = 536870912' \
                     'net.core.wmem_max = 536870912' \
                     'net.core.somaxconn = 32768' \
                     'net.core.netdev_max_backlog = 32768' \
                     'net.ipv4.tcp_max_tw_buckets = 65536' \
                     'net.ipv4.tcp_abort_on_overflow = 1' \
                     'net.ipv4.tcp_slow_start_after_idle = 0' \
                     'net.ipv4.tcp_timestamps = 1' \
                     'net.ipv4.tcp_syncookies = 0' \
                     'net.ipv4.tcp_syn_retries = 3' \
                     'net.ipv4.tcp_synack_retries = 3' \
                     'net.ipv4.tcp_max_syn_backlog = 32768' \
                     'net.ipv4.tcp_fin_timeout = 15' \
                     'net.ipv4.tcp_keepalive_intvl = 3' \
                     'net.ipv4.tcp_keepalive_probes = 5' \
                     'net.ipv4.tcp_keepalive_time = 600' \
                     'net.ipv4.tcp_retries1 = 3' \
                     'net.ipv4.tcp_retries2 = 5' \
                     'net.ipv4.tcp_no_metrics_save = 1' \
                     'net.ipv4.ip_forward = 1' \
                     'fs.file-max = 104857600' \
                     'fs.inotify.max_user_instances = 8192' \
                     'fs.nr_open = 1048576'"

    # 构建 printf 参数：最小设置总是包含，如果选择则加上高级设置
    if [[ "$enableBBRAdv" =~ ^[Yy]$ ]]; then
        BBR_CONTENT="$BBR_MIN_CONTENT $BBR_ADV_CONTENT"
    else
        BBR_CONTENT="$BBR_MIN_CONTENT"
    fi

    # 在目标系统内原子性写入内容，确保目录存在
    target="in-target"
    BBR="$target /bin/sh -c \"mkdir -p /etc/sysctl.d; \\
        printf '%s\\n' $BBR_CONTENT > $bbr_path; \\
        sysctl --system >/dev/null 2>&1 || true\";"
else
    BBR=""
fi

# 获取根目录的设备号
root_device=$(df / | awk 'NR==2 {print $1}')

# 从设备号中提取分区号
partitionr_root_number=$(echo "$root_device" | grep -oE '[0-9]+$')

# 解析根块设备及其父设备（处理 NVMe、SCSI、virtio 等）
ROOT_SOURCE=$(findmnt -no SOURCE /)
ROOT_BLK=$(readlink -f "$ROOT_SOURCE")
# 如果这是一个映射设备，找到其底层块设备
PARENT_DISK=$(lsblk -no pkname "$ROOT_BLK" 2>/dev/null | head -n1)
if [ -z "$PARENT_DISK" ]; then
    # 如果 pkname 为空（例如分区），去掉分区后缀获取磁盘
    PARENT_DISK=$(lsblk -no name "$ROOT_BLK" | head -n1)
fi
# 如果仍然为空，回退到解析 df 输出
if [ -z "$PARENT_DISK" ]; then
    PARENT_DISK=$(lsblk -no pkname "$(df / | awk 'NR==2 {print $1}')" 2>/dev/null | head -n1)
fi
if [ -z "$PARENT_DISK" ]; then
    echo "无法确定 / 的父磁盘。退出以避免数据丢失。" && exit 1
fi
DEVICE_PREFIX="$PARENT_DISK"

# 检查是否有磁盘被挂载
if [ -z "$(df -h)" ]; then
    echo "当前没有磁盘被挂载。"
    exit 1
fi

rm -rf /netboot
mkdir /netboot && cd /netboot

# 选择主要物理网络接口（忽略虚拟接口：veth、docker*、br-*、lo、tun*、tap*、wg*、tailscale*、virbr*、vnet*、vmnet*）
get_physical_ifaces() {
    for i in $(ls -1 /sys/class/net); do
        [ "$i" = "lo" ] && continue
        case "$i" in veth*|docker*|br-*|tun*|tap*|wg*|tailscale*|virbr*|vnet*|vmnet*) continue;; esac
        # 只保留有后备设备的（物理）接口
        if [ -e "/sys/class/net/$i/device" ]; then
            echo "$i"
        fi
    done
}

# 选择承载默认路由的接口（优先 IPv4，然后 IPv6）
PRIMARY_IFACE=""
for cand in $(get_physical_ifaces); do
    if ip -4 route show default 2>/dev/null | grep -q " dev $cand "; then PRIMARY_IFACE="$cand"; break; fi
done
if [ -z "$PRIMARY_IFACE" ]; then
    for cand in $(get_physical_ifaces); do
        if ip -6 route show default 2>/dev/null | grep -q " dev $cand "; then PRIMARY_IFACE="$cand"; break; fi
    done
fi
# 回退到第一个物理接口
if [ -z "$PRIMARY_IFACE" ]; then
    PRIMARY_IFACE=$(get_physical_ifaces | head -n1)
fi

if [ -z "$PRIMARY_IFACE" ]; then
    echo "未检测到物理网络接口。" && exit 1
fi

# 为安装后网络配置派生稳定匹配键（优先 MAC 而非名称）
IF_MAC=$(cat "/sys/class/net/$PRIMARY_IFACE/address" 2>/dev/null | tr '[:upper:]' '[:lower:]')
[ -n "$IF_MAC" ] && MATCH_LINE="MACAddress=$IF_MAC" || MATCH_LINE="Name=$PRIMARY_IFACE"

# IPv4 详细信息
IPV4_CIDR=$(ip -4 -o addr show dev "$PRIMARY_IFACE" scope global | awk '{print $4}' | head -n1)
IPV4_ADDR=${IPV4_CIDR%%/*}
IPV4_PREFIX=${IPV4_CIDR##*/}
IPV4_GATEWAY=$(ip -4 route show default dev "$PRIMARY_IFACE" 2>/dev/null | awk '/default/ {print $3; exit}')

# 将前缀转换为子网掩码（例如 24 -> 255.255.255.0）
to_netmask() {
    local p=$1; local mask=""; local i
    for i in 1 2 3 4; do
        if [ $p -ge 8 ]; then mask+="255"; p=$((p-8))
        else mask+=$((256 - 2**(8-p))) ; p=0; fi
        [ $i -lt 4 ] && mask+="."
    done
    echo "$mask"
}
IPV4_NETMASK=""
if [ -n "$IPV4_PREFIX" ]; then IPV4_NETMASK=$(to_netmask "$IPV4_PREFIX"); fi

# IPv6 详细信息（仅全局地址）
# 通过显式提取 'via' 后的令牌检测 IPv6 默认网关，并去掉区域 ID（例如 %eth0）
IPV6_GATEWAY=$(ip -6 route show default dev "$PRIMARY_IFACE" 2>/dev/null \
    | awk '($1=="default"){for(i=1;i<=NF;i++){if($i=="via"){print $(i+1); exit}}}' \
    | sed 's/%.*//')
# 健全性检查：如果 awk 产生了一个纯整数（例如误解析），则丢弃它
if echo "$IPV6_GATEWAY" | grep -qE '^[0-9]+$'; then IPV6_GATEWAY=""; fi

IPV6_CIDR=$(ip -6 -o addr show dev "$PRIMARY_IFACE" scope global | awk '{print $4}' | head -n1)
IPV6_ADDR=${IPV6_CIDR%%/*}
IPV6_PREFIX=${IPV6_CIDR##*/}

# 如果 IPv6 网关是链路本地的，networkd 需要 GatewayOnLink=yes
IPV6_GW_ONLINK=""
if [ -n "$IPV6_GATEWAY" ] && echo "$IPV6_GATEWAY" | grep -qi '^fe80:'; then
    IPV6_GW_ONLINK="GatewayOnLink=yes"
fi

# 决定是否接受 IPv6 RA 进行自动配置（仅在需要时发出）
IPV6_ACCEPT_RA_LINE=""
[ -z "$IPV6_ADDR" ] && IPV6_ACCEPT_RA_LINE="IPv6AcceptRA=yes"

# 根据检测到的内容决定 systemd-networkd DHCP 模式
NETWORKD_DHCP=""
if [ -z "$IPV4_ADDR" ] && [ -z "$IPV6_ADDR" ]; then
    NETWORKD_DHCP="DHCP=yes"   # 未检测到静态地址；允许两者
elif [ -z "$IPV4_ADDR" ] && [ -n "$IPV6_ADDR" ]; then
    NETWORKD_DHCP="DHCP=ipv4"  # v6 静态/自动存在；如果可用也尝试通过 DHCP 获取 v4
elif [ -n "$IPV4_ADDR" ] && [ -z "$IPV6_ADDR" ]; then
    NETWORKD_DHCP="DHCP=ipv6"  # v4 静态存在；也尝试通过 RA/DHCPv6 获取 v6
fi

# DNS 选择（用户选择：默认为 Google IPv4/IPv6）
GOOGLE_NS_V4="8.8.8.8 1.1.1.1"
GOOGLE_NS_V6="2001:4860:4860::8888 2606:4700:4700::1111"

echo -ne "\n${aoiBlue}DNS 配置${plain}\n"
read -p "使用当前系统 DNS？y/n [默认 n -> Google]: " useDefaultDNS

# 收集当前 resolv.conf 名称服务器并过滤掉链路本地 IPv6 的辅助函数
collect_dns() {
    awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | awk 'NF {print $1}'
}

if [[ "$useDefaultDNS" =~ ^[Yy]$ ]]; then
    DNS_ALL=$(collect_dns)
    # 过滤掉链路本地 IPv6 (fe80::/10) 和空行
    DNS_ALL=$(echo "$DNS_ALL" | awk 'NF && $1 !~ /^fe8[0-9a-f]:/ && $1 !~ /^fe9[0-9a-f]:/ && $1 !~ /^fea[0-9a-f]:/ && $1 !~ /^feb[0-9a-f]:/')
    # 分为不同协议族
    NS_V4=$(echo "$DNS_ALL" | awk 'index($1, ":")==0' | xargs)
    NS_V6=$(echo "$DNS_ALL" | awk 'index($1, ":")>0' | xargs)
    # 如果任一协议族缺失，用 Google 默认值补充
    [ -z "$NS_V4" ] && NS_V4="$GOOGLE_NS_V4"
    [ -z "$NS_V6" ] && NS_V6="$GOOGLE_NS_V6"
else
    NS_V4="$GOOGLE_NS_V4"
    NS_V6="$GOOGLE_NS_V6"
fi

# 重新组合；保持 v4 在前 v6 在后的顺序
NAMESERVERS="$(echo $NS_V4 $NS_V6 | xargs)"
# 安全措施：总是有一个回退，这样 resolv.conf 不会为空
if [ -z "$NAMESERVERS" ]; then
    NAMESERVERS="$GOOGLE_NS_V4 $GOOGLE_NS_V6"
fi
# 准备 systemd-networkd DNS 行（为 resolved 的每链路 DNS）
NETWORKD_DNS_LINE="DNS=$NAMESERVERS"

echo -en "\n${aoiBlue}下载启动文件...${plain}\n"
wget -q -O linux "https://ftp.debian.org/debian/dists/$debian_version/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux" || { echo "错误：下载 netboot 内核 (linux) 失败。" >&2; exit 1; }
wget -q -O initrd.gz "https://ftp.debian.org/debian/dists/$debian_version/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz" || { echo "错误：下载 netboot initrd (initrd.gz) 失败。" >&2; exit 1; }


echo -e "${aoiBlue}开始配置预安装文件...${plain}"
mkdir temp_initrd
cd temp_initrd
gunzip -c ../initrd.gz | cpio -i

cat << EOF > preseed.cfg

d-i debian-installer/locale string en_US.UTF-8
d-i debian-installer/language string en
d-i debian-installer/country string CN
d-i keyboard-configuration/xkb-keymap select us
d-i passwd/make-user boolean false
d-i passwd/root-password password $passwd
d-i passwd/root-password-again password $passwd
d-i user-setup/allow-password-weak boolean true

### 网络配置
# 基于当前系统值配置安装期间的网络。
d-i netcfg/choose_interface select auto
# 检测到 IPv4 静态时；否则允许自动配置
${IPV4_ADDR:+d-i netcfg/disable_autoconfig boolean true}
${IPV4_ADDR:+d-i netcfg/dhcp_failed note}
${IPV4_ADDR:+d-i netcfg/dhcp_options select Configure network manually}
${IPV4_ADDR:+d-i netcfg/get_ipaddress string $IPV4_ADDR}
${IPV4_NETMASK:+d-i netcfg/get_netmask string $IPV4_NETMASK}
${IPV4_GATEWAY:+d-i netcfg/get_gateway string $IPV4_GATEWAY}
d-i netcfg/get_nameservers string $NAMESERVERS
${IPV4_ADDR:+d-i netcfg/confirm_static boolean true}
# IPv6：启用并在检测到时设置静态值；否则允许 RA/DHCPv6
 d-i netcfg/enable_ipv6 boolean true

### 低内存模式
d-i lowmem/low note

### 主机名
d-i netcfg/hostname string $HostName

### 镜像设置
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true
d-i time/zone string Asia/Shanghai
d-i partman-auto/disk string /dev/$DEVICE_PREFIX
# (安装程序回显) 使用检测到的根磁盘 /dev/$DEVICE_PREFIX
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-basicfilesystems/no_swap boolean false
d-i partman-auto/expert_recipe string                       \
200 1 200 ext4 \
        \$primary{ } \$bootable{ } \
        method{ format } format{ } \
        use_filesystem{ } filesystem{ ext4 } \
        mountpoint{ /boot } \
    . \
201 2 -1 ext4 \
        \$primary{ } \
        method{ format } format{ } \
        use_filesystem{ } filesystem{ ext4 } \
        mountpoint{ / } \
    .
d-i partman-md/confirm_nooverwrite boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true

### 软件包选择
tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string lrzsz net-tools vim rsync socat curl sudo wget telnet iptables gpg zsh python3 python3-pip nmap tree iperf3 vnstat ufw

d-i pkgsel/update-policy select none
d-i pkgsel/upgrade select none

d-i grub-installer/grub2_instead_of_grub_legacy boolean true
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string /dev/$DEVICE_PREFIX

### 写入 preseed
d-i preseed/late_command string \
sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config; \
sed -ri 's/^#?Port.*/Port ${sshPORT}/g' /target/etc/ssh/sshd_config; \
${BBR} \
 in-target apt-get update; \
 in-target apt-get -y install systemd-networkd; \
 in-target mkdir -p /etc/systemd/network; \
 in-target /bin/sh -c "printf '%s\n' \
 '[Match]' \
 '${MATCH_LINE}' \
 '' \
 '[Network]' \
 ${NETWORKD_DNS_LINE:+"'${NETWORKD_DNS_LINE}'"} \
 ${NETWORKD_DHCP:+"'${NETWORKD_DHCP}'"} \
 ${IPV6_ACCEPT_RA_LINE:+"'${IPV6_ACCEPT_RA_LINE}'"} \
 ${IPV4_ADDR:+"'Address=${IPV4_ADDR}/${IPV4_PREFIX}'"} \
 ${IPV4_GATEWAY:+"'Gateway=${IPV4_GATEWAY}'"} \
 ${IPV6_ADDR:+"'Address=${IPV6_ADDR}/${IPV6_PREFIX}'"} \
 ${IPV6_GATEWAY:+"'Gateway=${IPV6_GATEWAY}'"} \
 ${IPV6_GW_ONLINK:+"'GatewayOnLink=yes'"} \
 > /etc/systemd/network/10-main.network"; \
 in-target apt-get -y install systemd-resolved; \
 in-target ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf; \
 in-target systemctl enable --now systemd-resolved.service; \
 in-target systemctl enable systemd-networkd.service; \
 in-target systemctl restart systemd-networkd.service; \
 in-target apt-get -y purge ifupdown || true;
### 关闭机器
d-i finish-install/reboot_in_progress note
EOF
find . | cpio -H newc -o | gzip -6 > ../initrd.gz && cd ..
rm -rf temp_initrd 
cat << EOF >> /etc/grub.d/40_custom
menuentry "DigVPS.COM Debian 安装程序 AMD64" {
    set root="(hd0,$partitionr_root_number)"
    linux /netboot/linux auto=true priority=critical lowmem/low=true preseed/file=/preseed.cfg
    initrd /netboot/initrd.gz
}
EOF

# 修改 GRUB DEFAULT 选项
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=2/' /etc/default/grub
# 修改 GRUB TIMEOUT 选项
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub

update-grub 

echo "-----------------------------------------------------------------"
echo "重装摘要（安装程序将使用的配置）："
echo "  根磁盘        : /dev/${DEVICE_PREFIX} (GRUB 目标)"
echo "  启动分区      : (hd0,${partitionr_root_number}) 在 GRUB 条目中"
echo "  网络接口      : ${PRIMARY_IFACE}"
if [ -n "${IPV4_ADDR}" ]; then echo "  IPv4          : ${IPV4_ADDR}/${IPV4_PREFIX}  网关 ${IPV4_GATEWAY}"; else echo "  IPv4          : (无)"; fi
if [ -n "${IPV6_ADDR}" ]; then echo "  IPv6          : ${IPV6_ADDR}/${IPV6_PREFIX}  网关 ${IPV6_GATEWAY}"; else echo "  IPv6          : (无)"; fi
echo "  DNS           : ${NAMESERVERS}"
echo "-----------------------------------------------------------------"

echo -ne "\n[${aoiBlue}完成${plain}] 输入 '${red}reboot${plain}' 继续后续安装。\n"
exit 1