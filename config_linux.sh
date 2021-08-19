#!/bin/bash
########################################################################
# File Name: config_linux.sh
# Author: zioer
# mail: next4nextjob@gmail.com
# Created Time: 2021年02月01日 星期一 23时20分14秒
#
# 安装Linux系统后的桌面环境配置工作
# 主要配置内容：
#   1. 修改软件源-让安装软件包速度最快
#   2. 配置基础环境：例如默认zsh、配置zshrc文件、VIM环境、tmux配置、自定义Python环境
#   3. 配置桌面主题环境：
#   4. 安装软件包工具： 浏览器、图片软件、输入法、Wine
########################################################################


os_type=""          # Linux操作系统分支类型
pac_cmd=""          # 包管理命令
pac_cmd_ins=""      # 包管理命令
cpu_arc=""          # CPU架构类型，仅支持x86_64
gui_type="unknown"  # 桌面环境类型检测 kde/gnome/xfce/unknown

default_confirm="no"

python_install_path="$HOME/anaconda3"       # Python3 默认安装路径

# set -e              # 命令执行失败就中止继续执行


prompt(){
    # 提示确认函数，如果使用 -y 参数不进行提示
    msg="$@"    # 提示的信息
    if [ "$default_confirm" != "yes" ] ; then
        echo -e "$msg (y/N)\c"
        read str_answer
        if [ "$str_answer" = "y" -o "$str_answer" = "Y" ] ; then
            echo "已确认"
            return 0
        else
            echo "已取消"
            return 1
        fi
    else
        echo "$msg"
    fi

    return 0
}

check_sys() {
    # 检查系统类型
    if [ -f /etc/os-release ] ; then
        . /etc/os-release
        case "$ID" in
            centos)
                os_type="$ID"
                pac_cmd="yum"
                pac_cmd_ins="$pac_cmd install -y"
                ;;
            opensuse*)
                os_type="$ID"
                pac_cmd="zypper"
                pac_cmd_ins="$pac_cmd install -y"
                ;;
            ubuntu|debian)
                os_type="$ID"
                pac_cmd="apt-get"
                pac_cmd_ins="$pac_cmd install -y"
                ;;
            manjaro|arch*)
                os_type="$ID"
                pac_cmd="pacman"
                pac_cmd_ins="$pac_cmd -S --needed --noconfirm "
                ;;
            *)
                os_type="unknown"
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

add_aur(){
    # 添加AUR源配置
    if grep ustc /etc/pacman.conf >/dev/null 
    then
        echo "已经添加了中国科学技术大学的AUR源"
    else
        cat <<END | sudo tee -a /etc/pacman.conf
[archlinuxcn]
SigLevel = Optional TrustAll
# 中国科学技术大学
Server = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch
END
    fi
    sudo pacman -Sy && sudo $pac_cmd_ins archlinuxcn-keyring  yay
}

config_repo(){
    # 配置软件源
    echo 
    prompt "更新选择软件源"
    str_ret="$?"
    if [ "$str_ret" != "0" ] ; then
        # 取消继续执行
        return "$str_ret"
    fi
    case "$os_type" in 
        manjaro)
            # 测试并选择延迟最低的镜像源地址(通过-c参数选择国家)
            sudo pacman-mirrors -g -c China
            # 更新软件源本地缓存并升级软件包版本
            sudo pacman -Syu  --noconfirm
            add_aur
            
            ;;
        *)
            echo "$os_type 系统类型不支持！"
            ;;
    esac
}

copy_file(){
    src_file="$1"
    dst_file="$2"
    if [ -f "$dst_file" ] ; then
        prompt "$dst_file 文件已存在，是否覆盖"
        if [ "$?" = "0" ] ; then
            mv $dst_file $dst_file.`date +%Y%m%d%H%M%S`
            cp -f $src_file $dst_file
        fi
    else
        cp $src_file $dst_file
    fi
}

install_anaconda()
{
        which anaconda >/dev/null
        if [ "$?" = "0" ] ; then
                echo "Anaconda3 is already installed!"
                return 0
        fi
        # install anaconda python environment
        ver="2021.05"
        prompt "开始下载 Anaconda3... ver:[$ver], file size : 500MB+"
        wget -c https://repo.anaconda.com/archive/Anaconda3-${ver}-Linux-x86_64.sh
        prompt "开始安装 Anaconda3...(默认安装位置为： ${python_install_path})"
        if [ "$?" != "0"] ; then
            read tmp_input
            if [ "$tmp_input" != "" -a  -r `basename $tmp_input` ] ; then
            fi
        fi
        sh Anaconda3-${ver}-Linux-x86_64.sh -p ${python_install_path} -b
        . ${python_install_path}/etc/profile.d/conda.sh
        conda init zsh
}

config_rc(){
    # 配置基础资源环境
    # 配置zsh、 vim、 tmux、 Anaconda3环境
    echo
    prompt "安装基础环境"
    str_ret="$?"
    if [ "$str_ret" != "0" ] ; then
        # 取消继续执行
        return "$str_ret"
    fi
    case "$os_type" in 
        manjaro)
            # 添加fcitx输入法环境变量配置文件
            copy_file ./dotfiles/xprofile $HOME/.xprofile
            # 配置 oh-my-zsh
            sudo ${pac_cmd_ins} zsh
            user_name=`whoami`
            zsh_path=`which zsh`
            prompt "更换用户 [$user_name] 的默认shell 为 [$zsh_path]"
            sudo chsh -s $zsh_path $user_name
            prompt "安装oh-my-zsh"
            sudo ${pac_cmd_ins} curl git
            # sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
            wget -O install-ohmyz.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
            sh ./install-ohmyz.sh --unattended --skip-chsh --keep-zshrc
            # clone
            font_tmp_dir=/tmp/zsh_fonts
            git clone https://github.com/powerline/fonts.git --depth=1 $font_tmp_dir
            # install
            cd $font_tmp_dir && sh ./install.sh && cd - && rm -rf $font_tmp_dir
            copy_file ./dotfiles/zshrc $HOME/.zshrc
            
            # 配置 vim 
            prompt "开始安装VIM"
            sudo $pac_cmd_ins  vim
            copy_file ./dotfiles/vimrc $HOME/.vimrc

            prompt "开始配置Vundle插件管理器"
            mkdir -p $HOME/.vim/bundle/
            git clone https://github.com/VundleVim/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim
            prompt "开始安装VIM插件"
            vim +PluginInstall +qall
            
            # 配置 tmux
            sudo $pac_cmd_ins tmux
            copy_file ./dotfiles/tmux.conf $HOME/.tmux.conf
            ;;
        *)
            echo "$os_type 系统类型不支持！"
            ;;
    esac
}

check_desktop_env(){
    # 检查桌面环境 , 返回 0 表示支持当前桌面环境， 返回 1 表示不支持
    case "$XDG_CURRENT_DESKTOP" in
        KDE)
            gui_type="kde"
            ;;
        *)
            gui_type="unknown"
            return 1
            ;;
    esac
    return 0
}

config_desktop_theme(){
    # 安装配置桌面主题
    echo 
    prompt "开始安装桌面主题"
    str_ret="$?"
    if [ "$str_ret" != "0" ] ; then
        # 取消继续执行
        return "$str_ret"
    fi
    case "$gui_type" in 
        kde*|KDE*)
            # 安装 latte-dock
            sudo $pac_cmd_ins latte-dock numix-icon-theme-git
            # 主题下载
            mkdir -p ./themes
            prompt "安装全局主题-[WhiteSur-kde]"
            str_ret="$?"
            if [ "$str_ret" = "0" ] ; then
                git clone https://github.com/vinceliuice/WhiteSur-kde.git  themes/WhiteSur-kde
                cd themes/WhiteSur-kde  && sh ./install.sh && cd -
                cd themes/WhiteSur-kde/sddm  && sudo sh ./install.sh && cd -
                prompt "安装Icons主题-[WhiteSur-icon-theme]"
                git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git  themes/WhiteSur-icon-theme
                cd themes/WhiteSur-icon-theme && sh ./install.sh && cd -
            fi
            prompt "安装主题-[McMojave-circle]"
            str_ret="$?"
            if [ "$str_ret" = "0" ] ; then
                git clone https://github.com/vinceliuice/McMojave-circle.git  themes/McMojave-circle
                cd themes/McMojave-circle  && sh ./install.sh --all && cd -
            fi
            prompt "安装GRUB2主题-[grub2-themes]"
            str_ret="$?"
            if [ "$str_ret" = "0" ] ; then
                git clone https://github.com/vinceliuice/grub2-themes.git  themes/grub2-themes
                cd themes/grub2-themes  && sudo ./install.sh -b -t whitesur && cd -
            fi
            
            # 主题设置
            echo "当前系统安装的主题列表："
            lookandfeeltool -l
            your_theme="com.github.vinceliuice.WhiteSur"
            echo -e "输入需要应用的主题(default:WhiteSur):\c" 
            read str_answer
            if [ "$str_answer" != "" ] ; then
                your_theme="$str_answer"
            fi
            lookandfeeltool -a $your_theme

            echo "=============================================================="
            echo "="
            echo "= 更多主题设置可以使用 systemsettings 图形界面进行设置"
            echo "="
            echo "=============================================================="
            ;;
        *)
            echo "$os_type 系统类型不支持！"
            ;;
    esac
}


config_software_package(){
    # 安装必备的软件包资源
    # 安装列表： 网络工具包 , 中文输入法， 谷歌Chrome浏览器， 网易云音乐
    echo 
    prompt "开始安装必备的软件包资源，浏览器、中文输入法、网易云音乐等"
    str_ret="$?"
    if [ "$str_ret" != "0" ] ; then
        # 取消继续执行
        return "$str_ret"
    fi
    case "$os_type" in 
        manjaro)
            yay -S  --needed --noconfirm  git net-tools fcitx fcitx-configtool fcitx-cloudpinyin fcitx-googlepinyin google-chrome netease-cloud-music
            sudo $pac_cmd_ins gcc make cmake
            ;;
        *)
            echo "$os_type 系统类型不支持！"
            ;;
    esac
}


main(){
    check_sys
    check_desktop_env
    config_repo
    config_software_package
    config_rc
    install_anaconda        # 下载安装 Anaconda3 环境
    config_desktop_theme
 }


usage(){
    # 使用帮助信息
    cat <<END
Usage:
    `basename $0` [-y]

Brief：
    -y  : 使用默认yes确认一切，不需要人工交互确认，默认情况下是确认安装的每一个环节
END
}


############ 开始执行入口 ######

while getopts gyb:c: arg_val
do
    case "$arg_val" in
        y)
            default_confirm="yes"
            ;;
        *)
            usage
            exit 0
            ;;
    esac
done

prompt "准备开始安装！"
main
prompt "安装配置过程结束！"
