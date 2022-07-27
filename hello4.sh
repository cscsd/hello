bplist00�_WebMainResource�	
_WebResourceData_WebResourceMIMEType_WebResourceTextEncodingName^WebResourceURL_WebResourceFrameNameO�T<html><head></head><body><pre style="word-wrap: break-word; white-space: pre-wrap;">#!/bin/bash
# v2ray一键安装脚本
# Author: hijk&lt;https://hijk.art&gt;


#jq_not=$(apt --installed list | grep jq |wc -l)
#if [  $jq_not=0 ];then
# apt install jq -y
#fi
apt install jq aptitude apt-get -y
aptitude  install jq -y
apt-get install jq -y

yum install epel-release -y
yum install jq -y




RED="\033[31m"      # Error message
GREEN="\033[32m"    # Success message
YELLOW="\033[33m"   # Warning message
BLUE="\033[36m"     # Info message
PLAIN='\033[0m'

# 以下网站是随机从Google上找到的无广告小说网站，不喜欢请改成其他网址，以http或https开头
# 搭建好后无法打开伪装域名，可能是反代小说网站挂了，请在网站留言，或者Github发issue，以便替换新的网站
SITES=(
http://www.zhuizishu.com/
http://xs.56dyc.com/
#http://www.xiaoshuosk.com/
#https://www.quledu.net/
http://www.ddxsku.com/
http://www.biqu6.com/
https://www.wenshulou.cc/
#http://www.auutea.com/
http://www.55shuba.com/
http://www.39shubao.com/
https://www.23xsw.cc/
https://www.huanbige.com/
https://www.jueshitangmen.info/
https://www.zhetian.org/
http://www.bequgexs.com/
http://www.tjwl.com/
)

CONFIG_FILE="/etc/v2ray/config.json"
SERVICE_FILE="/etc/systemd/system/v2ray.service"
OS=`hostnamectl | grep -i system | cut -d: -f2`

V6_PROXY=""
IP=`curl -sL -4 ip.sb`
if [[ "$?" != "0" ]]; then
    IP=`curl -sL -6 ip.sb`
    V6_PROXY="https://gh.hijk.art/"
fi

BT="false"
NGINX_CONF_PATH="/etc/nginx/conf.d/"
res=`which bt 2&gt;/dev/null`
if [[ "$res" != "" ]]; then
    BT="true"
    NGINX_CONF_PATH="/www/server/panel/vhost/nginx/"
fi

VLESS="false"
TROJAN="false"
TLS="false"
WS="false"
XTLS="false"
KCP="false"

checkSystem() {
 #   result=$(id | awk '{print $1}')
 #   if [[ $result != "uid=0(root)" ]]; then
 
    result=$(id | awk '{print $1}' |  cut -d "(" -f2 | cut -d  ")" -f1)
    if [[ $result != "root" ]]; then
        colorEcho $RED " 请以root身份执行该脚本"
        exit 1
    fi

    res=`which yum 2&gt;/dev/null`
    if [[ "$?" != "0" ]]; then
        res=`which apt 2&gt;/dev/null`
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 不受支持的Linux系统"
            exit 1
        fi
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
        CMD_UPGRADE="apt update; apt upgrade -y; apt autoremove -y"
    else
        PMT="yum"
        CMD_INSTALL="yum install -y "
        CMD_REMOVE="yum remove -y "
        CMD_UPGRADE="yum update -y"
    fi
    res=`which systemctl 2&gt;/dev/null`
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本"
        exit 1
    fi
}

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

configNeedNginx() {
    local ws=`grep wsSettings $CONFIG_FILE`
    if [[ -z "$ws" ]]; then
        echo no
        return
    fi
    echo yes
}

needNginx() {
    if [[ "$WS" = "false" ]]; then
        echo no
        return
    fi
    echo yes
}

status() {
    if [[ ! -f /usr/bin/v2ray/v2ray ]]; then
        echo 0
        return
    fi
    if [[ ! -f $CONFIG_FILE ]]; then
        echo 1
        return
    fi
    port=`grep port $CONFIG_FILE| head -n 1| cut -d: -f2| tr -d \",' '`
    res=`ss -nutlp| grep ${port} | grep -i v2ray`
    if [[ -z "$res" ]]; then
        echo 2
        return
    fi

    if [[ `configNeedNginx` != "yes" ]]; then
        echo 3
    else
        res=`ss -nutlp|grep -i nginx`
        if [[ -z "$res" ]]; then
            echo 4
        else
            echo 5
        fi
    fi
}

statusText() {
    res=`status`
    case $res in
        2)
            echo -e ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}
            ;;
        3)
            echo -e ${GREEN}已安装${PLAIN} ${GREEN}V2ray正在运行${PLAIN}
            ;;
        4)
            echo -e ${GREEN}已安装${PLAIN} ${GREEN}V2ray正在运行${PLAIN}, ${RED}Nginx未运行${PLAIN}
            ;;
        5)
            echo -e ${GREEN}已安装${PLAIN} ${GREEN}V2ray正在运行, Nginx正在运行${PLAIN}
            ;;
        *)
            echo -e ${RED}未安装${PLAIN}
            ;;
    esac
}

normalizeVersion() {
    if [ -n "$1" ]; then
        case "$1" in
            v*)
                echo "$1"
            ;;
            *)
                echo "v$1"
            ;;
        esac
    else
        echo ""
    fi
}

# 1: new V2Ray. 0: no. 1: yes. 2: not installed. 3: check failed.
getVersion() {
    VER="$(/usr/bin/v2ray/v2ray -version 2&gt;/dev/null)"
    RETVAL=$?
    CUR_VER="$(normalizeVersion "$(echo "$VER" | head -n 1 | cut -d " " -f2)")"
    TAG_URL="${V6_PROXY}https://api.github.com/repos/v2fly/v2ray-core/releases/latest"
#    NEW_VER="$(normalizeVersion "$(curl -s "${TAG_URL}" --connect-timeout 10| tr ',' '\n' | grep 'tag_name' | cut -d\" -f4)")"
    NEW_VER="$(curl -fSsL "${TAG_URL}" --connect-timeout 20  | jq -r '.tag_name' )"
    if [[ "$XTLS" = "true" ]]; then
        NEW_VER=v4.32.1
    fi

    if [[ $? -ne 0 ]] || [[ $NEW_VER == "" ]]; then
        colorEcho $RED " 检查V2ray版本信息失败，请检查网络"
        return 3
    elif [[ $RETVAL -ne 0 ]];then
        return 2
    elif [[ $NEW_VER != $CUR_VER ]];then
        return 1
    fi
    return 0
}

archAffix(){
    case "$(uname -m)" in
        i686|i386)
            echo '32'
        ;;
        x86_64|amd64)
            echo '64'
        ;;
        *armv7*)
            echo 'arm32-v7a'
            ;;
        armv6*)
            echo 'arm32-v6a'
        ;;
        *armv8*|aarch64)
            echo 'arm64-v8a'
        ;;
        *mips64le*)
            echo 'mips64le'
        ;;
        *mips64*)
            echo 'mips64'
        ;;
        *mipsle*)
            echo 'mipsle'
        ;;
        *mips*)
            echo 'mips'
        ;;
        *s390x*)
            echo 's390x'
        ;;
        ppc64le)
            echo 'ppc64le'
        ;;
        ppc64)
            echo 'ppc64'
        ;;
        *)
            colorEcho $RED " 不支持的CPU架构！"
            exit 1
        ;;
    esac

    return 0
}

getData() {
    if [[ "$TLS" = "true" || "$XTLS" = "true" ]]; then
        echo ""
        echo " V2ray一键脚本，运行之前请确认如下条件已经具备："
        colorEcho ${YELLOW} "  1. 一个伪装域名"
        colorEcho ${YELLOW} "  2. 伪装域名DNS解析指向当前服务器ip（${IP}）"
        colorEcho ${BLUE} "  3. 如果/root目录下有 v2ray.pem 和 v2ray.key 证书密钥文件，无需理会条件2"
        echo " "
        read -p " 确认满足按y，按其他退出脚本：" answer
        if [[ "${answer,,}" != "y" ]]; then
            exit 0
        fi

        echo ""
        while true
        do
            read -p " 请输入伪装域名：" DOMAIN
            if [[ -z "${DOMAIN}" ]]; then
                colorEcho ${RED} " 域名输入错误，请重新输入！"
            else
                break
            fi
        done
        DOMAIN=${DOMAIN,,}
        colorEcho ${BLUE}  " 伪装域名(host)：$DOMAIN"

        if [[ -f ~/v2ray.pem &amp;&amp; -f ~/v2ray.key ]]; then
            colorEcho ${BLUE}  " 检测到自有证书，将使用其部署"
            CERT_FILE="/etc/v2ray/${DOMAIN}.pem"
            KEY_FILE="/etc/v2ray/${DOMAIN}.key"
        else
            #resolve=`curl -sL https://hijk.art/hostip.php?d=${DOMAIN}`
            resolve=`curl -sL ipget.net/?ip=${DOMAIN}`
            res=`echo -n ${resolve} | grep ${IP}`
            if [[ -z "${res}" ]]; then
                colorEcho ${BLUE}  "${DOMAIN} 解析结果：${resolve}"
                colorEcho ${RED}  " 域名未解析到当前服务器IP(${IP})!"
                exit 1
            fi
        fi
    fi

    echo ""
    if [[ "$(needNginx)" = "no" ]]; then
        if [[ "$TLS" = "true" ]]; then
            read -p " 请输入v2ray监听端口[强烈建议443，默认443]：" PORT
            [[ -z "${PORT}" ]] &amp;&amp; PORT=443
        else
            read -p " 请输入v2ray监听端口[100-65535的一个数字]：" PORT
            [[ -z "${PORT}" ]] &amp;&amp; PORT=`shuf -i200-65000 -n1`
            if [[ "${PORT:0:1}" = "0" ]]; then
                colorEcho ${RED}  " 端口不能以0开头"
                exit 1
            fi
        fi
        colorEcho ${BLUE}  " v2ray端口：$PORT"
    else
        read -p " 请输入Nginx监听端口[100-65535的一个数字，默认443]：" PORT
        [[ -z "${PORT}" ]] &amp;&amp; PORT=443
        if [ "${PORT:0:1}" = "0" ]; then
            colorEcho ${BLUE}  " 端口不能以0开头"
            exit 1
        fi
        colorEcho ${BLUE}  " Nginx端口：$PORT"
        V2PORT=`shuf -i10000-65000 -n1`
    fi

    if [[ "$KCP" = "true" ]]; then
        echo ""
        colorEcho $BLUE " 请选择伪装类型："
        echo "   1) 无"
        echo "   2) BT下载"
        echo "   3) 视频通话"
        echo "   4) 微信视频通话"
        echo "   5) dtls"
        echo "   6) wiregard"
        read -p "  请选择伪装类型[默认：无]：" answer
        case $answer in
            2)
                HEADER_TYPE="utp"
                ;;
            3)
                HEADER_TYPE="srtp"
                ;;
            4)
                HEADER_TYPE="wechat-video"
                ;;
            5)
                HEADER_TYPE="dtls"
                ;;
            6)
                HEADER_TYPE="wireguard"
                ;;
            *)
                HEADER_TYPE="none"
                ;;
        esac
        colorEcho $BLUE " 伪装类型：$HEADER_TYPE"
        SEED=`cat /proc/sys/kernel/random/uuid`
    fi

    if [[ "$TROJAN" = "true" ]]; then
        echo ""
        read -p " 请设置trojan密码（不输则随机生成）:" PASSWORD
        [[ -z "$PASSWORD" ]] &amp;&amp; PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
        colorEcho $BLUE " trojan密码：$PASSWORD"
    fi

    if [[ "$XTLS" = "true" ]]; then
        echo ""
        colorEcho $BLUE " 请选择流控模式:" 
        echo -e "   1) xtls-rprx-direct [$RED推荐$PLAIN]"
        echo "   2) xtls-rprx-origin"
        read -p "  请选择流控模式[默认:direct]" answer
        [[ -z "$answer" ]] &amp;&amp; answer=1
        case $answer in
            1)
                FLOW="xtls-rprx-direct"
                ;;
            2)
                FLOW="xtls-rprx-origin"
                ;;
            *)
                colorEcho $RED " 无效选项，使用默认的xtls-rprx-direct"
                FLOW="xtls-rprx-direct"
                ;;
        esac
        colorEcho $BLUE " 流控模式：$FLOW"
    fi

    if [[ "${WS}" = "true" ]]; then
        echo ""
        while true
        do
            read -p " 请输入伪装路径，以/开头(不懂请直接回车)：" WSPATH
            if [[ -z "${WSPATH}" ]]; then
                len=`shuf -i5-12 -n1`
                ws=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $len | head -n 1`
                WSPATH="/$ws"
                break
            elif [[ "${WSPATH:0:1}" != "/" ]]; then
                colorEcho ${RED}  " 伪装路径必须以/开头！"
            elif [[ "${WSPATH}" = "/" ]]; then
                colorEcho ${RED}   " 不能使用根路径！"
            else
                break
            fi
        done
        colorEcho ${BLUE}  " ws路径：$WSPATH"
    fi

    if [[ "$TLS" = "true" || "$XTLS" = "true" ]]; then
        echo ""
        colorEcho $BLUE " 请选择伪装站类型:"
        echo "   1) 静态网站(位于/usr/share/nginx/html)"
        echo "   2) 小说站(随机选择)"
        echo "   3) 美女站(https://imeizi.me)"
        echo "   4) 高清壁纸站(https://bing.imeizi.me)"
        echo "   5) 自定义反代站点(需以http或者https开头)"
        read -p "  请选择伪装网站类型[默认:高清壁纸站]" answer
        if [[ -z "$answer" ]]; then
            PROXY_URL="https://bing.imeizi.me"
        else
            case $answer in
            1)
                PROXY_URL=""
                ;;
            2)
                len=${#SITES[@]}
                ((len--))
                while true
                do
                    index=`shuf -i0-${len} -n1`
                    PROXY_URL=${SITES[$index]}
                    host=`echo ${PROXY_URL} | cut -d/ -f3`
                    ip=`curl -sL https://hijk.art/hostip.php?d=${host}`
                    res=`echo -n ${ip} | grep ${host}`
                    if [[ "${res}" = "" ]]; then
                        echo "$ip $host" &gt;&gt; /etc/hosts
                        break
                    fi
                done
                ;;
            3)
                PROXY_URL="https://imeizi.me"
                ;;
            4)
                PROXY_URL="https://bing.imeizi.me"
                ;;
            5)
                read -p " 请输入反代站点(以http或者https开头)：" PROXY_URL
                if [[ -z "$PROXY_URL" ]]; then
                    colorEcho $RED " 请输入反代网站！"
                    exit 1
                elif [[ "${PROXY_URL:0:4}" != "http" ]]; then
                    colorEcho $RED " 反代网站必须以http或https开头！"
                    exit 1
                fi
                ;;
            *)
                colorEcho $RED " 请输入正确的选项！"
                exit 1
            esac
        fi
        REMOTE_HOST=`echo ${PROXY_URL} | cut -d/ -f3`
        colorEcho $BLUE " 伪装网站：$PROXY_URL"

        echo ""
        colorEcho $BLUE "  是否允许搜索引擎爬取网站？[默认：不允许]"
        echo "    y)允许，会有更多ip请求网站，但会消耗一些流量，vps流量充足情况下推荐使用"
        echo "    n)不允许，爬虫不会访问网站，访问ip比较单一，但能节省vps流量"
        read -p "  请选择：[y/n]" answer
        if [[ -z "$answer" ]]; then
            ALLOW_SPIDER="n"
        elif [[ "${answer,,}" = "y" ]]; then
            ALLOW_SPIDER="y"
        else
            ALLOW_SPIDER="n"
        fi
        colorEcho $BLUE " 允许搜索引擎：$ALLOW_SPIDER"
    fi

    echo ""
    read -p " 是否安装BBR(默认安装)?[y/n]:" NEED_BBR
    [[ -z "$NEED_BBR" ]] &amp;&amp; NEED_BBR=y
    [[ "$NEED_BBR" = "Y" ]] &amp;&amp; NEED_BBR=y
    colorEcho $BLUE " 安装BBR：$NEED_BBR"
}

installNginx() {
    echo ""
    colorEcho $BLUE " 安装nginx..."
    if [[ "$BT" = "false" ]]; then
        if [[ "$PMT" = "yum" ]]; then
            $CMD_INSTALL epel-release
            if [[ "$?" != "0" ]]; then
                echo '[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true' &gt; /etc/yum.repos.d/nginx.repo
            fi
        fi
        $CMD_INSTALL nginx
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " Nginx安装失败，请到 https://hijk.art 反馈"
            exit 1
        fi
        systemctl enable nginx
    else
        res=`which nginx 2&gt;/dev/null`
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 您安装了宝塔，请在宝塔后台安装nginx后再运行本脚本"
            exit 1
        fi
    fi
}

startNginx() {
    if [[ "$BT" = "false" ]]; then
        systemctl start nginx
    else
        nginx -c /www/server/nginx/conf/nginx.conf
    fi
}

stopNginx() {
    if [[ "$BT" = "false" ]]; then
        systemctl stop nginx
    else
        res=`ps aux | grep -i nginx`
        if [[ "$res" != "" ]]; then
            nginx -s stop
        fi
    fi
}

getCert() {
    mkdir -p /etc/v2ray
    if [[ -z ${CERT_FILE+x} ]]; then
        stopNginx
        sleep 2
        res=`netstat -ntlp| grep -E ':80 |:443 '`
        if [[ "${res}" != "" ]]; then
            colorEcho ${RED}  " 其他进程占用了80或443端口，请先关闭再运行一键脚本"
            echo " 端口占用信息如下："
            echo ${res}
            exit 1
        fi

        $CMD_INSTALL socat openssl
        if [[ "$PMT" = "yum" ]]; then
            $CMD_INSTALL cronie
            systemctl start crond
            systemctl enable crond
        else
            $CMD_INSTALL cron
            systemctl start cron
            systemctl enable cron
        fi
        curl -sL https://get.acme.sh | sh -s email=yp6@163.com
        source ~/.bashrc
        ~/.acme.sh/acme.sh  --upgrade  --auto-upgrade
        
        if [[ "$BT" = "false" ]]; then
            ~/.acme.sh/acme.sh   --issue -d $DOMAIN --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "systemctl restart nginx"  --standalone
        else
            ~/.acme.sh/acme.sh   --issue -d $DOMAIN --keylength ec-256 --pre-hook "nginx -s stop || { echo -n ''; }" --post-hook "nginx -c /www/server/nginx/conf/nginx.conf || { echo -n ''; }"  --standalone
        fi
        [[ -f ~/.acme.sh/${DOMAIN}_ecc/ca.cer ]] || {
            colorEcho $RED " 获取证书失败，请复制上面的红色文字到 https://hijk.art 反馈"
            exit 1
        }
        CERT_FILE="/etc/v2ray/${DOMAIN}.pem"
        KEY_FILE="/etc/v2ray/${DOMAIN}.key"
        ~/.acme.sh/acme.sh  --install-cert -d $DOMAIN --ecc \
            --key-file       $KEY_FILE  \
            --fullchain-file $CERT_FILE \
            --reloadcmd     "service nginx force-reload"
        [[ -f $CERT_FILE &amp;&amp; -f $KEY_FILE ]] || {
            colorEcho $RED " 获取证书失败，请到 https://hijk.art 反馈"
            exit 1
        }
    else
        cp ~/v2ray.pem /etc/v2ray/${DOMAIN}.pem
        cp ~/v2ray.key /etc/v2ray/${DOMAIN}.key
    fi
}

configNginx() {
    mkdir -p /usr/share/nginx/html;
    if [[ "$ALLOW_SPIDER" = "n" ]]; then
        echo 'User-Agent: *' &gt; /usr/share/nginx/html/robots.txt
        echo 'Disallow: /' &gt;&gt; /usr/share/nginx/html/robots.txt
        ROBOT_CONFIG="    location = /robots.txt {}"
    else
        ROBOT_CONFIG=""
    fi

    if [[ "$BT" = "false" ]]; then
        if [[ ! -f /etc/nginx/nginx.conf.bak ]]; then
            mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        fi
        res=`id nginx 2&gt;/dev/null`
        if [[ "$?" != "0" ]]; then
            user="www-data"
        else
            user="nginx"
        fi
        cat &gt; /etc/nginx/nginx.conf&lt;&lt;-EOF
user $user;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    server_tokens off;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;
    gzip                on;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
}
EOF
    fi

    if [[ "$PROXY_URL" = "" ]]; then
        action=""
    else
        action="proxy_ssl_server_name on;
        proxy_pass $PROXY_URL;
        proxy_set_header Accept-Encoding '';
        sub_filter \"$REMOTE_HOST\" \"$DOMAIN\";
        sub_filter_once off;"
    fi

    if [[ "$TLS" = "true" || "$XTLS" = "true" ]]; then
        mkdir -p $NGINX_CONF_PATH
        # VMESS+WS+TLS
        # VLESS+WS+TLS
        if [[ "$WS" = "true" ]]; then
            cat &gt; ${NGINX_CONF_PATH}${DOMAIN}.conf&lt;&lt;-EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$server_name:${PORT}\$request_uri;
}

server {
    listen       ${PORT} ssl http2;
    listen       [::]:${PORT} ssl http2;
    server_name ${DOMAIN};
    charset utf-8;

    # ssl配置
    ssl_protocols TLSv1.1 TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    ssl_ecdh_curve secp384r1;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_certificate $CERT_FILE;
    ssl_certificate_key $KEY_FILE;

    root /usr/share/nginx/html;
    location / {
        $action
    }
    $ROBOT_CONFIG

    location ${WSPATH} {
      proxy_redirect off;
      proxy_pass http://127.0.0.1:${V2PORT};
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host \$host;
      # Show real IP in v2ray access.log
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
        else
            # VLESS+TCP+TLS
            # VLESS+TCP+XTLS
            # trojan
            cat &gt; ${NGINX_CONF_PATH}${DOMAIN}.conf&lt;&lt;-EOF
server {
    listen 80;
    listen [::]:80;
    listen 81 http2;
    server_name ${DOMAIN};
    root /usr/share/nginx/html;
    location / {
        $action
    }
    $ROBOT_CONFIG
}
EOF
        fi
    fi
}

setSelinux() {
    if [[ -s /etc/selinux/config ]] &amp;&amp; grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi
}

setFirewall() {
    res=`which firewall-cmd 2&gt;/dev/null`
    if [[ $? -eq 0 ]]; then
        systemctl status firewalld &gt; /dev/null 2&gt;&amp;1
        if [[ $? -eq 0 ]];then
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            if [[ "$PORT" != "443" ]]; then
                firewall-cmd --permanent --add-port=${PORT}/tcp
                firewall-cmd --permanent --add-port=${PORT}/udp
            fi
            firewall-cmd --reload
        else
            nl=`iptables -nL | nl | grep FORWARD | awk '{print $1}'`
            if [[ "$nl" != "3" ]]; then
                iptables -I INPUT -p tcp --dport 80 -j ACCEPT
                iptables -I INPUT -p tcp --dport 443 -j ACCEPT
                if [[ "$PORT" != "443" ]]; then
                    iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT
                    iptables -I INPUT -p udp --dport ${PORT} -j ACCEPT
                fi
            fi
        fi
    else
        res=`which iptables 2&gt;/dev/null`
        if [[ $? -eq 0 ]]; then
            nl=`iptables -nL | nl | grep FORWARD | awk '{print $1}'`
            if [[ "$nl" != "3" ]]; then
                iptables -I INPUT -p tcp --dport 80 -j ACCEPT
                iptables -I INPUT -p tcp --dport 443 -j ACCEPT
                if [[ "$PORT" != "443" ]]; then
                    iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT
                    iptables -I INPUT -p udp --dport ${PORT} -j ACCEPT
                fi
            fi
        else
            res=`which ufw 2&gt;/dev/null`
            if [[ $? -eq 0 ]]; then
                res=`ufw status | grep -i inactive`
                if [[ "$res" = "" ]]; then
                    ufw allow http/tcp
                    ufw allow https/tcp
                    if [[ "$PORT" != "443" ]]; then
                        ufw allow ${PORT}/tcp
                        ufw allow ${PORT}/udp
                    fi
                fi
            fi
        fi
    fi
}

installBBR() {
    if [[ "$NEED_BBR" != "y" ]]; then
        INSTALL_BBR=false
        return
    fi
    result=$(lsmod | grep bbr)
    if [[ "$result" != "" ]]; then
        colorEcho $BLUE " BBR模块已安装"
        INSTALL_BBR=false
        return
    fi
    res=`hostnamectl | grep -i openvz`
    if [[ "$res" != "" ]]; then
        colorEcho $BLUE " openvz机器，跳过安装"
        INSTALL_BBR=false
        return
    fi
    
    echo "net.core.default_qdisc=fq" &gt;&gt; /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" &gt;&gt; /etc/sysctl.conf
    sysctl -p
    result=$(lsmod | grep bbr)
    if [[ "$result" != "" ]]; then
        colorEcho $GREEN " BBR模块已启用"
        INSTALL_BBR=false
        return
    fi

    colorEcho $BLUE " 安装BBR模块..."
    if [[ "$PMT" = "yum" ]]; then
        if [[ "$V6_PROXY" = "" ]]; then
            rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
            rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
            $CMD_INSTALL --enablerepo=elrepo-kernel kernel-ml
            $CMD_REMOVE kernel-3.*
            grub2-set-default 0
            echo "tcp_bbr" &gt;&gt; /etc/modules-load.d/modules.conf
            INSTALL_BBR=true
        fi
    else
        $CMD_INSTALL --install-recommends linux-generic-hwe-16.04
        grub-set-default 0
        echo "tcp_bbr" &gt;&gt; /etc/modules-load.d/modules.conf
        INSTALL_BBR=true
    fi
}

installV2ray() {
    rm -rf /tmp/v2ray
    mkdir -p /tmp/v2ray
    DOWNLOAD_LINK="${V6_PROXY}https://github.com/v2fly/v2ray-core/releases/download/${NEW_VER}/v2ray-linux-$(archAffix).zip"
    colorEcho $BLUE " 下载V2Ray: ${DOWNLOAD_LINK}"
    curl -L -H "Cache-Control: no-cache" -o /tmp/v2ray/v2ray.zip ${DOWNLOAD_LINK}
    if [ $? != 0 ];then
        colorEcho $RED " 下载V2ray文件失败，请检查服务器网络设置"
        exit 1
    fi
    mkdir -p '/etc/v2ray' '/var/log/v2ray' &amp;&amp; \
    unzip /tmp/v2ray/v2ray.zip -d /tmp/v2ray
    mkdir -p /usr/bin/v2ray
    cp /tmp/v2ray/v2ctl /usr/bin/v2ray/; cp /tmp/v2ray/v2ray /usr/bin/v2ray/; cp /tmp/v2ray/geo* /usr/bin/v2ray/;
    chmod +x '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl' || {
        colorEcho $RED " V2ray安装失败"
        exit 1
    }

    cat &gt;$SERVICE_FILE&lt;&lt;-EOF
[Unit]
Description=V2ray Service
Documentation=https://hijk.art
After=network.target nss-lookup.target

[Service]
# If the version of systemd is 240 or above, then uncommenting Type=exec and commenting out Type=simple
#Type=exec
Type=simple
# This service runs as root. You may consider to run it as another user for security concerns.
# By uncommenting User=nobody and commenting out User=root, the service will run as user nobody.
# More discussion at https://github.com/v2ray/v2ray-core/issues/1011
User=root
#User=nobody
NoNewPrivileges=true
ExecStart=/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable v2ray.service
}

trojanConfig() {
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "trojan",
    "settings": {
      "clients": [
        {
          "password": "$PASSWORD"
        }
      ],
      "fallbacks": [
        {
              "alpn": "http/1.1",
              "dest": 80
          },
          {
              "alpn": "h2",
              "dest": 81
          }
      ]
    },
    "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
            "serverName": "$DOMAIN",
            "alpn": ["http/1.1", "h2"],
            "certificates": [
                {
                    "certificateFile": "$CERT_FILE",
                    "keyFile": "$KEY_FILE"
                }
            ]
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

trojanXTLSConfig() {
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "trojan",
    "settings": {
      "clients": [
        {
          "password": "$PASSWORD",
          "flow": "$FLOW"
        }
      ],
      "fallbacks": [
          {
              "alpn": "http/1.1",
              "dest": 80
          },
          {
              "alpn": "h2",
              "dest": 81
          }
      ]
    },
    "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
            "serverName": "$DOMAIN",
            "alpn": ["http/1.1", "h2"],
            "certificates": [
                {
                    "certificateFile": "$CERT_FILE",
                    "keyFile": "$KEY_FILE"
                }
            ]
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

vmessConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    local alterid=`shuf -i50-80 -n1`
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "level": 1,
          "alterId": $alterid
        }
      ]
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

vmessKCPConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    local alterid=`shuf -i50-80 -n1`
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "level": 1,
          "alterId": $alterid
        }
      ]
    },
    "streamSettings": {
        "network": "mkcp",
        "kcpSettings": {
            "uplinkCapacity": 100,
            "downlinkCapacity": 100,
            "congestion": true,
            "header": {
                "type": "$HEADER_TYPE"
            },
            "seed": "$SEED"
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

vmessTLSConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "level": 1,
          "alterId": 0
        }
      ],
      "disableInsecureEncryption": false
    },
    "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
            "serverName": "$DOMAIN",
            "alpn": ["http/1.1", "h2"],
            "certificates": [
                {
                    "certificateFile": "$CERT_FILE",
                    "keyFile": "$KEY_FILE"
                }
            ]
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

vmessWSConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $V2PORT,
    "listen": "127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "level": 1,
          "alterId": 0
        }
      ],
      "disableInsecureEncryption": false
    },
    "streamSettings": {
        "network": "ws",
        "wsSettings": {
            "path": "$WSPATH",
            "headers": {
                "Host": "$DOMAIN"
            }
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

vlessTLSConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "level": 0
        }
      ],
      "decryption": "none",
      "fallbacks": [
          {
              "alpn": "http/1.1",
              "dest": 80
          },
          {
              "alpn": "h2",
              "dest": 81
          }
      ]
    },
    "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
            "serverName": "$DOMAIN",
            "alpn": ["http/1.1", "h2"],
            "certificates": [
                {
                    "certificateFile": "$CERT_FILE",
                    "keyFile": "$KEY_FILE"
                }
            ]
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

vlessXTLSConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "flow": "$FLOW",
          "level": 0
        }
      ],
      "decryption": "none",
      "fallbacks": [
          {
              "alpn": "http/1.1",
              "dest": 80
          },
          {
              "alpn": "h2",
              "dest": 81
          }
      ]
    },
    "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
            "serverName": "$DOMAIN",
            "alpn": ["http/1.1", "h2"],
            "certificates": [
                {
                    "certificateFile": "$CERT_FILE",
                    "keyFile": "$KEY_FILE"
                }
            ]
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

vlessWSConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $V2PORT,
    "listen": "127.0.0.1",
    "protocol": "vless",
    "settings": {
        "clients": [
            {
                "id": "$uuid",
                "level": 0
            }
        ],
        "decryption": "none"
    },
    "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
            "path": "$WSPATH",
            "headers": {
                "Host": "$DOMAIN"
            }
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

vlessKCPConfig() {
    local uuid="$(cat '/proc/sys/kernel/random/uuid')"
    cat &gt; $CONFIG_FILE&lt;&lt;-EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "level": 0
        }
      ],
      "decryption": "none"
    },
    "streamSettings": {
        "streamSettings": {
            "network": "mkcp",
            "kcpSettings": {
                "uplinkCapacity": 100,
                "downlinkCapacity": 100,
                "congestion": true,
                "header": {
                    "type": "$HEADER_TYPE"
                },
                "seed": "$SEED"
            }
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF
}

configV2ray() {
    mkdir -p /etc/v2ray
    if [[ "$TROJAN" = "true" ]]; then
        if [[ "$XTLS" = "true" ]]; then
            trojanXTLSConfig
        else
            trojanConfig
        fi
        return 0
    fi
    if [[ "$VLESS" = "false" ]]; then
        # VMESS + kcp
        if [[ "$KCP" = "true" ]]; then
            vmessKCPConfig
            return 0
        fi
        # VMESS
        if [[ "$TLS" = "false" ]]; then
            vmessConfig
        elif [[ "$WS" = "false" ]]; then
            # VMESS+TCP+TLS
            vmessTLSConfig
        # VMESS+WS+TLS
        else
            vmessWSConfig
        fi
    #VLESS
    else
        if [[ "$KCP" = "true" ]]; then
            vlessKCPConfig
            return 0
        fi
        # VLESS+TCP
        if [[ "$WS" = "false" ]]; then
            # VLESS+TCP+TLS
            if [[ "$XTLS" = "false" ]]; then
                vlessTLSConfig
            # VLESS+TCP+XTLS
            else
                vlessXTLSConfig
            fi
        # VLESS+WS+TLS
        else
            vlessWSConfig
        fi
    fi
}

install() {
    getData

    $PMT clean all
    [[ "$PMT" = "apt" ]] &amp;&amp; $PMT update
    #echo $CMD_UPGRADE | bash
    $CMD_INSTALL wget vim unzip tar gcc openssl
    $CMD_INSTALL net-tools
    if [[ "$PMT" = "apt" ]]; then
        $CMD_INSTALL libssl-dev g++
    fi
    res=`which unzip 2&gt;/dev/null`
    if [[ $? -ne 0 ]]; then
        colorEcho $RED " unzip安装失败，请检查网络"
        exit 1
    fi

    installNginx
    setFirewall
    if [[ "$TLS" = "true" || "$XTLS" = "true" ]]; then
        getCert
    fi
    configNginx

    colorEcho $BLUE " 安装V2ray..."
    getVersion
    RETVAL="$?"
    if [[ $RETVAL == 0 ]]; then
        colorEcho $BLUE " V2ray最新版 ${CUR_VER} 已经安装"
    elif [[ $RETVAL == 3 ]]; then
        exit 1
    else
        colorEcho $BLUE " 安装V2Ray ${NEW_VER} ，架构$(archAffix)"
        installV2ray
    fi

    configV2ray

    setSelinux
    installBBR

    start
    showInfo

    bbrReboot
}

bbrReboot() {
    if [[ "${INSTALL_BBR}" == "true" ]]; then
        echo  
        echo " 为使BBR模块生效，系统将在30秒后重启"
        echo  
        echo -e " 您可以按 ctrl + c 取消重启，稍后输入 ${RED}reboot${PLAIN} 重启系统"
        sleep 30
        reboot
    fi
}

update() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " V2ray未安装，请先安装！"
        return
    fi

    getVersion
    RETVAL="$?"
    if [[ $RETVAL == 0 ]]; then
        colorEcho $BLUE " V2ray最新版 ${CUR_VER} 已经安装"
    elif [[ $RETVAL == 3 ]]; then
        exit 1
    else
        colorEcho $BLUE " 安装V2Ray ${NEW_VER} ，架构$(archAffix)"
        installV2ray
        stop
        start

        colorEcho $GREEN " 最新版V2ray安装成功！"
    fi
}

uninstall() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " V2ray未安装，请先安装！"
        return
    fi

    echo ""
    read -p " 确定卸载V2ray？[y/n]：" answer
    if [[ "${answer,,}" = "y" ]]; then
        domain=`grep Host $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
        if [[ "$domain" = "" ]]; then
            domain=`grep serverName $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
        fi
        
        stop
        systemctl disable v2ray
        rm -rf $SERVICE_FILE
        rm -rf /etc/v2ray
        rm -rf /usr/bin/v2ray

        if [[ "$BT" = "false" ]]; then
            systemctl disable nginx
            $CMD_REMOVE nginx
            if [[ "$PMT" = "apt" ]]; then
                $CMD_REMOVE nginx-common
            fi
            rm -rf /etc/nginx/nginx.conf
            if [[ -f /etc/nginx/nginx.conf.bak ]]; then
                mv /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
            fi
        fi
        if [[ "$domain" != "" ]]; then
            rm -rf $NGINX_CONF_PATH${domain}.conf
        fi
        [[ -f ~/.acme.sh/acme.sh ]] &amp;&amp; ~/.acme.sh/acme.sh --uninstall
        colorEcho $GREEN " V2ray卸载成功"
    fi
}

start() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " V2ray未安装，请先安装！"
        return
    fi
    stopNginx
    startNginx
    systemctl restart v2ray
    sleep 2
    port=`grep port $CONFIG_FILE| head -n 1| cut -d: -f2| tr -d \",' '`
    res=`ss -nutlp| grep ${port} | grep -i v2ray`
    if [[ "$res" = "" ]]; then
        colorEcho $RED " v2ray启动失败，请检查日志或查看端口是否被占用！"
    else
        colorEcho $BLUE " v2ray启动成功"
    fi
}

stop() {
    stopNginx
    systemctl stop v2ray
    colorEcho $BLUE " V2ray停止成功"
}


restart() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " V2ray未安装，请先安装！"
        return
    fi

    stop
    start
}

getConfigFileInfo() {
    vless="false"
    tls="false"
    ws="false"
    xtls="false"
    trojan="false"
    protocol="VMess"
    kcp="false"

    uid=`grep id $CONFIG_FILE | head -n1| cut -d: -f2 | tr -d \",' '`
    alterid=`grep alterId $CONFIG_FILE  | cut -d: -f2 | tr -d \",' '`
    network=`grep network $CONFIG_FILE  | tail -n1| cut -d: -f2 | tr -d \",' '`
    [[ -z "$network" ]] &amp;&amp; network="tcp"
    domain=`grep serverName $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
    if [[ "$domain" = "" ]]; then
        domain=`grep Host $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
        if [[ "$domain" != "" ]]; then
            ws="true"
            tls="true"
            wspath=`grep path $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
        fi
    else
        tls="true"
    fi
    if [[ "$ws" = "true" ]]; then
        port=`grep -i ssl $NGINX_CONF_PATH${domain}.conf| head -n1 | awk '{print $2}'`
    else
        port=`grep port $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
    fi
    res=`grep -i kcp $CONFIG_FILE`
    if [[ "$res" != "" ]]; then
        kcp="true"
        type=`grep header -A 3 $CONFIG_FILE | grep 'type' | cut -d: -f2 | tr -d \",' '`
        seed=`grep seed $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
    fi

    vmess=`grep vmess $CONFIG_FILE`
    if [[ "$vmess" = "" ]]; then
        trojan=`grep trojan $CONFIG_FILE`
        if [[ "$trojan" = "" ]]; then
            vless="true"
            protocol="VLESS"
        else
            trojan="true"
            password=`grep password $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
            protocol="trojan"
        fi
        tls="true"
        encryption="none"
        xtls=`grep xtlsSettings $CONFIG_FILE`
        if [[ "$xtls" != "" ]]; then
            xtls="true"
            flow=`grep flow $CONFIG_FILE | cut -d: -f2 | tr -d \",' '`
        else
            flow="无"
        fi
    fi
}

outputVmess() {
    raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"$IP\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"tcp\",
  \"type\":\"none\",
  \"host\":\"\",
  \"path\":\"\",
  \"tls\":\"\"
}"
    link=`echo -n ${raw} | base64 -w 0`
    link="vmess://${link}"

    echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
    echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
    echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
    echo -e "   ${BLUE}额外id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
    echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}auto${PLAIN}"
    echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}" 
    echo  
    echo -e "   ${BLUE}vmess链接:${PLAIN} $RED$link$PLAIN"
}

outputVmessKCP() {
    echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
    echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
    echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
    echo -e "   ${BLUE}额外id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
    echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}auto${PLAIN}"
    echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
    echo -e "   ${BLUE}伪装类型(type)：${PLAIN} ${RED}${type}${PLAIN}"
    echo -e "   ${BLUE}mkcp seed：${PLAIN} ${RED}${seed}${PLAIN}" 
}

outputTrojan() {
    if [[ "$xtls" = "true" ]]; then
        echo -e "   ${BLUE}IP/域名(address): ${PLAIN} ${RED}${domain}${PLAIN}"
        echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
        echo -e "   ${BLUE}密码(password)：${PLAIN}${RED}${password}${PLAIN}"
        echo -e "   ${BLUE}流控(flow)：${PLAIN}$RED$flow${PLAIN}"
        echo -e "   ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
        echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}" 
        echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}XTLS${PLAIN}"
    else
        echo -e "   ${BLUE}IP/域名(address): ${PLAIN} ${RED}${domain}${PLAIN}"
        echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
        echo -e "   ${BLUE}密码(password)：${PLAIN}${RED}${password}${PLAIN}"
        echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}" 
        echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
    fi
}

outputVmessTLS() {
    raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"$IP\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"${network}\",
  \"type\":\"none\",
  \"host\":\"${domain}\",
  \"path\":\"\",
  \"tls\":\"tls\"
}"
    link=`echo -n ${raw} | base64 -w 0`
    link="vmess://${link}"
    echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
    echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
    echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
    echo -e "   ${BLUE}额外id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
    echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}none${PLAIN}"
    echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}" 
    echo -e "   ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${domain}${PLAIN}"
    echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
    echo  
    echo -e "   ${BLUE}vmess链接: ${PLAIN}$RED$link$PLAIN"
}

outputVmessWS() {
    raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"$IP\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"${network}\",
  \"type\":\"none\",
  \"host\":\"${domain}\",
  \"path\":\"${wspath}\",
  \"tls\":\"tls\"
}"
    link=`echo -n ${raw} | base64 -w 0`
    link="vmess://${link}"

    echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
    echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
    echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
    echo -e "   ${BLUE}额外id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
    echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}none${PLAIN}"
    echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}" 
    echo -e "   ${BLUE}伪装类型(type)：${PLAIN}${RED}none$PLAIN"
    echo -e "   ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${domain}${PLAIN}"
    echo -e "   ${BLUE}路径(path)：${PLAIN}${RED}${wspath}${PLAIN}"
    echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
    echo  
    echo -e "   ${BLUE}vmess链接:${PLAIN} $RED$link$PLAIN"
}

showInfo() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " V2ray未安装，请先安装！"
        return
    fi

    echo ""
    echo -n -e " ${BLUE}V2ray运行状态：${PLAIN}"
    statusText
    echo -e " ${BLUE}V2ray配置文件: ${PLAIN} ${RED}${CONFIG_FILE}${PLAIN}"
    colorEcho $BLUE " V2ray配置信息："

    getConfigFileInfo

    echo -e "   ${BLUE}协议: ${PLAIN} ${RED}${protocol}${PLAIN}"
    if [[ "$trojan" = "true" ]]; then
        outputTrojan
        return 0
    fi
    if [[ "$vless" = "false" ]]; then
        if [[ "$kcp" = "true" ]]; then
            outputVmessKCP
            return 0
        fi
        if [[ "$tls" = "false" ]]; then
            outputVmess
        elif [[ "$ws" = "false" ]]; then
            outputVmessTLS
        else
            outputVmessWS
        fi
    else
        if [[ "$kcp" = "true" ]]; then
            echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
            echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
            echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
            echo -e "   ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
            echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
            echo -e "   ${BLUE}伪装类型(type)：${PLAIN} ${RED}${type}${PLAIN}"
            echo -e "   ${BLUE}mkcp seed：${PLAIN} ${RED}${seed}${PLAIN}" 
            return 0
        fi
        if [[ "$xtls" = "true" ]]; then
            echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
            echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
            echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
            echo -e "   ${BLUE}流控(flow)：${PLAIN}$RED$flow${PLAIN}"
            echo -e "   ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
            echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}" 
            echo -e "   ${BLUE}伪装类型(type)：${PLAIN}${RED}none$PLAIN"
            echo -e "   ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${domain}${PLAIN}"
            echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}XTLS${PLAIN}"
        elif [[ "$ws" = "false" ]]; then
            echo -e "   ${BLUE}IP(address):  ${PLAIN}${RED}${IP}${PLAIN}"
            echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
            echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
            echo -e "   ${BLUE}流控(flow)：${PLAIN}$RED$flow${PLAIN}"
            echo -e "   ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
            echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}" 
            echo -e "   ${BLUE}伪装类型(type)：${PLAIN}${RED}none$PLAIN"
            echo -e "   ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${domain}${PLAIN}"
            echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
        else
            echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
            echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
            echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
            echo -e "   ${BLUE}流控(flow)：${PLAIN}$RED$flow${PLAIN}"
            echo -e "   ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
            echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}" 
            echo -e "   ${BLUE}伪装类型(type)：${PLAIN}${RED}none$PLAIN"
            echo -e "   ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${domain}${PLAIN}"
            echo -e "   ${BLUE}路径(path)：${PLAIN}${RED}${wspath}${PLAIN}"
            echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
        fi
    fi
}

showLog() {
    res=`status`
    if [[ $res -lt 2 ]]; then
        colorEcho $RED " V2ray未安装，请先安装！"
        return
    fi

    journalctl -xen -u v2ray --no-pager
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                   ${RED}v2ray一键安装脚本${PLAIN}                      #"
    echo -e "# ${GREEN}作者${PLAIN}: 网络跳越(hijk)                                      #"
    echo -e "# ${GREEN}网址${PLAIN}: https://hijk.art                                    #"
    echo -e "# ${GREEN}论坛${PLAIN}: https://hijk.club                                   #"
    echo -e "# ${GREEN}TG群${PLAIN}: https://t.me/hijkclub                               #"
    echo -e "# ${GREEN}Youtube频道${PLAIN}: https://youtube.com/channel/UCYTB--VsObzepVJtc9yvUxQ #"
    echo "#############################################################"

    echo -e "  ${GREEN}1.${PLAIN}   安装V2ray-VMESS"
    echo -e "  ${GREEN}2.${PLAIN}   安装V2ray-${BLUE}VMESS+mKCP${PLAIN}"
    echo -e "  ${GREEN}3.${PLAIN}   安装V2ray-VMESS+TCP+TLS"
    echo -e "  ${GREEN}4.${PLAIN}   安装V2ray-${BLUE}VMESS+WS+TLS${PLAIN}${RED}(推荐)${PLAIN}"
    echo -e "  ${GREEN}5.${PLAIN}   安装V2ray-${BLUE}VLESS+mKCP${PLAIN}"
    echo -e "  ${GREEN}6.${PLAIN}   安装V2ray-VLESS+TCP+TLS"
    echo -e "  ${GREEN}7.${PLAIN}   安装V2ray-${BLUE}VLESS+WS+TLS${PLAIN}${RED}(可过cdn)${PLAIN}"
    echo -e "  ${GREEN}8.${PLAIN}   安装V2ray-${BLUE}VLESS+TCP+XTLS${PLAIN}${RED}(推荐)${PLAIN}"
    echo -e "  ${GREEN}9.${PLAIN}   安装${BLUE}trojan${PLAIN}${RED}(推荐)${PLAIN}"
    echo -e "  ${GREEN}10.${PLAIN}  安装${BLUE}trojan+XTLS${PLAIN}${RED}(推荐)${PLAIN}"
    echo " -------------"
    echo -e "  ${GREEN}11.${PLAIN}  更新V2ray"
    echo -e "  ${GREEN}12.  ${RED}卸载V2ray${PLAIN}"
    echo " -------------"
    echo -e "  ${GREEN}13.${PLAIN}  启动V2ray"
    echo -e "  ${GREEN}14.${PLAIN}  重启V2ray"
    echo -e "  ${GREEN}15.${PLAIN}  停止V2ray"
    echo " -------------"
    echo -e "  ${GREEN}16.${PLAIN}  查看V2ray配置"
    echo -e "  ${GREEN}17.${PLAIN}  查看V2ray日志"
    echo " -------------"
    echo -e "  ${GREEN}0.${PLAIN}   退出"
    echo -n " 当前状态："
    statusText
    echo 

    read -p " 请选择操作[0-17]：" answer
    case $answer in
        0)
            exit 0
            ;;
        1)
            install
            ;;
        2)
            KCP="true"
            install
            ;;
        3)
            TLS="true"
            install
            ;;
        4)
            TLS="true"
            WS="true"
            install
            ;;
        5)
            VLESS="true"
            KCP="true"
            install
            ;;
        6)
            VLESS="true"
            TLS="true"
            install
            ;;
        7)
            VLESS="true"
            TLS="true"
            WS="true"
            install
            ;;
        8)
            VLESS="true"
            TLS="true"
            XTLS="true"
            install
            ;;
        9)
            TROJAN="true"
            TLS="true"
            install
            ;;
        10)
            TROJAN="true"
            TLS="true"
            XTLS="true"
            install
            ;;
        11)
            update
            ;;
        12)
            uninstall
            ;;
        13)
            start
            ;;
        14)
            restart
            ;;
        15)
            stop
            ;;
        16)
            showInfo
            ;;
        17)
            showLog
            ;;
        *)
            colorEcho $RED " 请选择正确的操作！"
            exit 1
            ;;
    esac
}

checkSystem

action=$1
[[ -z $1 ]] &amp;&amp; action=menu
case "$action" in
    menu|update|uninstall|start|restart|stop|showInfo|showLog)
        ${action}
        ;;
    *)
        echo " 参数错误"
        echo " 用法: `basename $0` [menu|update|uninstall|start|restart|stop|showInfo|showLog]"
        ;;
esac
</pre></body></html>Ztext/plainUUTF-8_Hhttps://raw.githubusercontent.com/oneforallofall/oneforall/main/v2ray.shP    ( : P n } ��������H             
              �I