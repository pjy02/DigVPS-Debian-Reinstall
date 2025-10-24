<div align="center">

# DigVPS-Debian-重装脚本


**一个用于将服务器重装为 Debian 13 的轻量级脚本**

</div>

---

⚠️ **注意：**  

此脚本仅支持将系统重装为 **Debian 13**，并且要求原系统为 **Debian** 或 **Ubuntu**。  

由于我们尚未进行广泛测试，重装可能存在较高的失败概率。  

理论上，如果最终的安装摘要显示正确的磁盘和 IP 设置，重装很可能会成功。

## 🚀 使用方法

### 原版（英文界面）
```shell
bash <(curl -sL https://raw.githubusercontent.com/pjy02/DigVPS-Debian-Reinstall/refs/heads/main/debian-dd.sh)
```

### 中文版（推荐中文用户使用）
```shell
bash <(curl -sL https://raw.githubusercontent.com/pjy02/DigVPS-Debian-Reinstall/refs/heads/main/debian-dd-zh.sh)
```


## ✨ 功能特性

- **智能网络检测**：自动识别物理网络接口和网络配置
- **IPv4/IPv6 双栈支持**：完整支持 IPv4 和 IPv6 网络配置
- **BBR 拥塞控制**：可选启用 BBR 和高级 TCP 调优参数
- **安全配置**：支持自定义 SSH 端口和随机密码生成
- **预装软件包**：包含常用的系统管理和开发工具
- **中文界面**：提供完全汉化的用户交互界面
- **国内镜像源支持**（中国优化版）：支持阿里云、清华大学和网易等国内镜像源
- **国内DNS选项**（中国优化版）：支持阿里云DNS和腾讯云DNS
- **多镜像源自动切换**（中国优化版）：自动尝试多个镜像源，提高下载成功率

## 📋 系统要求

- **支持的原系统**：Debian 或 Ubuntu
- **目标系统**：Debian 13 (trixie)
- **权限要求**：必须使用 root 用户执行
- **网络要求**：需要稳定的网络连接下载安装文件

## 🔧 配置选项

脚本运行时会提示您配置以下选项：

1. **主机名设置**：自定义服务器主机名（默认：digvps）
2. **root 密码**：设置 root 用户密码（可自动生成）
3. **SSH 端口**：自定义 SSH 服务端口（默认：22）
4. **BBR 拥塞控制**：是否启用 BBR 算法（默认：是）
5. **高级 TCP 调优**：是否启用激进的 TCP 参数优化（默认：否）
6. **DNS 配置**：选择使用系统 DNS 或 Google DNS（默认：Google）
7. **国内DNS选择**（中国优化版）：选择阿里云DNS或腾讯云DNS（默认：阿里云DNS）
8. **镜像源选择**（中国优化版）：选择阿里云、清华大学或网易镜像源（默认：阿里云镜像）

## 📦 预装软件包

脚本会自动安装以下常用软件包：

- **系统工具**：lrzsz, net-tools, vim, rsync, socat
- **网络工具**：curl, wget, telnet, nmap, iperf3
- **安全工具**：iptables, ufw, gpg
- **开发工具**：python3, python3-pip, zsh
- **监控工具**：vnstat, tree
- **其他**：sudo

## 🛡️ 安全提醒

- **数据备份**：重装会清除所有数据，请提前备份重要文件
- **测试环境**：建议先在测试环境验证脚本功能
- **网络稳定**：确保网络连接稳定，避免安装过程中断
- **权限确认**：仅在确认需要重装的服务器上使用 root 权限执行

## 🔍 VPS 推荐

查看我们的 VPS 评测网站：**[DigVPS.COM](https://digvps.com/)**

## 📸 截图

![安装界面截图](Screenshot.png)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 📄 许可证

本项目采用开源许可证，详情请查看 LICENSE 文件。

---

<div align="center">

**由 [DigVPS.COM](https://digvps.com/) 团队维护**

</div>
