#!/usr/bin/env bash
######################################
#
#   检测操作系统模块
#
######################################

os_type=""          # Linux操作系统分支类型
os_ver=""           # Linux系统版本号
pac_cmd=""          # 包管理命令
pac_cmd_ins=""      # 包管理命令
cpu_arc=""          # CPU架构类型，仅支持x86_64



check_sys() {
    # 检查系统类型
    if [ -f /etc/os-release ] ; then
        . /etc/os-release
        os_ver="$VERSION_ID"
        os_type="$ID"
        case "$ID" in
            centos)
                pac_cmd="yum"
                pac_cmd_ins="$pac_cmd install -y"
                ;;
            opensuse*)
                pac_cmd="zypper"
                pac_cmd_ins="$pac_cmd install -y"
                ;;
            ubuntu|debian)
                pac_cmd="apt-get"
                pac_cmd_ins="$pac_cmd install -y"
                ;;
            manjaro|arch*)
                pac_cmd="pacman"
                pac_cmd_ins="$pac_cmd -S --needed --noconfirm "
                ;;
            *)
                pac_cmd=""
                pac_cmd_ins=""
                ;;
        esac
    fi
    if [ -z "$pac_cmd" ] ; then
        return 1
    fi
    cpu_arc="`uname -m`"
    if [ "$cpu_arc" != "x86_64" ] ; then
        echo "invalid cpu arch:[$cpu_arc]"
        return 2
    fi
    return 0
}

