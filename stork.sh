#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/stork.sh"

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 Ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 部署 stork 节点"
        echo "2. 退出脚本"
        echo "================================================================"
        read -p "请输入选择 (1/2): " choice

        case $choice in
            1)  deploy_stork_node ;;
            2)  exit ;;
            *)  echo "无效选择，请重新输入！"; sleep 2 ;;
        esac
    done
}

# 检测并安装环境依赖
function install_dependencies() {
    echo "正在检测系统环境依赖..."

    # 安装 git
    if ! command -v git &> /dev/null; then
        echo "未找到 git，正在安装..."
        sudo apt-get update && sudo apt-get install -y git
    fi

    # 安装 node & npm
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        echo "未找到 node 或 npm，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # 安装 pm2
    if ! command -v pm2 &> /dev/null; then
        echo "未找到 pm2，正在安装..."
        sudo npm install -g pm2
        pm2 startup systemd -u $USER --hp $HOME
    fi

    echo "环境依赖检测完成！"
}

# 部署 stork 节点
function deploy_stork_node() {
    install_dependencies

    echo "正在拉取 stork 仓库..."
    if [ -d "stork" ]; then
        read -p "stork 目录已存在，是否删除并重新拉取？(y/n) " delete_old
        if [[ "$delete_old" =~ ^[Yy]$ ]]; then
            rm -rf stork
        else
            echo "使用现有目录"
            cd stork || return
            goto_configure
            return
        fi
    fi

    if ! git clone https://github.com/sdohuajia/stork.git; then
        echo "仓库拉取失败，请检查网络！"
        return
    fi

    cd stork || return

    goto_configure
}

# 配置与启动函数
function goto_configure() {
    echo "请输入代理地址（格式：http://账号:密码@127.0.0.1:8080）："
    > "proxy.txt"
    while true; do
        read -p "代理地址（回车结束）：" proxy
        [[ -z "$proxy" ]] && break
        echo "$proxy" >> "proxy.txt"
    done

    # 处理账户信息
    echo "检查 accounts.json..."
    if [ -f "accounts.json" ]; then
        read -p "accounts.json 已存在，是否重新输入？(y/n) " overwrite
        [[ "$overwrite" =~ ^[Yy]$ ]] && rm -f "accounts.json"
    fi

    if [ ! -f "accounts.json" ]; then
        echo "[" > "accounts.json"
        first=1
        while true; do
            read -p "邮箱：" username
            [[ -z "$username" ]] && break
            read -p "密码：" password
            if [ $first -eq 1 ]; then
                echo "  { \"username\": \"$username\", \"password\": \"$password\" }" >> "accounts.json"
                first=0
            else
                echo "  ,{ \"username\": \"$username\", \"password\": \"$password\" }" >> "accounts.json"
            fi
        done
        echo "]" >> "accounts.json"
    fi

    echo "安装依赖..."
    npm install
    npm install chalk@4

    # 创建 PM2 配置文件（如果不存在）
    if [ ! -f "ecosystem.config.js" ]; then
        cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: "stork",
      script: "./index.cjs",
      watch: false,
      env: {
        NODE_ENV: "production"
      }
    }
  ]
};
EOF
    fi

    # 使用 PM2 启动
    pm2 delete stork 2>/dev/null
    pm2 start ecosystem.config.js
    pm2 save

    echo "Stork 节点已通过 PM2 启动。"
    echo "查看日志: pm2 logs stork"
    echo "查看状态: pm2 status"
    echo "停止服务: pm2 stop stork"
    echo "重启服务: pm2 restart stork"

    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 启动主菜单
main_menu
