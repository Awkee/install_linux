#!/bin/bash
##########################################################
# 脚本功能： 安装SS 客户端/服务端脚本
# 脚本作者： https://github.com/Awkee
# 脚本地址: https://github.com/Awkee
##########################################################

uid=$(id -u)
if [ "$uid" != "0" ] ; then
    echo "脚本需要在root用户下运行！"
    exit 0
fi

INFO() {
    echo -e "$@" >&2
}
LOG(){
    echo -e "\033[0;32;7m $1 \033[0m " $2 >&2
}

# 安装ss可执行程序
install_bin() {
    
    if [ -f "/usr/bin/shadowsocks2-linux" ] ; then
        echo "已经安装成功： /usr/bin/shadowsocks2-linux"
        echo "你是不是已经安装过ss啦？"
        exit 0
    else
        wget -c https://github.com/shadowsocks/go-shadowsocks2/releases/download/v0.1.5/shadowsocks2-linux.gz
        gzip -d shadowsocks2-linux.gz
        chmod +x shadowsocks2-linux
        mv shadowsocks2-linux /usr/bin/
        ln -sf /usr/bin/shadowsocks2-linux /usr/bin/ss2go
    fi
}

uninstall() {
    port="$1"
    echo "走到这一步，说明你再也不想使用ss了！你确定要这样么？(按任意键继续，Ctrl+C 取消操作):"
    read your_answer
    if [ "$port" = "c" -o "$port" = "client" ] ; then
        echo "客户端清理工作"
        systemctl disable --now ssclient.service
        rm -f /usr/bin/shadowsocks2-linux /usr/bin/ss2go
        rm -f /usr/lib/systemd/system/ssclient.service
        systemctl daemon-reload
        exit 0
    fi
    systemctl disable --now ssserver.service
    rm -f /usr/bin/shadowsocks2-linux /usr/bin/ss2go
    rm -f /usr/lib/systemd/system/ssserver.service
    systemctl daemon-reload
    del_firewall ${port}
}

# 添加systemd服务
add_service() {
    cmd="$1"
    fn="$2"
    if [ -f "$fn" ] ; then
        echo "文件已经存在！如果你的确想要重新安装，请先手工删除 $fn 文件."
        exit 1
    fi
    cat <<END > ${fn}
[Unit]
Description=Shadowsocks2
Wants=network-online.target
After=network-online.target

[Service]
User=nobody
PermissionsStartOnly=true
ExecStart=${cmd}
Nice=-10
KillMode=process
Restart=on-failure
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target

END

}

# 添加防火墙配置
add_firewall() {
    echo "开始添加 iptables 防火墙配置"
    ss_port="${1:-12345}"
    maxlink="50"
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT                #允许已建立的或相关连的通行
    iptables -A INPUT -p tcp -m multiport --dport 22,80,443,${ss_port} -j ACCEPT    # 端口开放
    # 限制每个客户端的HTTPS服务连接数
    iptables -A INPUT -p tcp --syn --dport ${ss_port} -m connlimit --connlimit-above ${maxlink} -j REJECT
    iptables -A INPUT -p tcp --syn --dport ${ss_port} -m connlimit --connlimit-upto ${maxlink}  -j ACCEPT
    iptables -A INPUT -j DROP   #禁止其他未允许的规则访问

    iptables -A FORWARD -p TCP ! --syn -m state --state NEW -j DROP                 # 丢弃异常的TCP连接包(可以屏蔽ACK扫描)
    iptables -A FORWARD -p icmp -j DROP                                             # 禁止ICMP包
    echo "防火墙规则："
    echo "  开放端口:22,80,443,${ss_port}"
    echo "  限制单个IP最大连接数:${maxlink}"
    echo "  丢弃所有ICMP消息"
    echo "  丢弃其他外来消息包"
}

del_firewall() {
    echo "清理 iptables 防火墙配置"
    ss_port="${1:-12345}"
    maxlink="50"
    iptables-save > /tmp/iptables.bak
    iptables -D INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT                #允许已建立的或相关连的通行
    iptables -D INPUT -p tcp -m multiport --dport 22,80,443,${ss_port} -j ACCEPT    # 端口开放
    # 限制每个客户端的HTTPS服务连接数
    iptables -D INPUT -p tcp --syn --dport ${ss_port} -m connlimit --connlimit-above ${maxlink} -j REJECT
    iptables -D INPUT -p tcp --syn --dport ${ss_port} -m connlimit --connlimit-upto ${maxlink}  -j ACCEPT
    iptables -D INPUT -j DROP   #禁止其他未允许的规则访问

    iptables -D FORWARD -p TCP ! --syn -m state --state NEW -j DROP                 # 丢弃异常的TCP连接包(可以屏蔽ACK扫描)
    iptables -D FORWARD -p icmp -j DROP                                             # 禁止ICMP包
}

select_cipher(){
    # 根据提示选择加密方法
    cipher_list="AEAD_CHACHA20_POLY1305 AEAD_AES_256_GCM AEAD_AES_128_GCM"
    i=1
    for cc in ${cipher_list}
    do
        choice[$i]="$cc"
        LOG "$i : $cc"
        i=`expr $i + 1`
    done
    LOG "选择加密方法：(默认:1)"
    read your_answer
    if [ "$your_answer" = "" ] ; then
        LOG "您选择使用默认值:1"
        your_answer="1"
    elif [ "$your_answer" -le "0" -a "$your_answer" -ge "$i" ] ; then
        LOG "输入值不再范围，已帮您选择使用默认值:1"
        your_answer="1"
    fi
    res=${choice[$your_answer]}
    LOG "使用加密方式： ${res}"
    unset choice
    echo "$res"
}

select_port() {
    LOG "设置服务端端口（1024-65535)：(默认:12345)"
    read your_answer
    if [ "$your_answer" = "" ] ; then
        your_answer="12345"
        LOG "使用默认值:${your_answer}"
    elif [ "$your_answer" -le "1024" -o "$your_answer" -ge "65535" ] ; then
        your_answer="12345"
        LOG "无效输入！已帮您选择默认值:$your_answer"
    fi
    echo "$your_answer"
}

# 设置密码
select_pass() {
    rand_pass=`echo "$(openssl rand -hex 32)$(date +%s%N)" | md5sum|base64|md5sum | awk '{ print $1}'`
    
    LOG "随机密码算法(随机序列+系统时间值):" "echo \"$(openssl rand -hex 32)$(date +%s%N)\" | md5sum | awk '{ print $1}'"
    LOG "请设置代理密码：(直接回车取默认的随机值:" "${rand_pass}"
    read your_answer
    if [ "$your_answer" = "" ] ; then
        LOG "您选择使用默认值:" "${rand_pass}"
        your_answer="${rand_pass}"
    else
        LOG "自定义密码：" "${your_answer}"
    fi
    echo "$your_answer"
}

# 安装服务端
install_server() {
    
    # 安装可执行程序
    install_bin

    # 简单启动命令: 格式为'ss://<cipher_method>:<your_password>@:<your_port>'
    # 想了解AEAD加密方法,请阅读 https://shadowsocks.org/en/wiki/AEAD-Ciphers.html
    
    random_password=`select_pass`
    cipher=`select_cipher`
    server_ip=$(ifconfig eth0 | awk '/inet /{ print $2 }')
    server_port=`select_port`

    ss_uri="ss://${cipher}:${random_password}@${server_ip}:${server_port}"
    echo "客户端/服务端使用的SS链接: ${ss_uri}"

    # 添加自启动服务
    add_service "ss2go -s '${ss_uri}'" "/usr/lib/systemd/system/ssserver.service"
    # 启动服务端进程
    echo "开始启动服务端进程"
    systemctl enable --now ssserver.service
    systemctl status ssserver.service

    add_firewall ${server_port}
    enable_bbr
    info
}

# 安装客户端
install_client() {
    SS_URI="$1"
    local_port="${2:-1080}"
    if [ "$SS_URI" = "" ] ; then
        echo "SS_URI 参数没设置!"
        return 1
    fi
    if [ "${SS_URI:0:5}" != "ss://" ] ; then
        echo "SS_URI 前缀不是以 ss://开头!你确定没搞错？！？"
        return 2
    fi
    install_bin
    add_service "ss2go -c '$SS_URI' -socks :${local_port}" "/usr/lib/systemd/system/ssclient.service"

    echo "开始启动客户端进程"
    systemctl enable --now ssclient.service

    systemctl status ssclient.service
}

get_uri(){
    echo "`awk '/^ExecStart/{ print $3 }' $1 | sed 's/'\''//g'`"
}

cmd_install() {
    # 系统命令安装 apt/dnf/zypper/pacman
    packages="$@"
    if which apt-get >/dev/null 2>&1 ; then 
        apt-get install -y ${packages}
        return
    fi
    if which dnf >/dev/null 2>&1 ; then 
        dnf install -y ${packages}
        return
    fi
    if which zypper >/dev/null 2>&1 ; then 
        zypper install -y ${packages}
        return
    fi
    if which pacman >/dev/null 2>&1 ; then 
        pacman -Sy ${packages}
        return
    fi
    LOG "没办法啦！" "没找到适合您当前系统安装命令！如果您知道如何安装，那就手工安装以下软件包：\n ${packages}"
    return
}

info() {
    if [ -f "/usr/lib/systemd/system/ssserver.service" ] ; then
        uri_str=`get_uri /usr/lib/systemd/system/ssserver.service`
    else
        uri_str=`get_uri /usr/lib/systemd/system/ssclient.service`
    fi
    INFO "========================================================================"
    LOG "SS原始链接（ss-go客户端配置用）：" ${uri_str}
    params=`echo ${uri_str:5}`
    aead_method=`echo $params| cut -d: -f1`
    method=`echo ${aead_method} | tr 'A-Z' 'a-z' |sed 's/aead_//'`
    new_uri=`echo -e "$uri_str\c" |sed "s/${aead_method}/${method}/"`
    share_uri_aead="ss://`echo -e "${uri_str:5}\c" |base64 -w0`#ss01"
    LOG "分享 支持AEAD加密算法链接 移动APP使用：" "${share_uri_aead}" 
    share_uri="ss://`echo -e "${new_uri:5}\c" |base64 -w0`#ss01"
    LOG "分享 不支持AEAD加密算法链接 移动APP用：" "${share_uri}"
    LOG "分享移动APP使用链接的二维码："
    INFO "========================================================================"
    if ! qrencode -h  >/dev/null 2>&1 ; then 
        LOG "稍等一下..." "正在为您安装qrencode二维码生成工具!"
        cmd_install qrencode
    fi
    if ! qrencode -h  >/dev/null 2>&1 ; then 
        LOG "糟糕！" "您的系统安装 qrencode 失败!" 
        return 1
    fi
    qrencode -s6 -l L -t UTF8 -o - ${share_uri}
}

init_config() {
    LOG "时区修改为国内时区"
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

    LOG "修改字符集为中文zh_CN.UTF-8"
    echo 'export LC_ALL="zh_CN.UTF-8"' >> ~/.bashrc
    echo 'export LC_ALL="zh_CN.UTF-8"' >> /etc/locale.conf
}

enable_bbr() {
    LOG "开启BBR内核加速"
    kver_major=`uname -r| cut -d . -f1`
    kver_minor=`uname -r| cut -d . -f2`
    if [ "${kver_major}" -le "5" ] || [ "${kver_major}" -eq "4" -a "${kver_minor}" -ge "9" ] ; then
        if sysctl -a | grep "net.ipv4.tcp_congestion_control" |grep bbr >/dev/null ; then
            LOG "已经开启过BBR加速哦！"
            return 1
        fi
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
    else
        LOG "真糟糕！您的内核版本太低！无法直接支持BBR加速！"
        LOG "您有两个选择：1.升级系统版本(优先建议)，2.手工升级内核版本到4.9以上。"
        LOG "当前内核版本：`uname -r`"
        return 2
    fi
}

usage() {
    cat <<END
Usage:
    `basename $0` server                        # 第一次安装服务端
    `basename $0` client uri  port              # 第一次安装客户端
    `basename $0` uninstall                     # 卸载服务端安装软件及配置，默认端口12345
    `basename $0` uninstall  port               # 卸载服务端安装软件及配置，自定义端口port
    `basename $0` uninstall  client             # 卸载客户端安装软件及配置
    `basename $0` enable_bbr                    # 启用BBR加速(服务端第一次安装自动开启)
    `basename $0` info                          # 查看SS链接URI信息
END
}

case "$1" in
    server|s)
    install_server
    ;;
    client|c)
    install_client $2 $3
    ;;
    uninstall|uni)
    uninstall $2
    ;;
    enable_bbr)
    $1
    ;;
    info|i)
    info
    ;;
    *)
    usage
    ;;
esac