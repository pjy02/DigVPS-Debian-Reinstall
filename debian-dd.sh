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
    echo "Error: Please use the root user to execute this script."
    exit
fi

echo "-----------------------------------------------------------------"
echo "This script was written by『DigVPS』"
echo "If you have any questions, please raise an issue. "
echo -e "${aoiBlue}GitHub${plain}: https://github.com/bihell/debian-dd"
echo -e "${aoiBlue}VPS Review Site${plain}: https://digvps.com/"
echo "-----------------------------------------------------------------"
echo "Welcome to subscribe to my channel"
echo -e "${aoiBlue}YouTube${plain}：https://www.youtube.com/channel/UCINmrFonh6v0VTyWhudSQ2w"
echo -e "${aoiBlue}bilibili${plain}：https://space.bilibili.com/88900889"
echo "-----------------------------------------------------------------"

echo -en "\n${aoiBlue}Installation dependencies...${plain}\n"
apt update
apt install wget net-tools -y


debian_version="trixie"

echo -en "\n${aoiBlue}Start installing Debian $debian_version...${plain}\n"

echo -en "\n${aoiBlue}Set hostname:${plain}\n"
read -p "Please input [Default digvps]:" HostName
if [ -z "$HostName" ]; then
    HostName="digvps"
fi

echo -ne "\n${aoiBlue}Set root password${plain}\n"
read -p "Please input [Enter directly to generate a random password]: " passwd
if [ -z "$passwd" ]; then
# Length of the password
    PASSWORD_LENGTH=16

    # Generate the password
    passwd=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c $PASSWORD_LENGTH)

    echo -e "Generated password: ${red}$passwd${plain}"
fi

echo -ne "\n${aoiBlue}Set ssh port${plain}\n"
read -p "Please input [Default 22]: " sshPORT
if [ -z "$sshPORT" ]; then
    sshPORT=22
fi

echo -ne "\n${aoiBlue}Whether to enable BBR${plain}\n"
read -p "Please input y/n [Default n]: " enableBBR
if [[ "$enableBBR" =~ ^[Yy]$ ]]; then
    bbr_path="/etc/sysctl.d/99-sysctl.conf"
    target="in-target"
    BBR="$target sed -i '\$anet.core.default_qdisc = fq' $bbr_path;$target sed -i '\$anet.ipv4.tcp_congestion_control = bbr' $bbr_path;$target sed -i '\$anet.ipv4.tcp_rmem = 8192 262144 536870912' $bbr_path;$target sed -i '\$anet.ipv4.tcp_wmem = 4096 16384 536870912' $bbr_path;$target sed -i '\$anet.ipv4.tcp_adv_win_scale = -2' $bbr_path;$target sed -i '\$anet.ipv4.tcp_collapse_max_bytes = 6291456' $bbr_path;$target sed -i '\$anet.ipv4.tcp_notsent_lowat = 131072' $bbr_path;$target sed -i '\$anet.ipv4.ip_local_port_range = 1024 65535' $bbr_path;$target sed -i '\$anet.core.rmem_max = 536870912' $bbr_path;$target sed -i '\$anet.core.wmem_max = 536870912' $bbr_path;$target sed -i '\$anet.core.somaxconn = 32768' $bbr_path;$target sed -i '\$anet.core.netdev_max_backlog = 32768' $bbr_path;$target sed -i '\$anet.ipv4.tcp_max_tw_buckets = 65536' $bbr_path;$target sed -i '\$anet.ipv4.tcp_abort_on_overflow = 1' $bbr_path;$target sed -i '\$anet.ipv4.tcp_slow_start_after_idle = 0' $bbr_path;$target sed -i '\$anet.ipv4.tcp_timestamps = 1' $bbr_path;$target sed -i '\$anet.ipv4.tcp_syncookies = 0' $bbr_path;$target sed -i '\$anet.ipv4.tcp_syn_retries = 3' $bbr_path;$target sed -i '\$anet.ipv4.tcp_synack_retries = 3' $bbr_path;$target sed -i '\$anet.ipv4.tcp_max_syn_backlog = 32768' $bbr_path;$target sed -i '\$anet.ipv4.tcp_fin_timeout = 15' $bbr_path;$target sed -i '\$anet.ipv4.tcp_keepalive_intvl = 3' $bbr_path;$target sed -i '\$anet.ipv4.tcp_keepalive_probes = 5' $bbr_path;$target sed -i '\$anet.ipv4.tcp_keepalive_time = 600' $bbr_path;$target sed -i '\$anet.ipv4.tcp_retries1 = 3' $bbr_path;$target sed -i '\$anet.ipv4.tcp_retries2 = 5' $bbr_path;$target sed -i '\$anet.ipv4.tcp_no_metrics_save = 1' $bbr_path;$target sed -i '\$anet.ipv4.ip_forward = 1' $bbr_path;$target sed -i '\$afs.file-max = 104857600' $bbr_path;$target sed -i '\$afs.inotify.max_user_instances = 8192' $bbr_path;$target sed -i '\$afs.nr_open = 1048576' $bbr_path;$target sed -i '\$anet.ipv4.tcp_fastopen=3' $bbr_path;"
else
    BBR=""
fi

# Get the device number of the root directory
root_device=$(df / | awk 'NR==2 {print $1}')

# Extract the partition number from the device number
partitionr_root_number=$(echo "$root_device" | grep -oE '[0-9]+$')

# Resolve root block device and its parent (handles NVMe, SCSI, virtio, etc.)
ROOT_SOURCE=$(findmnt -no SOURCE /)
ROOT_BLK=$(readlink -f "$ROOT_SOURCE")
# If this is a mapper device, find its underlying block device
PARENT_DISK=$(lsblk -no pkname "$ROOT_BLK" 2>/dev/null | head -n1)
if [ -z "$PARENT_DISK" ]; then
    # If pkname is empty (e.g., for partitions), strip partition suffix to get disk
    PARENT_DISK=$(lsblk -no name "$ROOT_BLK" | head -n1)
fi
# If still empty, fallback to parsing df output
if [ -z "$PARENT_DISK" ]; then
    PARENT_DISK=$(lsblk -no pkname "$(df / | awk 'NR==2 {print $1}')" 2>/dev/null | head -n1)
fi
if [ -z "$PARENT_DISK" ]; then
    echo "Could not determine the parent disk of /. Exiting to avoid data loss." && exit 1
fi
DEVICE_PREFIX="$PARENT_DISK"
echo "Detected root disk: /dev/$DEVICE_PREFIX"

# Check if any disk is mounted
if [ -z "$(df -h)" ]; then
    echo "No disks are currently mounted."
    exit 1
fi

echo -en "\n${aoiBlue}Download boot file...${plain}\n"

rm -rf /netboot
mkdir /netboot && cd /netboot
wget https://ftp.debian.org/debian/dists/$debian_version/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux
wget https://ftp.debian.org/debian/dists/$debian_version/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz

# Select primary physical network interface (ignore virtual: veth, docker*, br-*, lo, tun*, tap*, wg*, tailscale*, virbr*, vnet*, vmnet*)
get_physical_ifaces() {
    for i in $(ls -1 /sys/class/net); do
        [ "$i" = "lo" ] && continue
        case "$i" in veth*|docker*|br-*|tun*|tap*|wg*|tailscale*|virbr*|vnet*|vmnet*) continue;; esac
        # Only keep if it has a backing device (physical)
        if [ -e "/sys/class/net/$i/device" ]; then
            echo "$i"
        fi
    done
}

# Pick interface that carries the default route (prefer IPv4, then IPv6)
PRIMARY_IFACE=""
for cand in $(get_physical_ifaces); do
    if ip -4 route show default 2>/dev/null | grep -q " dev $cand "; then PRIMARY_IFACE="$cand"; break; fi
done
if [ -z "$PRIMARY_IFACE" ]; then
    for cand in $(get_physical_ifaces); do
        if ip -6 route show default 2>/dev/null | grep -q " dev $cand "; then PRIMARY_IFACE="$cand"; break; fi
    done
fi
# Fallback to first physical iface
if [ -z "$PRIMARY_IFACE" ]; then
    PRIMARY_IFACE=$(get_physical_ifaces | head -n1)
fi
if [ -z "$PRIMARY_IFACE" ]; then
    echo "No physical network interface detected." && exit 1
fi

# IPv4 details
IPV4_CIDR=$(ip -4 -o addr show dev "$PRIMARY_IFACE" scope global | awk '{print $4}' | head -n1)
IPV4_ADDR=${IPV4_CIDR%%/*}
IPV4_PREFIX=${IPV4_CIDR##*/}
IPV4_GATEWAY=$(ip -4 route show default dev "$PRIMARY_IFACE" 2>/dev/null | awk '/default/ {print $3; exit}')

# Convert prefix to netmask (e.g., 24 -> 255.255.255.0)
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

# IPv6 details (global address only)
IPV6_CIDR=$(ip -6 -o addr show dev "$PRIMARY_IFACE" scope global | awk '{print $4}' | head -n1)
IPV6_ADDR=${IPV6_CIDR%%/*}
IPV6_PREFIX=${IPV6_CIDR##*/}
IPV6_GATEWAY=$(ip -6 route show default dev "$PRIMARY_IFACE" 2>/dev/null | awk '/default/ {print $3; exit}')

# If IPv6 gateway is link-local, networkd needs GatewayOnLink=yes
IPV6_GW_ONLINK=""
if [ -n "$IPV6_GATEWAY" ] && echo "$IPV6_GATEWAY" | grep -qi '^fe80:'; then
    IPV6_GW_ONLINK="GatewayOnLink=yes"
fi

# Decide systemd-networkd DHCP mode based on what we detected
NETWORKD_DHCP=""
if [ -z "$IPV4_ADDR" ] && [ -z "$IPV6_ADDR" ]; then
    NETWORKD_DHCP="DHCP=yes"   # no static addresses detected; allow both
elif [ -z "$IPV4_ADDR" ] && [ -n "$IPV6_ADDR" ]; then
    NETWORKD_DHCP="DHCP=ipv4"  # v6 static/auto present; also try v4 via DHCP if available
elif [ -n "$IPV4_ADDR" ] && [ -z "$IPV6_ADDR" ]; then
    NETWORKD_DHCP="DHCP=ipv6"  # v4 static present; also try v6 via RA/DHCPv6
fi

# DNS (collect both IPv4 and IPv6 global nameservers from current system, fallback to Cloudflare/Google)
collect_dns() {
    awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null |
    awk 'NF {print $1}'
}
DNS_ALL=$(collect_dns)
# Filter out link-local IPv6 (fe80::/10) and empty lines
DNS_ALL=$(echo "$DNS_ALL" | awk 'NF && $1 !~ /^fe8[0-9a-f]:/ && $1 !~ /^fe9[0-9a-f]:/ && $1 !~ /^fea[0-9a-f]:/ && $1 !~ /^feb[0-9a-f]:/')
# Build a space-separated list, limit to first 4
NAMESERVERS=$(echo "$DNS_ALL" | head -n 4 | xargs)
# Fallback defaults if empty
if [ -z "$NAMESERVERS" ]; then
    NAMESERVERS="1.1.1.1 8.8.8.8 2606:4700:4700::1111 2001:4860:4860::8888"
fi

# Also keep separate v4/v6 (optional)
NS_V4=$(echo "$NAMESERVERS" | tr ' ' '\n' | awk -F: 'NF==1' | xargs)
NS_V6=$(echo "$NAMESERVERS" | tr ' ' '\n' | awk -F: 'NF>1' | xargs)


echo -e "${aoiBlue}Start configuring pre-installed file...${plain}"
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

### Network configuration
# Configure networking during install based on the current system values.
d-i netcfg/choose_interface select $PRIMARY_IFACE
# IPv4 static when detected; otherwise allow autoconfig
${IPV4_ADDR:+d-i netcfg/disable_autoconfig boolean true}
${IPV4_ADDR:+d-i netcfg/dhcp_failed note}
${IPV4_ADDR:+d-i netcfg/dhcp_options select Configure network manually}
${IPV4_ADDR:+d-i netcfg/get_ipaddress string $IPV4_ADDR}
${IPV4_NETMASK:+d-i netcfg/get_netmask string $IPV4_NETMASK}
${IPV4_GATEWAY:+d-i netcfg/get_gateway string $IPV4_GATEWAY}
d-i netcfg/get_nameservers string $NAMESERVERS
${IPV4_ADDR:+d-i netcfg/confirm_static boolean true}
# IPv6: enable and seed static values if detected; otherwise allow RA/DHCPv6
 d-i netcfg/enable_ipv6 boolean true
${IPV6_ADDR:+d-i netcfg/ipv6/address string $IPV6_ADDR}
${IPV6_PREFIX:+d-i netcfg/ipv6/prefix-length string $IPV6_PREFIX}
${IPV6_GATEWAY:+d-i netcfg/ipv6/gateway string $IPV6_GATEWAY}

### Low memory mode
d-i lowmem/low note

### hostname
d-i netcfg/hostname string $HostName

### Mirror settings
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true
d-i time/zone string Asia/Shanghai
d-i partman-auto/disk string /dev/$DEVICE_PREFIX
# (installer echo) using detected root disk /dev/$DEVICE_PREFIX
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

### Package selection
tasksel tasksel/first multiselect standard, ssh-server
# d-i pkgsel/include string lrzsz net-tools vim rsync socat curl sudo wget telnet iptables gpg zsh python3 python3-pip nmap tree iperf3 vnstat ufw

d-i pkgsel/update-policy select none
d-i pkgsel/upgrade select none

d-i grub-installer/grub2_instead_of_grub_legacy boolean true
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string /dev/$DEVICE_PREFIX

### Write preseed
d-i preseed/late_command string \
sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config; \
sed -ri 's/^#?Port.*/Port ${sshPORT}/g' /target/etc/ssh/sshd_config; \
${BBR}
### Shutdown machine
d-i finish-install/reboot_in_progress note
EOF
find . | cpio -H newc -o | gzip -6 > ../initrd.gz && cd ..
rm -rf temp_initrd 
cat << EOF >> /etc/grub.d/40_custom
menuentry "DigVPS.COM Debian Installer AMD64" {
    set root="(hd0,$partitionr_root_number)"
    linux /netboot/linux auto=true priority=critical lowmem/low=true preseed/file=/preseed.cfg
    initrd /netboot/initrd.gz
}
EOF

# Modifying the GRUB DEFAULT option
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=2/' /etc/default/grub
# Modify the GRUB TIMEOUT option
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub

update-grub 

echo "-----------------------------------------------------------------"
echo "Reinstall summary (what the installer will use):"
echo "  Root disk      : /dev/${DEVICE_PREFIX} (GRUB target)"
echo "  Boot partition : (hd0,${partitionr_root_number}) in GRUB entry"
echo "  Interface      : ${PRIMARY_IFACE}"
if [ -n "${IPV4_ADDR}" ]; then echo "  IPv4           : ${IPV4_ADDR}/${IPV4_PREFIX}  gw ${IPV4_GATEWAY}"; else echo "  IPv4           : (none)"; fi
if [ -n "${IPV6_ADDR}" ]; then echo "  IPv6           : ${IPV6_ADDR}/${IPV6_PREFIX}  gw ${IPV6_GATEWAY}"; else echo "  IPv6           : (none)"; fi
echo "  DNS            : ${NAMESERVERS}"
echo "-----------------------------------------------------------------\n"

echo -ne "\n[${aoiBlue}Finish${plain}] Input '${red}reboot${plain}' to continue the subsequential installation.\n"
exit 1
