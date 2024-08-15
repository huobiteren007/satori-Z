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

# GitHub仓库URL，用于下载修改后的satori.py
GITHUB_RAW="https://raw.githubusercontent.com/Zephyrsailor/satori/main"

# Satori原始文件的URL
SATORI_URL="https://satorinet.io/static/download/satori.zip"

# 检查并安装依赖
install_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo "未找到Docker。正在安装Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    else
        echo "Docker已安装。"
    fi

    local packages="wget python3-venv unzip"
    for package in $packages; do
        if ! dpkg -s $package &> /dev/null; then
            sudo apt-get install -y $package
        else
            echo "$package 已安装。"
        fi
    done
}

# 给用户Docker权限
give_docker_permissions() {
    CURRENT_USER=$(whoami)
    if groups $CURRENT_USER | grep -q docker; then
        echo "用户已有Docker权限。"
    else
        echo "正在给用户Docker权限..."
        sudo groupadd docker 2>/dev/null || true
        sudo usermod -aG docker $CURRENT_USER
        echo "Docker权限已授予。您可能需要注销并重新登录以使更改生效。"
        # 尝试立即应用新的组成员身份
        exec sg docker newgrp `id -gn`
    fi
}

# 创建并配置单个Satori节点
setup_satori_node() {
    local node_num=$1
    local port=$2
    
    WORK_DIR="$HOME/.satori$node_num"
    echo "设置Satori节点 $node_num 在目录 $WORK_DIR"
    
    # 检查节点是否已存在
    if [ -d "$WORK_DIR" ]; then
        echo "节点 $node_num 已存在。跳过..."
        return
    fi
    
    # 创建并进入工作目录
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # 下载并解压原始Satori文件
    if [ ! -f "./satori.zip" ]; then
        wget -P ./ "$SATORI_URL"
        unzip ./satori.zip
        rm ./satori.zip
    fi
    
    # 下载修改后的satori.py
    wget -O satori.py "$GITHUB_RAW/satori.py"
    
    # 设置权限
    chmod +x ./neuron.sh ./satori.py
    
    # 创建Python虚拟环境并安装依赖
    if [ ! -d "./satorienv" ]; then
        python3 -m venv "./satorienv"
        source "./satorienv/bin/activate"
        pip install -r "./requirements.txt"
        deactivate
    fi
    
    # 创建service文件
    if [ ! -f "/etc/systemd/system/satori$node_num.service" ]; then
        cat > satori$node_num.service <<EOL
[Unit]
Description=Satori Node $node_num
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/satorienv/bin/python3 $WORK_DIR/satori.py --port $port --install-dir $WORK_DIR --container-name satorineuron$node_num
Restart=always

[Install]
WantedBy=multi-user.target
EOL

        sudo mv satori$node_num.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable satori$node_num.service
        sudo systemctl start satori$node_num.service
    else
        echo "节点 $node_num 的服务文件已存在。跳过服务创建。"
    fi
    
    echo "Satori节点 $node_num 已创建并在端口 $port 上启动。"
}

# 主函数
main() {
    install_dependencies
    give_docker_permissions
    
    for i in $(seq 1 $NUM_NODES); do
        PORT=$((BASE_PORT + i - 1))
        setup_satori_node $i $PORT
    done

    echo "已创建或检查 $NUM_NODES 个Satori节点。"
}

# 运行主函数
main