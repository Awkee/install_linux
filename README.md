# install_linux
> Linux安装各种一键配置脚本.

## 脚本介绍

- config_linux.sh : 自动配置Linux桌面环境脚本，设置默认zsh、配置zshrc文件、VIM环境、tmux配置、自定义Python环境(安装Anaconda3版本)
- lnmp/install_lnmp.sh : 自动安装LNMP环境
- lnmp/config_lnmp.sh : 自动配置LNMP环境(自动配置SSL证书，HTTPS服务, 设置MySQL数据库root口令及PHP-FPM服务配置)
- proxy/install_ss.sh  : 自动安装**GoLang版本Shadowsocks****服务端/客户端脚本**，支持BBR加速设置、iptables防火墙设置。


## 自动配置Linux桌面环境脚本使用方法

查看帮助信息：
```bash
$ ./config_linux.sh -h
Usage:
    config_linux.sh [-y]

Brief：
    -y  : 使用默认yes确认一切，不需要人工交互确认，默认情况下是确认安装的每一个环节
```
使用非常简单，使用`-y`选项即选择安静无人值守安装。




## LNMP安装配置脚本使用方法

```
git clone https://github.com/Awkee/install_linux.git
cd lnmp
```

说明：使用脚本前，需要设置一些变量参数信息：

例如：`config_lnmp.sh` 脚本中如下变量：
```bash
domain_name=""   # 替换 example.com 为个人域名地址
webroot_dir=""     # Web服务部署的根目录
mysql_root_password=""  # MySQL数据库root密码

```

`install_lnmp.sh`脚本中的如下变量也是可以选择的,前提是你知道安装源是否包含正确的版本号软件包：
```bash
nginx_ver="1.20.1"  # 安装Nginx版本号
php_ver="7.4"       # 安装PHP版本号
```

设置好，接下来就可以执行脚本了：


```bash
./install_lnmp.sh
./config_lnmp.sh
```

安装配置完成后，即可部署`Wordpress`、`Typecho`或者你个人的PHP项目了，这个过程就不介绍了。

## proxy/install_ss.sh自动安装SS脚本
> SS服务端安装方法很多，本脚本采用的是[GoLang版本](https://github.com/shadowsocks/go-shadowsocks2/releases)，支持**AEAD加密方式**。

脚本短地址： [https://git.io/JzXAg](https://git.io/JzXAg)
脚本的使用介绍如下：
```bash
$ ./install_ss.sh -h

Usage:
    install_ss.sh server                        # 第一次安装服务端
    install_ss.sh uninstall                     # 卸载服务端安装软件及配置，默认端口12345
    install_ss.sh uninstall  port               # 卸载服务端安装软件及配置，自定义端口port

    install_ss.sh client uri  port              # 第一次安装客户端
    install_ss.sh uninstall  client             # 卸载客户端安装软件及配置

    install_ss.sh enable_bbr                    # 启用BBR加速(服务端第一次安装自动开启)

```

服务器安装命令：
```
curl -o install_ss.sh https://git.io/JzXAg
sh ./install_ss.sh server
```
根据提示，选择或者使用默认值都可以。

成功后，会提示客户端使用的SS链接地址。

> 了解更多关于[AEAD加密方法](https://shadowsocks.org/en/wiki/AEAD-Ciphers.html)。


---
