#!/bin/bash

# 备份文件
备份文件() {
    cp $1 $1.bak
}

# 从备份恢复文件
恢复文件() {
    mv $1.bak $1
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
read -p "请输入新的SSH端口号: " new_port
read -p "请输入新的公钥: " public_key

# 备份SSH配置
备份文件 /etc/ssh/sshd_config

# 更新SSH配置
sed -i "s/Port [0-9]*/Port $new_port/" /etc/ssh/sshd_config
sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
echo "$public_key" >> ~/.ssh/authorized_keys

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

# 如果未提供公钥，则生成SSH密钥对
if [ -z "$public_key" ]; then
    生成SSH密钥
fi
