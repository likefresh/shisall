#!/bin/bash
#############################################################
# 自动化加密合约部署脚本
# 版本：1.0
# 环境：Ubuntu 22.04 LTS
# 描述：自动完成Rust安装、依赖配置和加密合约部署的全流程
#############################################################

# 设置颜色和样式
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # 恢复默认颜色

# 设置初始变量
SCRIPT_START_TIME=$(date +%s)
LOG_FILE="seismic_deploy_$(date +%Y%m%d_%H%M%S).log"
INSTALL_DIR="$HOME/seismic-contract-deploy"
REPO_URL="https://github.com/SeismicSystems/try-devnet.git"
SUCCESS=true
DEPENDENCIES_INSTALLED=0
TOTAL_STEPS=6
CURRENT_STEP=0

# 函数: 显示进度条
show_progress() {
    local percentage=$1
    local message=$2
    local bar_size=50
    local filled_size=$((percentage * bar_size / 100))
    local empty_size=$((bar_size - filled_size))
    
    # 构建进度条
    local progress="["
    for ((i=0; i<filled_size; i++)); do
        progress+="#"
    done
    for ((i=0; i<empty_size; i++)); do
        progress+=" "
    done
    progress+="]"
    
    # 清除当前行并显示进度
    echo -ne "\r${BLUE}${BOLD}进度: ${progress} ${percentage}%${NC} - ${message}"
}

# 函数: 更新步骤进度
update_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    show_progress $percentage "$1"
    echo -e "\n" # 添加换行使下一步显示更清晰
}

# 函数: 记录日志
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # 输出到控制台
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${message}"
            ;;
        "WARN")
            echo -e "${YELLOW}[警告]${NC} ${message}"
            ;;
        "ERROR")
            echo -e "${RED}[错误]${NC} ${message}"
            ;;
        *)
            echo -e "[${level}] ${message}"
            ;;
    esac
    
    # 记录到日志文件
    echo -e "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 函数: 检查命令是否成功执行
check_status() {
    if [ $? -ne 0 ]; then
        if [ "$2" = "critical" ]; then
            log "ERROR" "$1执行失败，部署脚本终止！"
            echo -e "\n${RED}${BOLD}严重错误：$1执行失败！${NC}"
            echo -e "${YELLOW}详情请查看日志文件：$LOG_FILE${NC}"
            SUCCESS=false
            exit 1
        else
            log "WARN" "$1执行出现警告，但将继续执行。"
            echo -e "${YELLOW}警告：$1执行出现问题，但将继续执行。${NC}"
        fi
    else
        log "INFO" "$1执行成功。"
    fi
}

# 函数: 检查并安装依赖
check_dependency() {
    local dependency=$1
    log "INFO" "检查依赖: $dependency"
    
    if ! command -v $dependency &> /dev/null; then
        log "INFO" "未找到 $dependency，准备安装..."
        return 1
    else
        log "INFO" "已安装 $dependency: $(command -v $dependency)"
        return 0
    fi
}

# 函数: 检查网络连接 - 已修改为使用curl而非ping
check_network() {
    log "INFO" "检查网络连接..."
    if curl -s --head --request GET https://github.com | grep "HTTP/" > /dev/null; then
        log "INFO" "网络连接正常。"
        return 0
    else
        log "ERROR" "无法连接到github.com，请检查网络设置。"
        return 1
    fi
}

# 函数: 显示帮助信息
show_help() {
    echo -e "${BOLD}加密合约自动部署脚本${NC}"
    echo -e "此脚本会自动安装必要的依赖并部署加密合约。"
    echo
    echo -e "${BOLD}用法:${NC}"
    echo -e "  $0 [选项]"
    echo
    echo -e "${BOLD}选项:${NC}"
    echo -e "  -h, --help      显示此帮助信息"
    echo -e "  -y, --yes       自动确认所有提示"
    echo -e "  -d, --dir DIR   指定安装目录 (默认: $INSTALL_DIR)"
    echo -e "  --no-progress   不显示进度条"
    echo
    echo -e "${BOLD}示例:${NC}"
    echo -e "  $0 -y           自动模式部署"
    echo -e "  $0 -d ~/seismic 在自定义目录部署"
    echo
}

# 函数: 显示执行报告
show_report() {
    local end_time=$(date +%s)
    local execution_time=$((end_time - SCRIPT_START_TIME))
    
    echo -e "\n${BOLD}====== 执行报告 ======${NC}"
    if $SUCCESS; then
        echo -e "${GREEN}${BOLD}状态: 成功√${NC}"
    else
        echo -e "${RED}${BOLD}状态: 失败×${NC}"
    fi
    
    echo -e "${BOLD}执行时长:${NC} $((execution_time / 60))分 $((execution_time % 60))秒"
    echo -e "${BOLD}日志位置:${NC} $(pwd)/$LOG_FILE"
    
    if $SUCCESS; then
        # 尝试获取部署信息
        if [ -f "$INSTALL_DIR/try-devnet/packages/contract/deployed.json" ]; then
            echo -e "${BOLD}合约部署信息:${NC}"
            cat "$INSTALL_DIR/try-devnet/packages/contract/deployed.json" | jq .
        fi
        
        echo -e "\n${GREEN}${BOLD}恭喜！加密合约已成功部署。${NC}"
        echo -e "您现在可以在 ${BOLD}$INSTALL_DIR/try-devnet/packages/contract/${NC} 目录中开始使用。"
    else
        echo -e "\n${RED}${BOLD}部署过程中遇到问题，请查看日志了解详情。${NC}"
    fi
}

# 函数: 清理资源
cleanup() {
    if [ "$1" = "interrupt" ]; then
        echo -e "\n${YELLOW}脚本被中断，正在清理...${NC}"
        SUCCESS=false
    fi
    
    # 保存最终日志
    log "INFO" "脚本执行结束，总用时: $(($(date +%s) - SCRIPT_START_TIME))秒。"
    
    # 显示报告
    show_report
    
    # 提醒用户检查问题
    if ! $SUCCESS; then
        echo -e "\n${BOLD}常见问题排查:${NC}"
        echo -e "1. 网络连接问题: 确保您能访问github.com和相关资源站点"
        echo -e "2. 权限问题: 使用sudo运行或检查目录权限"
        echo -e "3. 磁盘空间: 确保有足够的空间用于安装依赖和克隆代码库"
        echo -e "4. 查看日志: 详细错误信息请查看 $(pwd)/$LOG_FILE"
    fi
    
    exit
}

# 设置中断处理
trap 'cleanup interrupt' INT TERM

# 解析命令行参数
AUTO_CONFIRM=false
SHOW_PROGRESS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -d|--dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --no-progress)
            SHOW_PROGRESS=false
            shift
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 主程序开始
clear
echo -e "${BLUE}${BOLD}=======================================${NC}"
echo -e "${BLUE}${BOLD}     加密合约自动部署脚本 v1.0        ${NC}"
echo -e "${BLUE}${BOLD}=======================================${NC}"
echo -e "此脚本将自动完成以下步骤:"
echo -e "1. 安装Rust语言环境"
echo -e "2. 安装jq工具"
echo -e "3. 安装sfoundryup工具"
echo -e "4. 运行sfoundryup配置环境"
echo -e "5. 克隆代码仓库"
echo -e "6. 部署加密合约"
echo

# 确认开始
if ! $AUTO_CONFIRM; then
    echo -e "${YELLOW}准备开始安装和部署过程，此操作可能需要较长时间。${NC}"
    read -p "是否继续？(y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${RED}操作已取消。${NC}"
        exit 0
    fi
fi

# 检查并创建安装目录
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    check_status "创建安装目录" "critical"
fi

# 进入安装目录
cd "$INSTALL_DIR"
check_status "进入安装目录" "critical"

# 开始记录日志
log "INFO" "开始部署过程，安装目录: $INSTALL_DIR"

# 检查网络连接
# check_network
# if [ $? -ne 0 ]; then
#     echo -e "${RED}${BOLD}网络连接失败，请检查网络设置后重试。${NC}"
#     SUCCESS=false
#     cleanup
# fi

# 1. 安装Rust
update_step "安装Rust"
log "INFO" "开始安装Rust..."

if check_dependency rustc && check_dependency cargo; then
    log "INFO" "Rust已安装，跳过安装步骤。"
else
    echo -e "${YELLOW}正在安装Rust，这可能需要几分钟...${NC}"
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    check_status "下载并安装Rust" "critical"
    
    # 刷新环境变量
    source "$HOME/.cargo/env"
    check_status "加载Rust环境变量" "warn"
    
    # 验证安装
    rustc --version
    check_status "验证Rust安装" "critical"
    cargo --version
    check_status "验证Cargo安装" "critical"
    
    log "INFO" "Rust安装完成。"
fi

# 2. 安装jq
update_step "安装jq"
log "INFO" "开始安装jq..."

if check_dependency jq; then
    log "INFO" "jq已安装，跳过安装步骤。"
else
    echo -e "${YELLOW}正在安装jq...${NC}"
    # Ubuntu特有的安装方式
    sudo apt-get update
    sudo apt-get install -y jq
    check_status "安装jq" "critical"
    
    # 验证安装
    jq --version
    check_status "验证jq安装" "critical"
    
    log "INFO" "jq安装完成。"
fi

# 3. 安装sfoundryup
update_step "安装sfoundryup"
log "INFO" "开始安装sfoundryup..."

if check_dependency sfoundryup; then
    log "INFO" "sfoundryup已安装，跳过安装步骤。"
else
    echo -e "${YELLOW}正在安装sfoundryup...${NC}"
    curl -L -H "Accept: application/vnd.github.v3.raw" \
         "https://api.github.com/repos/SeismicSystems/seismic-foundry/contents/sfoundryup/install?ref=seismic" | bash
    check_status "下载并安装sfoundryup" "critical"
    
    # 直接添加路径到当前PATH环境变量
    export PATH="$HOME/.seismic/bin:$PATH"
    check_status "设置PATH环境变量" "warn"
    
    # 验证安装
    if [ -f "$HOME/.seismic/bin/sfoundryup" ]; then
        log "INFO" "sfoundryup已安装在: $HOME/.seismic/bin/sfoundryup"
    else
        log "ERROR" "无法找到sfoundryup可执行文件"
        check_status "验证sfoundryup安装" "critical"
    fi
    
    log "INFO" "sfoundryup安装完成。"
fi

# 4. 运行sfoundryup
update_step "运行sfoundryup配置环境"
log "INFO" "开始运行sfoundryup..."

echo -e "${YELLOW}正在运行sfoundryup，这可能需要5-60分钟，请耐心等待...${NC}"
echo -e "${YELLOW}(注意: 在98%时可能会停顿较长时间，属于正常现象)${NC}"

# 使用完整路径运行sfoundryup
if [ -f "$HOME/.seismic/bin/sfoundryup" ]; then
    "$HOME/.seismic/bin/sfoundryup"
    check_status "运行sfoundryup" "critical"
else
    # 如果找不到sfoundryup，尝试通过PATH运行
    if command -v sfoundryup &> /dev/null; then
        sfoundryup
        check_status "运行sfoundryup" "critical"
    else
        log "ERROR" "无法找到sfoundryup命令，请确保安装成功。"
        check_status "查找sfoundryup命令" "critical"
    fi
fi

log "INFO" "sfoundryup运行完成。"

# 5. 克隆代码仓库
update_step "克隆代码仓库"
log "INFO" "开始克隆代码仓库..."

if [ -d "$INSTALL_DIR/try-devnet" ]; then
    log "WARN" "try-devnet目录已存在，将使用现有目录。"
else
    echo -e "${YELLOW}正在克隆代码仓库...${NC}"
    git clone --recurse-submodules "$REPO_URL"
    check_status "克隆代码仓库" "critical"
    
    log "INFO" "代码仓库克隆完成。"
fi

# 进入合约目录
cd try-devnet/packages/contract/
check_status "进入合约目录" "critical"

# 6. 部署合约
update_step "部署加密合约"
log "INFO" "开始部署加密合约..."

echo -e "${YELLOW}正在部署合约，这可能需要几分钟时间...${NC}"
bash script/deploy.sh
check_status "部署合约" "critical"

log "INFO" "合约部署完成。"

# 显示100%进度
show_progress 100 "部署完成！"
echo -e "\n\n${GREEN}${BOLD}全部步骤已完成!${NC}\n"

# 显示执行报告
cleanup

exit 0
