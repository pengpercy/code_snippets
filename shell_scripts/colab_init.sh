#!/usr/bin/env bash

if [ ! "$(command -v bash-completion)" ]; then
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  \cp -rf /tools/node/bin/node /usr/bin
  cat >>~/.bashrc <<-EOF
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF
  source ~/.bashrc
  echo "apt安装依赖..."
  sudo apt update -qq >/dev/null
  sudo apt install -qq -y rng-tools net-tools unzip openssh-server supervisor vim htop chromium-chromedriver lrzsz git jq bash-completion ssh >/dev/null

  echo "pip安装依赖"
  pip3 install -q selenium pyperclip apscheduler lxml pyecharts >/dev/null

  echo "设置配置信息"
  init_config=$(cat /tmp/init.config | base64 -di --decode)
  instance_name=$(echo $init_config | jq -r '.instance_name')
  frp_version=$(echo $init_config | jq -r '.frp_version')
  frp_token=$(echo $init_config | jq -r '.frp_token')
  frp_server_domain=$(echo $init_config | jq -r '.frp_server_domain')
  frp_server_addr=$(echo $init_config | jq -r '.frp_server_addr')
  frp_server_port=$(echo $init_config | jq -r '.frp_server_port')
  frp_admin_port=$(echo $init_config | jq -r '.frp_admin_port')
  ssh_port=$(echo $init_config | jq -r '.ssh_port')
  ssh_password=$(echo $init_config | jq -r '.ssh_password')
  snell_port=$(echo $init_config | jq -r '.snell_port')
  snell_psk=$(echo $init_config | jq -r '.snell_psk')
  snell_version=$(echo $init_config | jq -r '.snell_version')
fi

# if [ ! -d /etc/frp ]; then
#   echo "安装frpc"
#   wget -q https://github.com/fatedier/frp/releases/download/v${frp_version}/frp_${frp_version}_linux_amd64.tar.gz
#   tar -xzf frp_${frp_version}_linux_amd64.tar.gz
#   \cp -rf frp_${frp_version}_linux_amd64/frpc /usr/bin/frpc
#   rm -rf frp_${frp_version}_linux_amd64* /tmp/init.
#   mkdir -p /etc/frp
#   cat >/etc/frp/frpc.ini <<-EOF
# [common]
# server_addr = ${frp_server_addr}
# server_port = ${frp_server_port}
# admin_port = ${frp_admin_port}
# token = ${frp_token}
# [colab.${instance_name}.ssh]
# type = tcp
# local_ip = localhost
# local_port = 22
# remote_port = ${ssh_port}
# custom_domains = ${frp_server_domain}
# [colab.${instance_name}.snell]
# type = tcp
# local_ip = localhost
# local_port = ${snell_port}
# remote_port = ${snell_port}
# use_encryption = true
# use_compression = true
# custom_domains = ${frp_server_domain}
# [colab.${instance_name}.ss.udp]
# type = udp
# local_ip = localhost
# local_port = ${snell_port}
# remote_port = ${snell_port}
# use_encryption = true
# use_compression = true
# custom_domains = ${frp_server_domain}
# EOF
# fi

# pip3 install pyecharts jupyterlab  >/dev/null && pip3 uninstall jupyterlab -y  >/dev/null && pip3 install jupyterlab  >/dev/null && jupyter lab clean  >/dev/null && jupyter lab build  >/dev/null
if [ ! -d /opt/colab_daemon ]; then
  echo "安装colab_daemon"
  mkdir -p /opt/colab_daemon/log
  wget -qO /opt/colab_daemon/app.py https://raw.githubusercontent.com/pengpercy/code_snippets/master/shell_scripts/colab_daemon.py
fi

if [ ! -f /usr/bin/cloudflared ]; then
  echo "安装cloudflared"
  wget -qO /usr/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x /usr/bin/cloudflared
fi



# if [ ! -f /etc/supervisor/conf.d/frpc.conf ]; then
#   echo "配置frpc"
#   cat >/etc/supervisor/conf.d/frpc.conf <<-EOF
# [program:frpc]
# command = frpc -c /etc/frp/frpc.ini
# directory = /etc/frp/
# autostart = true
# autorestart = true
# stdout_logfile = /var/log/frp.log
# stderr_logfile = /var/log/frp.err.log
# numprocs = 1
# startretries = 100
# stopsignal = KILL
# stopwaitsecs = 10
# killasgroup=true
# stopasgroup=true
# EOF
# fi

if [ ! -f /etc/supervisor/conf.d/colab_daemon.conf ]; then
  echo "配置colab_daemon"
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
killasgroup=true
stopasgroup=true
EOF
fi


if [ ! -d /root/.ssh ]; then
  mkdir ~/.ssh
fi

if [ ! -f /var/log/frp.log ]; then
  sudo service supervisor start
  echo "安装ssh"
  sed -re 's/^(\#)(Port)([[:space:]]+)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
  sed -re 's/^(\#)(ListenAddress)([[:space:]]+)(0\.0\.0\.0)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
  sed -re 's/^(\#)(PermitRootLogin)([[:space:]]+)(prohibit-password)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
  # sed -re 's/^(PermitRootLogin)([[:space:]]+)prohibit-password/\1\2yes/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config && (echo "${ssh_password}" && echo "${ssh_password}") | sudo passwd root
  sed -re 's/^(PermitRootLogin)([[:space:]]+)prohibit-password/\1\2yes/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
  sed -re 's/^(\#)(PubkeyAuthentication)([[:space:]]+)(yes)(.*)/\2\3\4/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
  sed -re 's/^(\#)(AuthorizedKeysFile)([[:space:]]+)(\.ssh\/authorized_keys)([[:space:]]+)(\.ssh\/authorized_keys2)(.*)/\2\3\4\5\6/' /etc/ssh/sshd_config >~/temp.cnf && mv -f ~/temp.cnf /etc/ssh/sshd_config
  mv -f /tmp/authorized_keys ~/.ssh/authorized_keys
  sudo service ssh restart
fi

touch /var/log/frp.log
