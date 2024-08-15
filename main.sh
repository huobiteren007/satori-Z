#!/bin/bash

# 启用错误时退出
set -e

# 启用调试模式，显示执行的每一行命令
set -x

# 默认值
DEFAULT_NUM_NODES=3
DEFAULT_BASE_PORT=24601

# 解析命令行参数
NUM_NODES=${1:-$DEFAULT_NUM_NODES}
BASE_PORT=${2:-$DEFAULT_BASE_PORT}

# 显示使用的值
echo "使用节点数量: $NUM_NODES"
echo "使用基础端口: $BASE_PORT"

# Satori文件的URL
SATORI_URL="https://satorinet.io/static/download/linux/satori.zip"

# GitHub仓库URL，用于下载修改后的satori.py
GITHUB_RAW="https://raw.githubusercontent.com/Zephyrsailor/satori/main"

# 安装依赖
install_dependencies() {
    sudo apt update
    sudo apt install -y unzip docker.io python3 python3-pip
    sudo pip3 install requests
}

# 给予当前用户Docker权限
give_docker_permissions() {
    sudo groupadd docker || true
    sudo usermod -aG docker $USER
    newgrp docker
}

# 下载并解压Satori文件
download_and_extract_satori() {
    if [ ! -f "satori.zip" ]; then
        wget $SATORI_URL -O satori.zip
    fi
    unzip -o satori.zip -d satori
}

# 设置Satori节点
setup_satori_node() {
    local node_num=$1
    local port=$2
    
    cd satori
    
    # 下载修改后的satori.py文件
    wget $GITHUB_RAW/satori.py -O satori.py
    
    # 创建配置文件
    cat > config$node_num.json <<EOF
{
    "port": $port
}
EOF
    
    # 创建systemd服务文件
    sudo tee /etc/systemd/system/satori$node_num.service > /dev/null <<EOF
[Unit]
Description=Satori Node $node_num
After=network.target

[Service]
ExecStart=/usr/bin/python3 $(pwd)/satori.py $(pwd)/config$node_num.json
WorkingDirectory=$(pwd)
User=$USER
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # 启动服务
    sudo systemctl daemon-reload
    sudo systemctl enable satori$node_num.service
    sudo systemctl start satori$node_num.service
    
    echo "Satori节点 $node_num 已创建并在端口 $port 上启动。"
    
    cd ..
}

# 主函数
main() {
    install_dependencies
    give_docker_permissions
    download_and_extract_satori
    
    for i in $(seq 1 $NUM_NODES); do
        PORT=$((BASE_PORT + i - 1))
        setup_satori_node $i $PORT
    done

    echo "已创建 $NUM_NODES 个Satori节点。"
    
    # 清理下载的文件
    rm -f satori.zip
    echo "清理完成。"
}

# 运行主函数
main