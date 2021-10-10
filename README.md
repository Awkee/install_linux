# install_linux
> Linux安装各种一键配置脚本.

## 脚本介绍

- config_linux.sh : 自动配置Linux桌面环境脚本，设置默认zsh、配置zshrc文件、VIM环境、tmux配置、自定义Python环境(安装Anaconda3版本)
- lnmp/install_lnmp.sh : 自动安装LNMP环境
- lnmp/config_lnmp.sh : 自动配置LNMP环境(自动配置SSL证书，HTTPS服务, 设置MySQL数据库root口令及PHP-FPM服务配置)


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


## 更详细文档

了解更详细的使用介绍，可以进入[wiki](https://github.com/Awkee/install_linux/wiki)了解。

---
