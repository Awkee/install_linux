#!/usr/bin/env bash
######################################
#
#   安装LNMP模块
#
######################################


nginx_ver="1.20.1"  # 安装Nginx版本号
php_ver="7.4"       # 安装PHP版本号
mysql_ver=`dnf info mysql-server | awk '/Version|版本/{ print $3 }'`    # 安装系统默认MySQL版本号

install_nginx_on_centos8() {
    echo "安装Nginx"
    dnf -y install http://nginx.org/packages/centos/8/x86_64/RPMS/nginx-${nginx_ver}-1.el8.ngx.x86_64.rpm
    if nginx -v | grep $nginx_ver ; then
        echo "安装Nginx 成功!"
    else
        echo "安装Nginx 失败!"
        return 1
    fi
}

install_mysql_on_centos8() {
    echo "安装Mysql"
    dnf -y install @mysql
    if mysql -V  ； then
        echo "安装MySQL 成功！"
    else
        echo "安装MySQL 失败！"
        return 1
    fi
}

install_php_on_centos8(){
    echo "安装PHP："
    dnf -y install epel-release
    dnf update epel-release
    dnf clean all
    dnf makecache
    # 先安装remi源
    dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm
    dnf module enable -y php:${php_ver}
    dnf -y install php php-curl php-dom php-exif php-fileinfo php-fpm php-gd php-hash php-json php-mbstring php-mysqli php-openssl php-pcre php-xml libsodium

    if php -v ; then
        echo "安装PHP-${php_ver} 成功！"
    else
        echo "安装PHP-${php_ver} 失败！"
        return 1
    fi
}

check_lnmp_on_centos8() {
    echo "======================================"
    echo "##  安装成功！检测系统当前LNMP版本信息 "
    echo "Nginx Version:"  ||  nginx -v
    echo "MySQL Version:"  ||  mysql -V
    echo "PHP   Version:"  ||  php -v
    echo "======================================"
    
}

install_lnmp_on_centos8() {
    echo "======================================"
    echo "开始安装部署LNMP环境："
    echo "==== Nginx : ${nginx_ver} "
    echo "==== MySQL : ${mysql_ver}"
    echo "==== PHP   : ${php_ver} "
    echo "======================================"
    
    install_nginx_on_centos8 || return 1
    install_mysql_on_centos8 || return 2
    install_php_on_centos8   || return 3

    check_lnmp_on_centos8
}

install_lnmp_on_centos8
