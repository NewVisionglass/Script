#!/bin/bash

# 备份文件
备份文件() {
    cp $1 $1.bak
}

# 从备份恢复文件
恢复文件() {
    mv $1.bak $1
}

# 检查端口是否在合法范围内
检查端口() {
    local port=$1
    if ! [[ $port =~ ^[0-9]+$ ]]; then
        echo "端口号必须为数字。"
        exit 1
    fi

    if ((port < 1 || port > 65535)); then
        echo "端口号必须在1到65535之间。"
        exit 1
    fi
}

# 检查公钥格式
检查公钥格式() {
    local public_key=$1
    if ! echo "$public_key" | grep -q "ssh-rsa"; then
        echo "公钥格式不正确。"
        exit 1
    fi
}

# 生成SSH密钥对
生成SSH密钥() {
    read -p "是否要生成新的SSH密钥对？ (y/n): " choice
    if [ "$choice" == "y" ]; then
        read -p "请选择要使用的加密协议 (默认为 rsa): " key_type
        key_type=${key_type:-rsa}
        ssh-keygen -t $key_type -b 4096 -C "your_email@example.com"
        mv ~/.ssh/id_rsa /root/id_rsa
        chmod 600 /root/id_rsa
        cat /root/id_rsa
    fi
}

# 主要脚本

# 外部参数处理
while getopts ":p:k:" opt; do
    case ${opt} in
        p )
            new_port=$OPTARG
            检查端口 $new_port
            ;;
        k )
            public_key=$OPTARG
            检查公钥格式 "$public_key"
            ;;
        \? )
            echo "无效的参数: -$OPTARG" 1>&2
            exit 1
            ;;
    esac
done

# 检查参数是否提供
if [ -z "$new_port" ] || [ -z "$public_key" ]; then
    echo "请提供新的SSH端口号 (-p) 和公钥 (-k) 参数。"
    exit 1
fi

# 备份SSH配置
备份文件 /etc/ssh/sshd_config

# 更新SSH配置
sed -i "s/Port [0-9]*/Port $new_port/" /etc/ssh/sshd_config
sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config

# 检查是否存在公钥
if [ -f ~/.ssh/authorized_keys ]; then
    read -p "已存在公钥，是否要替换？(输入 '替换' 替换现有公钥): " replace_choice
    if [ "$replace_choice" == "替换" ]; then
        echo "$public_key" > ~/.ssh/authorized_keys
    else
        echo "$public_key" >> ~/.ssh/authorized_keys
    fi
else
    echo "$public_key" > ~/.ssh/authorized_keys
fi

# 重新加载SSH配置
systemctl reload sshd

# 更新防火墙设置
firewall-cmd --zone=public --add-port=$new_port/tcp --permanent
firewall-cmd --reload

# 检查是否一切正常
echo "正在测试新的SSH配置..."
sleep 3
ssh -p $new_port localhost

if [ $? -eq 0 ]; then
    echo "SSH配置已成功更新。"
else
    echo "更新SSH配置失败。正在恢复备份..."
    恢复文件 /etc/ssh/sshd_config
    systemctl reload sshd
    firewall-cmd --zone=public --remove-port=$new_port/tcp --permanent
    firewall-cmd --reload
fi

# 如果公钥错误，则生成SSH密钥对
if [ $? -ne 0 ]; then
    生成SSH密钥
fi
