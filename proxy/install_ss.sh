#!/bin/bash
##########################################################
# 脚本功能： 安装SS(GoLang语言支持AEAD版本) 客户端/服务端脚本
# 脚本作者： https://github.com/Awkee
# 脚本地址: https://github.com/Awkee
##########################################################

conf_file="$HOME/.ss.conf"
red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

INFO() {
    echo -e "$@" >&2
}

LOG(){
    echo -e "\033[0;32;7m $1 \033[0m " $2 >&2
}

cmd_install() {
    # 系统命令安装 apt/dnf/zypper/pacman
    packages="$@"
    if which apt-get >/dev/null 2>&1 ; then 
        apt-get install -y ${packages}
        return
    fi
    if which dnf >/dev/null 2>&1 ; then
        dnf install epel-release -y
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


# 安装ss可执行程序
install_bin() {
    
    if [ -f "/usr/bin/shadowsocks2-linux" ] ; then
        echo "已经安装成功： /usr/bin/shadowsocks2-linux"
        echo "你是不是已经安装过ss啦？"
        exit 0
    else
        ver=$(curl -H 'Cache-Control: no-cache' -s https://api.github.com/repos/shadowsocks/go-shadowsocks2/releases | grep -m1 'tag_name' | cut -d\" -f4)
        if [[ ! $ver ]]; then
            echo
            echo -e " $red获取 Shadowsocks-Go 最新版本失败!!!$none"
            echo
            echo -e " 请尝试执行如下命令: $green echo 'nameserver 8.8.8.8' >/etc/resolv.conf $none"
            echo
            echo " 然后再重新运行脚本...."
            echo
            exit 1
        fi
        _link="https://github.com/shadowsocks/go-shadowsocks2/releases/download/$ver/shadowsocks2-linux.gz"

        wget -c ${_link}
        gzip -d shadowsocks2-linux.gz
        chmod +x shadowsocks2-linux
        mv shadowsocks2-linux /usr/bin/
        ln -sf /usr/bin/shadowsocks2-linux /usr/bin/ss2go
    fi
}

service_port(){
    service_name="$1"
    systemctl cat ${service_name} | sed 's/'\''//g' | awk -F: '/^ExecStart/{print $NF }'
}

service_list(){
    i=1
    cat ${conf_file} | while read sn
    do
        echo "$i. ${sn} <`service_port ${sn}`>"
        i=`expr $i + 1`
    done
}

# 服务信息查看
service_status(){
    if [ "$1" != "" ] ; then
        # 指定单个服务查询
        info "$1"
        return 0
    fi
    # 所有服务查询
    cat ${conf_file} | while read sn
    do
        LOG "服务：${sn}信息:"
        systemctl status ${sn}
        if [ "$?" = "0" ] ; then 
            info ${sn}
        else
            LOG "服务: $sn 未启动！"
        fi
    done
        
}

# 添加systemd服务
add_service() {
    cmd="$1"
    local service_name="$2"
    local service_file="/usr/lib/systemd/system/${service_name}.service"
    while :
    do
        if [ "$service_name" = "" ] ; then
            read -p "输入新服务名(例如:ss2go01,或回车退出):" your_answer
            if [ "$your_answer" = "" ] ; then
                LOG "退出!"
                exit 0
            fi
            service_name="$your_answer"
        fi
        service_file="/usr/lib/systemd/system/${service_name}.service"
        if [ -f "$service_file" ] ; then
            read -p "文件[${service_file}]已经存在！换个新服务名(例如:ss2go01,或回车退出)?" your_answer
            if [ "${your_answer}" = "" ] ; then
                exit 0
            fi
            service_name="${your_answer}"
        fi
        break
    done
    cat <<END > ${service_file}
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

    # 启动服务端进程
    echo "启动[${service_name}]服务进程"
    systemctl daemon-reload
    systemctl enable --now ${service_name}.service
    systemctl status ${service_name}.service
    echo "${service_name}" >> ${conf_file}
    if [ "$?" != "0" ] ; then
        echo "服务启动失败啦！尝试根据错误信息解决问题吧！修复后再执行 systemctl start ${service_name} 启动试试。"
    fi
}

# 初始化防火墙配置
init_firewall() {
    echo "开始添加 iptables 防火墙配置"
    maxlink="150"
    iptables -A INPUT -p tcp -m multiport --dport 22,80,443 -j ACCEPT    # 端口开放
    iptables -A INPUT -j DROP   #禁止其他未允许的规则访问

    iptables -A FORWARD -p TCP ! --syn -m state --state NEW -j DROP                 # 丢弃异常的TCP连接包(可以屏蔽ACK扫描)
    iptables -A FORWARD -p icmp -j DROP                                             # 禁止ICMP包
    echo "防火墙规则："
    echo "  开放端口:22,80,443"
    echo "  丢弃所有ICMP消息"
    echo "  丢弃其他外来消息包"
}

del_firewall() {
    echo "清理 iptables 防火墙配置"
    bak_file="/tmp/iptables.`date +%Y%m%d%H%M%S`"
    iptables-save > ${bak_file}
    echo "已经备份iptables规则到文件[$bak_file]中！"
    iptables -D INPUT -p tcp -m multiport --dport 22,80,443 -j ACCEPT    # 端口开放
    iptables -D INPUT -j DROP   #禁止其他未允许的规则访问

    iptables -D FORWARD -p TCP ! --syn -m state --state NEW -j DROP                 # 丢弃异常的TCP连接包(可以屏蔽ACK扫描)
    iptables -D FORWARD -p icmp -j DROP                                             # 禁止ICMP包
}

# 添加防火墙端口
add_port() {
    echo "开始添加 iptables 防火墙配置"
    ss_port="${1:-12345}"
    if netstat -tlnp | grep "${ss_port}" | grep -v grep > /dev/null ; then 
        LOG "${ss_port}" "端口监听中"
    else
        LOG "这个端口没有服务呢？" "记得等下手工启动一下这个服务吧！"
    fi
    if  iptables -S |grep " ${ss_port} "  > /dev/null ; then
        LOG "${ss_port}" 端口已添加到防火墙中
        return 0
    fi
    # 开放端口
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ss_port} -j ACCEPT
}

# 删除防火墙端口
del_port() {
    echo "开始删除 iptables 防火墙端口配置"
    ss_port="${1:-12345}"
    if netstat -tlnp | grep "${ss_port}" | grep -v grep > /dev/null ; then 
        LOG "${ss_port}端口监听中," "记得等下手工停止掉这个服务吧！"
    else
        LOG "[${ss_port}]" "端口没有服务了!"
    fi
    # 开放端口
    iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${ss_port} -j ACCEPT
}

# 简单启动命令: 格式为'ss://<cipher_method>:<your_password>@:<your_port>'
# 想了解AEAD加密方法,请阅读 https://shadowsocks.org/en/wiki/AEAD-Ciphers.html
ciphers=(
	aes-128-gcm
	aes-256-gcm
	chacha20-ietf-poly1305
    #AEAD_AES_128_GCM
    #AEAD_AES_256_GCM
    #AEAD_CHACHA20_POLY1305
)

select_cipher(){
    # 根据提示选择加密方法
    i=1
    for ((i = 1; i <= ${#ciphers[*]}; i++)); do
        if [[ "$i" -le 9 ]]; then
            LOG " $i. ${ciphers[$i - 1]}"
        else
            LOG "$i. ${ciphers[$i - 1]}"
        fi
    done
    read -p "选择加密方法(默认:1):" your_answer
    if [ "$your_answer" = "" ] ; then
        LOG "您选择使用默认值:1"
        your_answer="1"
    elif [ "$your_answer" -le "0" -a "$your_answer" -ge "$i" ] ; then
        LOG "输入值不再范围，已帮您选择使用默认值:1"
        your_answer="1"
    fi
    res=${ciphers[$your_answer - 1]}
    LOG "使用加密方式：" "[${res}]"
    echo "$res"
}

select_port() {
    while :
    do
        LOG "设置服务端口（1024-65535)："
        read -p "(默认:12345):" your_answer
        if [ "$your_answer" = "" ] ; then
            your_answer="12345"
            LOG "使用默认值:${your_answer}"
        elif [ "$your_answer" -le "1024" -o "$your_answer" -ge "65535" ] ; then
            your_answer="12345"
            LOG "无效输入！已帮您选择默认值:$your_answer"
        fi
        if netstat -tanp|grep LISTEN |grep ":${your_answer}" >/dev/null ; then
            LOG "端口检测已经被占用! 重新选一个吧！"
        else
            break
        fi
    done
    echo "$your_answer"
}

function random_string_gen() {
    PASS=""
    MATRIX="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_+" # "~!@#$%^&*()_+="
    LENGTH=$1
    [ -z $1 ] && LENGTH="32"
    while [ "${n:=1}" -le "$LENGTH" ]
    do
        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
    done

    echo ${PASS}
}

# 设置密码
select_pass() {
    rand_pass=`random_string_gen`
    
    LOG "设置密码：(默认值${rand_pass}):"
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
    
    init_firewall

    add_server
    enable_bbr
}

# 添加新服务
add_server(){
    random_password=`select_pass`
    method=`select_cipher`
    server_ip=$(ifconfig eth0 | awk '/inet /{ print $2 }')
    server_port=`select_port`

    ss_uri="ss://${method}:${random_password}@${server_ip}:${server_port}"
    echo "客户端/服务端使用的SS链接: ${ss_uri}"

    # 添加自启动服务
    read -p "输入新服务名(例如:ss2go01,或回车退出):" your_answer
    if [ "$your_answer" = "" ] ; then
        LOG "退出!"
        exit 0
    fi
    service_name="$your_answer"
    add_service "ss2go -s '${ss_uri}'" "${service_name}"
    add_port ${server_port}

}

# 删除服务
del_server(){
    service_name="$1"
    if grep "$service_name" ${conf_file} >/dev/null ; then
        # 服务存在
        if systemctl is-active ${service_name} ; then
            systemctl disable --now ${service_name}
            systemctl status ${service_name}
            service_file="/usr/lib/systemd/system/${service_name}.service"
            sport=`service_port ${service_name}`
            del_port ${sport}
            if [ -f "$service_file" ] ; then
                rm -f $service_file
            fi
        fi
        sed -i "/${service_name}/d" ${conf_file}
    fi
}

# 删除所有服务端ss服务
del_all_server(){
    cat ${conf_file} | while read service_name
    do
        if systemctl is-active ${service_name} ; then
            systemctl disable --now ${service_name}
            systemctl status ${service_name}
            service_file="/usr/lib/systemd/system/${service_name}.service"
            if [ -f "$service_file" ] ; then
                rm -f $service_file
            fi
            sport=`service_port ${service_name}`
            del_port ${sport}
        fi
    done
    if [ "$?" = "0" ] ; then
        rm -f ${conf_file}
    fi
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
    add_service "ss2go -c '$SS_URI' -socks :${local_port}" "ssclient"
}

uninstall() {
    service_name="$1"
    echo "走到这一步，说明你再也不想使用ss了！你确定要这样么？(按任意键继续，Ctrl+C 取消操作):"
    read _nouse
    if [ "$service_name" = "client" ] ; then
        echo "客户端清理工作"
        systemctl disable --now ssclient.service
        rm -f /usr/bin/shadowsocks2-linux /usr/bin/ss2go
        rm -f /usr/lib/systemd/system/ssclient.service
        systemctl daemon-reload
        exit 0
    fi
    if [ "$service_name" = "" ] ; then
        del_all_server
        # del_firewall
        return 0
    fi
    del_server ${service_name}
}

get_uri(){
    # 提取服务配置中的URI信息
    systemctl cat ${service_name} | awk '/^ExecStart/{ print $3 }' | sed 's/'\''//g'
}

info() {
    service_name="$1"
    if [ -f "/usr/lib/systemd/system/${service_name}.service" ] ; then
        uri_str=`get_uri ${service_name}`
    else
        uri_str=`get_uri ssclient`
    fi
    INFO "========================================================================"
    params=`echo ${uri_str:5}`
    share_uri="ss://`echo -ne "${params}" |base64 -w0`"
    LOG "分享SS链接：" "${share_uri}"
    echo "分享移动APP使用链接的二维码："
    if ! qrencode -h  >/dev/null 2>&1 ; then 
        LOG "稍等一下..." "正在为您安装qrencode二维码生成工具!"
        cmd_install qrencode
    fi
    if ! qrencode -h  >/dev/null 2>&1 ; then 
        LOG "糟糕！" "您的系统安装 qrencode 失败!" 
        return 1
    fi
    qrencode -m2 -l L -t UTF8 -o - ${share_uri}
    INFO "========================================================================"
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
            return 0
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
    `basename $0` add                           # 服务端安装新服务
    `basename $0` uninstall                     # 卸载服务端安装的所有ss服务及相关软件
    `basename $0` uninstall [service]           # 卸载服务端安装的单个服务,service为服务名称

    `basename $0` client uri  port              # 第一次安装客户端
    `basename $0` remove                        # 卸载客户端安装软件及配置

    `basename $0` status [service]              # 服务端使用：查看SS链接URI信息(默认service名为ssserver或ssclient)
    `basename $0` info                          # 客户端使用：查看SS链接URI信息(默认ssclient)
    
    `basename $0` list                          # 查看SS服务名称列表信息
END
}

check_root() {
    uid=$(id -u)
    if [ "$uid" != "0" ] ; then
        echo "脚本需要在root用户下运行！"
        exit 0
    fi
}

case "$1" in
    server)
        check_root
        install_server
        ;;
    add)
        check_root
        add_server
        ;;
    client)
        check_root
        install_client $2 $3
        ;;
    uninstall)
        check_root
        uninstall $2
        ;;
    remove)
        check_root
        uninstall client
        ;;
    status)
        service_status $2
        ;;
    info)
        service_status ssclient
        ;;
    list)
        service_list
        ;;
    *)
        usage
        ;;
esac