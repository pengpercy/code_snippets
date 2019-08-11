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

echo "安装依赖"
sudo apt update && sudo apt install -q -y shadowsocks-libev rng-tools supervisor vim htop chromium-chromedriver git jq bash-completion
source ~/.bashrc

echo "获取配置信息"
init_config=$(cat /tmp/init.config | base64 -di --decode)
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

echo "安装frpc,并添加守护进程"
wget -q https://github.com/fatedier/frp/releases/download/v${frp_version}/frp_${frp_version}_linux_amd64.tar.gz
tar -xzf frp_${frp_version}_linux_amd64.tar.gz
\cp -rf frp_${frp_version}_linux_amd64/frpc /usr/bin/frpc

if [ ! -d /etc/frp ]; then
  mkdir -p /etc/frp
fi

if [ ! -d /var/log/frp ]; then
  mkdir -p /var/log/frp
fi

echo "写入frp配置文件"
# \cp -rf /tmp/frpc.conf /etc/supervisor/conf.d/
cat >/etc/supervisor/conf.d/frpc.conf <<-EOF
[program:frpc]
command = frpc -c /etc/frp/frpc.ini
directory = /etc/frp/
autostart = true
autorestart = true
stdout_logfile = /var/log/frp/frp.log
stderr_logfile = /var/log/frp/frp.err.log
numprocs = 1
startretries = 100
stopsignal = KILL
stopwaitsecs = 10
EOF

#\cp -rf /tmp/frpc.ini /etc/frp/
cat >/etc/frp/frpc.ini <<-EOF
[common]
server_addr = ${frp_server_addr}
server_port = ${frp_server_port}
token = ${frp_token}

[colab.ssh]
type = tcp
local_ip = localhost
local_port = 22
remote_port = ${ssh_port}
custom_domains = ${frp_server_domain}

[colab.ss]
type = tcp
local_ip = localhost
local_port = ${shadowsocksport}
remote_port = ${shadowsocksport}
use_encryption = true
use_compression = true
custom_domains = ${frp_server_domain}

[colab.ss.udp]
type = udp
local_ip = localhost
local_port = ${shadowsocksport}
remote_port = ${shadowsocksport}
use_encryption = true
use_compression = true
custom_domains = ${frp_server_domain}
EOF

\cp -rf /usr/lib/chromium-browser/chromedriver /usr/bin
pip3 install selenium
rm -rf frp_${frp_version}_linux_amd64* /tmp/init.config
sudo service supervisor start

echo "设置ssh配置文件，开启远程访问权限"
sed -re 's/^(\#)(Port)([[:space:]]+)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
sed -re 's/^(\#)(ListenAddress)([[:space:]]+)(0\.0\.0\.0)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
sed -re 's/^(\#)(PermitRootLogin)([[:space:]]+)(prohibit-password)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
sed -re 's/^(PermitRootLogin)([[:space:]]+)prohibit-password/\1\2yes/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config && (echo "${ssh_password}" && echo "${ssh_password}") | sudo passwd root
sudo service ssh restart

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

echo "启动ss服务"
wget -qO /etc/init.d/shadowsocks-libev "$shadowsocksservice"
chmod +x /etc/init.d/shadowsocks-libev
service shadowsocks-libev start

tail -f /var/log/frp/frp.log
