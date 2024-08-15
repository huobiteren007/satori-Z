   #!/bin/bash

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
           echo "Docker not found. Installing Docker..."
           curl -fsSL https://get.docker.com -o get-docker.sh
           sudo sh get-docker.sh
           sudo usermod -aG docker $USER
           rm get-docker.sh
       fi

       sudo apt-get update
       sudo apt-get install -y wget python3-venv unzip
   }

   # 创建并配置单个Satori节点
   setup_satori_node() {
       local node_num=$1
       local port=$2
       
       WORK_DIR="$HOME/.satori$node_num"
       
       # 检查节点是否已存在
       if [ -d "$WORK_DIR" ]; then
           echo "Node $node_num already exists. Skipping..."
           return
       fi
       
       # 创建并进入工作目录
       mkdir -p "$WORK_DIR"
       cd "$WORK_DIR"
       
       # 下载并解压原始Satori文件
       wget -P ./ "$SATORI_URL"
       unzip ./satori.zip
       rm ./satori.zip
       
       # 下载修改后的satori.py
       wget -O satori.py "$GITHUB_RAW/satori.py"
       
       # 设置权限
       chmod +x ./neuron.sh
       chmod +x ./satori.py
       
       # 创建Python虚拟环境并安装依赖
       python3 -m venv "./satorienv"
       source "./satorienv/bin/activate"
       pip install -r "./requirements.txt"
       deactivate
       
       # 创建service文件
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
       
       echo "Satori Node $node_num created and started on port $port."
   }

   # 主函数
   main() {
       install_dependencies
       
       for i in $(seq 1 $NUM_NODES); do
           PORT=$((BASE_PORT + i - 1))
           setup_satori_node $i $PORT
       done

       # 添加当前用户到docker组
       sudo groupadd docker
       sudo usermod -aG docker $USER

       echo "Created $NUM_NODES Satori nodes. Please log out and log back in for docker permissions to take effect."
   }

   # 运行主函数
   main
