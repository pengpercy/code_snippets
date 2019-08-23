#!/usr/bin/env bash
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

if [ ! "$(command -v bash-completion)" ]; then
  cat >>~/.bashrc <<-EOF
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF
fi

echo "安装依赖..."
sudo apt update -qq && sudo apt install -qq -y xsel xclip shadowsocks-libev rng-tools supervisor vim htop chromium-chromedriver git jq bash-completion ssh >/dev/null
source ~/.bashrc

echo "设置配置信息"
init_config=$(cat /tmp/init.config | base64 -di --decode)
instance_name=$(echo $init_config | jq -r '.instance_name')
frp_version=$(echo $init_config | jq -r '.frp_version')
frp_token=$(echo $init_config | jq -r '.frp_token')
frp_server_domain=$(echo $init_config | jq -r '.frp_server_domain')
frp_server_addr=$(echo $init_config | jq -r '.frp_server_addr')
frp_server_port=$(echo $init_config | jq -r '.frp_server_port')
ssh_port=$(echo $init_config | jq -r '.ssh_port')
ssh_password=$(echo $init_config | jq -r '.ssh_password')
shadowsocksport=$(echo $init_config | jq -r '.shadowsocksport')
shadowsockspwd=$(echo $init_config | jq -r '.shadowsockspwd')
shadowsockscipher=$(echo $init_config | jq -r '.shadowsockscipher')
shadowsocksservice=$(echo $init_config | jq -r '.shadowsocksservice')

echo "安装frpc"
wget -q https://github.com/fatedier/frp/releases/download/v${frp_version}/frp_${frp_version}_linux_amd64.tar.gz
tar -xzf frp_${frp_version}_linux_amd64.tar.gz
\cp -rf frp_${frp_version}_linux_amd64/frpc /usr/bin/frpc

if [ ! -d /etc/frp ]; then
  mkdir -p /etc/frp
fi

cat >/etc/frp/frpc.ini <<-EOF
[common]
server_addr = ${frp_server_addr}
server_port = ${frp_server_port}
token = ${frp_token}

[colab.${instance_name}.ssh]
type = tcp
local_ip = localhost
local_port = 22
remote_port = ${ssh_port}
custom_domains = ${frp_server_domain}

[colab.${instance_name}.ss]
type = tcp
local_ip = localhost
local_port = ${shadowsocksport}
remote_port = ${shadowsocksport}
use_encryption = true
use_compression = true
custom_domains = ${frp_server_domain}

[colab.${instance_name}.ss.udp]
type = udp
local_ip = localhost
local_port = ${shadowsocksport}
remote_port = ${shadowsocksport}
use_encryption = true
use_compression = true
custom_domains = ${frp_server_domain}
EOF
rm -rf frp_${frp_version}_linux_amd64* /tmp/init.

if [ ! -d /opt/colab_daemon ]; then
  echo "安装selenium"
  if [ ! -f /usr/lib/chromium-browser/chromedriver ]; then
    \cp -rf /usr/lib/chromium-browser/chromedriver /usr/bin
  fi
  pip3 install -q selenium pyperclip apscheduler lxml >/dev/null
  echo "安装colab_daemon"
  mkdir -p /opt/colab_daemon
  wget -qO /opt/colab_daemon/app.py  https://raw.githubusercontent.com/pengpercy/code_snippets/master/shell_scripts/colab_daemon.py
fi

echo "配置supervisor"
cat >/etc/supervisor/conf.d/frpc.conf <<-EOF
[program:frpc]
command = frpc -c /etc/frp/frpc.ini
directory = /etc/frp/
autostart = true
autorestart = true
stdout_logfile = /var/log/frp.log
stderr_logfile = /var/log/frp.err.log
numprocs = 1
startretries = 100
stopsignal = KILL
stopwaitsecs = 10
EOF

cat >/etc/supervisor/conf.d/colab_daemon.conf <<-EOF
[program:colab_daemon]
command = python3 /opt/colab_daemon/app.py
directory = /opt/colab_daemon
autostart = true
autorestart = true
stdout_logfile = /var/log/colab_daemon.log
stderr_logfile = /var/log/colab_daemon.err.log
numprocs = 1
startretries = 100
stopsignal = KILL
stopwaitsecs = 10
EOF

sudo service supervisor start

echo "安装ssh"
sed -re 's/^(\#)(Port)([[:space:]]+)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
sed -re 's/^(\#)(ListenAddress)([[:space:]]+)(0\.0\.0\.0)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
sed -re 's/^(\#)(PermitRootLogin)([[:space:]]+)(prohibit-password)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
sed -re 's/^(PermitRootLogin)([[:space:]]+)prohibit-password/\1\2yes/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config && (echo "${ssh_password}" && echo "${ssh_password}") | sudo passwd root
service ssh restart

echo "安装shadowsocks"
cat >/etc/shadowsocks-libev/config.json <<-EOF
{
    "server":"0.0.0.0",
    "server_port":${shadowsocksport},
    "password":"${shadowsockspwd}",
    "timeout":300,
    "user":"nobody",
    "method":"${shadowsockscipher}",
    "fast_open":false,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp"
}
EOF
wget -qO /etc/init.d/shadowsocks-libev "$shadowsocksservice"
chmod +x /etc/init.d/shadowsocks-libev
service shadowsocks-libev start
touch /var/log/frp.log