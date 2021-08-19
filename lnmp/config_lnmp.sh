#!/usr/bin/env bash
######################################
#
#   配置LNMP模块
#
######################################

# 检查变量是否为空
check_var_blank() {
    str_var="$1"
    str_ret=$2
    str_msg="$3"
    if [ "$str_var" = "" ] ; then
        echo "$str_msg"
        exit $str_ret
    fi
}

domain_name=""   # 替换 example.com 为个人域名地址
webroot_dir=""     # Web服务部署的根目录
mysql_root_password=""  # MySQL数据库root密码

check_var_blank "${domain_name}" 100 "请先设置自己的域名地址 {domain_name} 再次执行。"
check_var_blank "$webroot_dir" 101 "请先设置自己的站点部署根目录 {webroot_dir} 再次执行。"
check_var_blank "$mysql_root_password" 102 echo "请先设置MySQL的root密码 {mysql_root_password} 再次执行。"


config_nginx_on_centos8() {
    echo "配置Nginx"
    vhost_file="https.conf"
    sed "s/example.com/${domain_name}/g" ./conf/${vhost_file}   > /etc/nginx/conf.d/${vhost_file}
    if [[ -f "/etc/nginx/conf.d/${vhost_file}" ]] ; then
        echo "已生成 /etc/nginx/conf.d/${vhost_file} 文件."
    fi
    locations_file="https_php.conf"
    sed "s/your-webroot-path/${webroot_dir}/g" ./conf/${locations_file} > /etc/nginx/default.d/${locations_file}
    if [[ -f "/etc/nginx/default.d/${locations_file}" ]] ; then
        echo "已生成 /etc/nginx/default.d/${locations_file} 文件."
    fi
    
    echo "PSF完美前向加密，生成方法："
    [[ -f /etc/ssl/private/dhparam.pem ]] || ( mkdir -p /etc/ssl/private/ && openssl dhparam -out /etc/ssl/private/dhparam.pem 2048 )
    echo "生成 SSL 证书(从Let's Encrypt获取免费SSL证书)，使用certbot下载获取"
    dnf install -y epel-release
    dnf install -y certbot
    # 使用nginx申请SSL证书
    certbot --nginx -d ${domain_name}
    echo "如果执行成功，会在 /etc/nginx/conf.d/${vhost_file} 文件中看到centbot添加信息："
    if grep -i certbot /etc/nginx/conf.d/${vhost_file} ; then
        echo ""
        echo "检测添加SSL证书  成功！"
        echo "如果不希望强制重定向http服务到https服务，可以自己删除重定向添加部分"
    else
        echo "检测不到SSL证书信息! 添加失败!"
        echo "如果多次添加失败，可以手工通过DNS方式申请成功后再添加."
        return 1
    fi
    echo "添加定时自动更新SSL证书调度："
    crontab -l > /tmp/crontab.txt
    if grep "certbot renew" /tmp/crontab.txt ; then
        echo "已经添加过 自动更新SSL证书调度!"
    else
        echo "# 每两月的1日1点00分，执行SSL证书延期命令" >> /tmp/crontab.txt
        echo "00 01 01 */2 * /usr/bin/certbot renew --quiet"  >> /tmp/crontab.txt
        crontab /tmp/crontab.txt && rm -f /tmp/crontab.txt
    fi
    echo "Nginx SSL证书配置完成！"
    nginx -t && systemctl restart nginx && systemctl enable nginx
}

config_php_on_centos8(){
    echo "配置PHP"
    php_fpm_file="/etc/php-fpm.d/www.conf"
    cp ${php_fpm_file} ${php_fpm_file}.`date +%Y%m%d`
    sed -i "s/^user = apache/user = nginx/;s/group = apache/group = nginx/;s#^listen = .*#listen = /run/php-fpm/www.sock#;s/;listen.owner = nobody/listen.owner = nginx/;s/;listen.group = nobody/listen.group = nginx/;" /etc/php-fpm.d/www.conf
    php-fpm -t && systemctl enable --now php-fpm
    if [ "$?" != "0" ] ; then
        echo "启动php-fpm 失败！"
        return 1
    fi
    echo "启动并设置开机自启动PHP-FPM服务 成功！"
}

config_mysql_on_centos8() {
    echo "启动MySQL服务"
    systemctl enable --now mysqld
    systemctl status mysqld
    if [ "$?" != "0" ] ; then
        echo "MySQL启动失败！"
        return 1
    fi
    echo "配置MySQL数据库："
    # 更新root用户密码
    mysql -e "UPDATE mysql.user SET Password = PASSWORD('${mysql_root_password}') WHERE User = 'root'"
    # 禁止匿名用户登录
    mysql -e "DROP USER ''@'localhost'"
    mysql -e "DROP USER ''@'$(hostname)'"
    # 删除测试数据库test
    mysql -e "DROP DATABASE test"
    # 使修改内容生效
    mysql -e "FLUSH PRIVILEGES"
    echo "现在必须使用密码登录MySQL数据库了"
    echo "执行命令如下： mysql -u root -p"
}


config_lnmp_on_centos8() {
    echo "开始配置 lnmp on CentOS8:"
    config_nginx_on_centos8 || return 1
    config_php_on_centos8   || return 2
    config_mysql_on_centos8 || return 3
}


config_lnmp_on_centos8

