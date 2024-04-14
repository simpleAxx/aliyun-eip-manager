#!/bin/bash

if ! command -v systemctl &> /dev/null; then
    echo "当前系统不支持Systemd，程序退出。"
    exit 1
fi

os_name=$(uname -s)

install_packages() {
    local package="$1"
    if [ "$os_name" = "Linux" ]; then
        if which yum &> /dev/null; then
            yum install -y "$package"
        elif which apt-get &> /dev/null; then
            apt-get update && apt-get install -y "$package"
        else
            echo "不支持的操作系统，程序退出。"
            exit 1
        fi
    else
        echo "不支持的操作系统，程序退出。"
        exit 1
    fi
}

# 读取用户输入并保存到配置文件
save_mapping_to_conf() {
    local conf_file="/opt/instance-eip-map.conf"

    read -p "请输入实例ID (例如：i-AAAAAAAAAAA): " instance_id
    read -p "请输入EIP ID (例如：eip-BBBBBBBBBBBBBB): " eip_id
    read -p "请输入共享带宽包ID (例如：cbwp-CCCCCCCCCCCCCCCCC): " bandwidth_package_id

    echo "[mapping]" > "$conf_file"
    echo "${instance_id}=${eip_id}:${bandwidth_package_id}" >> "$conf_file"
}

# 检查服务运行状态
check_service_status() {
    local service_name="aliyun-eip-manager"

    systemctl status "$service_name"
}

# 查看服务日志
view_service_logs() {
    local log_file="/var/log/aliyun-eip-manager.log"

    cat "$log_file"
}

# 提示用户选择操作
echo ""
echo "------------------------------"
echo " 请选择操作："
echo "------------------------------"
echo ""
echo "(1) 安装aliyun-eip-manager服务"
echo ""
echo "(2) 卸载aliyun-eip-manager服务"
echo ""
echo "(3) 修改实例/EIP/带宽包ID并重启服务"
echo ""
echo "(4) 重启aliyun-eip-manager服务"
echo ""
echo "(5) 检查服务运行状态"
echo ""
echo "(6) 查看服务日志"
echo ""
echo "(7) 退出"
echo ""
echo "------------------------------"
read -p ": " action_choice
echo ""

case $action_choice in
    1)
        # 安装服务
        if systemctl is-enabled aliyun-eip-manager &> /dev/null; then
            echo "aliyun-eip-manager服务已安装。"
            exit 1
        else
            install_packages jq
            wget https://raw.githubusercontent.com/simpleAxx/aliyun-eip-manager/main/aliyun-eip-manager -O /opt/aliyun-eip-manager
            chmod +x /opt/aliyun-eip-manager

            save_mapping_to_conf

            cat << EOF > /etc/systemd/system/aliyun-eip-manager.service
[Unit]
Description=Aliyun Eip Manager Service
After=network.target

[Service]
User=<your_username>
ExecStart=/opt/aliyun-eip-manager
Restart=always
RestartSec=60s
StandardOutput=append:/var/log/aliyun-eip-manager.log
StandardError=append:/var/log/aliyun-eip-manager.log

[Install]
WantedBy=multi-user.target
EOF

            sed -i "s/<your_username>/$(whoami)/g" /etc/systemd/system/aliyun-eip-manager.service

            sudo systemctl daemon-reload
            sudo systemctl start aliyun-eip-manager.service
            sudo systemctl enable aliyun-eip-manager.service

            echo "aliyun-eip-manager服务安装成功。"
        fi
        ;;
    2)
        # 卸载服务
        if systemctl is-enabled aliyun-eip-manager &> /dev/null; then
            sudo systemctl stop aliyun-eip-manager.service
            sudo systemctl disable aliyun-eip-manager.service
            sudo rm /etc/systemd/system/aliyun-eip-manager.service
            sudo systemctl daemon-reload
            echo "aliyun-eip-manager服务卸载成功。"
        else
            echo "aliyun-eip-manager服务未安装。"
        fi
        ;;
    3)
        # 修改实例/EIP/带宽包ID并重启服务
        if systemctl is-enabled aliyun-eip-manager &> /dev/null; then
            save_mapping_to_conf
            sudo systemctl daemon-reload
            sudo systemctl restart aliyun-eip-manager.service
            echo "aliyun-eip-manager服务已重启，配置已更新。"
        else
            echo "aliyun-eip-manager服务未安装。"
        fi
        ;;
    4)
        # 重启服务
        if systemctl is-enabled aliyun-eip-manager &> /dev/null; then
            sudo systemctl restart aliyun-eip-manager.service
            echo "aliyun-eip-manager服务已重启。"
        else
            echo "aliyun-eip-manager服务未安装。"
        fi
        ;;
    5)
        # 检查服务运行状态
        check_service_status
        ;;
    6)
        # 查看服务日志
        view_service_logs
        ;;
    7)
        # 退出
        echo "退出程序。"
        exit 0
        ;;
    *)
        echo "无效的选择，程序退出。"
        exit 1
        ;;
esac
