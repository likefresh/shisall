#!/bin/bash
#############################################################
# 自动化加密合约部署脚本
# 版本：1.1
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
TOTAL_STEPS=7
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

# 函数: 检查并更新系统库
check_system_libraries() {
    log "INFO" "检查系统库版本..."
    
    # 获取当前GLIBC版本
    local glibc_version=$(ldd --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+$')
    log "INFO" "当前GLIBC版本: $glibc_version"
    
    # 检查GLIBC版本是否至少为2.34
    if [ "$(printf '%s\n' "2.34" "$glibc_version" | sort -V | head -n1)" != "2.34" ]; then
        log "WARN" "GLIBC版本低于2.34，可能会导致兼容性问题。"
        echo -e "${YELLOW}检测到GLIBC版本($glibc_version)低于所需版本(2.34)，将尝试更新系统库...${NC}"
        
        # 更新系统库
        echo -e "${YELLOW}正在更新系统包列表...${NC}"
        sudo apt-get update
        check_status "更新系统包列表" "warn"
        
        echo -e "${YELLOW}正在升级系统库...${NC}"
        sudo apt-get upgrade -y
        check_status "升级系统库" "warn"
        
        # 安装更新的C/C++库
        echo -e "${YELLOW}正在安装C/C++开发库...${NC}"
        sudo apt-get install -y build-essential libc6-dev libstdc++6
        check_status "安装C/C++开发库" "warn"
        
        # 再次检查GLIBC版本
        glibc_version=$(ldd --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+$')
        log "INFO" "更新后的GLIBC版本: $glibc_version"
        
        if [ "$(printf '%s\n' "2.34" "$glibc_version" | sort -V | head -n1)" != "2.34" ]; then
            log "WARN" "即使更新后，GLIBC版本仍低于2.34。"
            echo -e "${YELLOW}注意：即使更新后，系统GLIBC版本($glibc_version)仍低于所需版本(2.34)。${NC}"
            echo -e "${YELLOW}这可能意味着你使用的是较旧的Ubuntu版本。将尝试使用替代方法。${NC}"
            return 1
        else
            log "INFO" "系统库更新成功。"
            return 0
        fi
    else
        log "INFO" "GLIBC版本检查通过。"
        return 0
    fi
}

# 函数: 设置Docker环境作为备选方案
setup_docker_fallback() {
    log "INFO" "正在设置Docker环境作为备选方案..."
    
    # 检查Docker是否已安装
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker未安装，正在安装Docker...${NC}"
        
        # 安装Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        check_status "下载Docker安装脚本" "critical"
        
        sudo sh get-docker.sh
        check_status "安装Docker" "critical"
        
        # 添加当前用户到docker组
        sudo usermod -aG docker $USER
        check_status "将用户添加到docker组" "warn"
        
        # 提醒用户可能需要重新登录
        echo -e "${YELLOW}已将当前用户添加到docker组，可能需要重新登录才能生效。${NC}"
        echo -e "${YELLOW}如果后续Docker命令失败，请尝试退出并重新登录后再运行脚本。${NC}"
    fi
    
    # 创建Docker镜像和容器
    echo -e "${YELLOW}正在创建适用于合约部署的Docker镜像...${NC}"
    
    # 创建Dockerfile
    cat > Dockerfile << EOF
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl git build-essential jq \
    && rm -rf /var/lib/apt/lists/*

# 安装Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# 安装sfoundryup
RUN curl -L -H "Accept: application/vnd.github.v3.raw" \
    "https://api.github.com/repos/SeismicSystems/seismic-foundry/contents/sfoundryup/install?ref=seismic" | bash
ENV PATH="/root/.seismic/bin:${PATH}"

# 设置工作目录
WORKDIR /app

# 启动命令
CMD ["/bin/bash"]
EOF
    
    check_status "创建Dockerfile" "critical"
    
    # 构建Docker镜像
    docker build -t seismic-deploy .
    check_status "构建Docker镜像" "critical"
    
    log "INFO" "Docker环境设置完成。"
    return 0
}

# 函数: 在Docker中运行部署
deploy_in_docker() {
    log "INFO" "在Docker中运行部署..."
    
    # 克隆代码仓库（在本地进行）
    if [ ! -d "$INSTALL_DIR/try-devnet" ]; then
        echo -e "${YELLOW}正在克隆代码仓库...${NC}"
        git clone --recurse-submodules "$REPO_URL"
        check_status "克隆代码仓库" "critical"
    fi
    
    # 运行Docker容器执行部署
    echo -e "${YELLOW}在Docker中运行部署，这可能需要一些时间...${NC}"
    
    # 创建部署脚本
    cat > docker_deploy.sh << EOF
#!/bin/bash
cd /app/try-devnet/packages/contract/
bash script/deploy.sh
EOF
    
    chmod +x docker_deploy.sh
    check_status "创建Docker部署脚本" "critical"
    
    # 运行Docker容器
    docker run --rm -v "$INSTALL_DIR:/app" seismic-deploy /app/docker_deploy.sh
    check_status "在Docker中部署合约" "critical"
    
    log "INFO" "Docker部署完成。"
    return 0
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
    echo -e "  --docker        强制使用Docker进行部署"
    echo
    echo -e "${BOLD}示例:${NC}"
    echo -e "  $0 -y           自动模式部署"
    echo -e "  $0 -d ~/seismic 在自定义目录部署"
    echo -e "  $0 --docker     使用Docker容器部署"
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
        echo -e "4. 系统版本: 如果遇到GLIBC版本错误，考虑升级系统或使用Docker"
        echo -e "5. 查看日志: 详细错误信息请查看 $(pwd)/$LOG_FILE"
    fi
    
    exit
}

# 设置中断处理
trap 'cleanup interrupt' INT TERM

# 解析命令行参数
AUTO_CONFIRM=false
SHOW_PROGRESS=true
USE_DOCKER=false

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
        --docker)
            USE_DOCKER=true
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
echo -e "${BLUE}${BOLD}     加密合约自动部署脚本 v1.1        ${NC}"
echo -e "${BLUE}${BOLD}=======================================${NC}"
echo -e "此脚本将自动完成以下步骤:"
echo -e "1. 检查系统库版本"
echo -e "2. 安装Rust语言环境"
echo -e "3. 安装jq工具"
echo -e "4. 安装sfoundryup工具"
echo -e "5. 运行sfoundryup配置环境"
echo -e "6. 克隆代码仓库"
echo -e "7. 部署加密合约"
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

# 1. 检查系统库版本
update_step "检查系统库版本"

if $USE_DOCKER; then
    log "INFO" "已指定使用Docker，跳过系统库检查。"
    SYSTEM_LIBS_OK=false
else
    check_system_libraries
    SYSTEM_LIBS_OK=$?
fi

if $USE_DOCKER; then
    # 如果使用Docker，部署流程会有所不同
    # 2. 设置Docker环境
    update_step "设置Docker环境"
    setup_docker_fallback
    
    # 3. 在Docker中部署
    update_step "在Docker中部署"
    deploy_in_docker
    
    # 显示100%进度
    show_progress 100 "Docker部署完成！"
    echo -e "\n\n${GREEN}${BOLD}全部步骤已完成!${NC}\n"
    
    # 显示执行报告
    cleanup
else
    # 正常流程继续
    # 2. 安装Rust
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

    # 3. 安装jq
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

    # 4. 安装sfoundryup
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

    # 5. 运行sfoundryup
    update_step "运行sfoundryup配置环境"
    log "INFO" "开始运行sfoundryup..."

    echo -e "${YELLOW}正在运行sfoundryup，这可能需要5-60分钟，请耐心等待...${NC}"
    echo -e "${YELLOW}(注意: 在98%时可能会停顿较长时间，属于正常现象)${NC}"

    # 创建一个临时脚本来运行sfoundryup并捕获其输出
    cat > run_sfoundryup.sh << 'EOF'
#!/bin/bash
set +e  # 不退出出错
if [ -f "$HOME/.seismic/bin/sfoundryup" ]; then
    "$HOME/.seismic/bin/sfoundryup" 2>&1 | tee sfoundryup_output.log
else
    sfoundryup 2>&1 | tee sfoundryup_output.log
fi

# 检查输出，看是否只有文件移动错误
if grep -q "mv: 'target/release/sanvil' and '/root/.seismic/bin/sanvil' are the same file" sfoundryup_output.log; then
    # 如果存在目标文件，我们认为这是非关键错误
    if [ -f "$HOME/.seismic/bin/sanvil" ]; then
        echo "检测到文件移动错误，但sanvil文件已存在，继续执行..."
        exit 0
    fi
fi

# 检查sanvil是否存在，即使有错误
if [ -f "$HOME/.seismic/bin/sanvil" ]; then
    exit 0
else
    # 真正的错误，退出非零状态
    exit 1
fi
EOF

    chmod +x run_sfoundryup.sh
    ./run_sfoundryup.sh

    if [ $? -ne 0 ]; then
        log "ERROR" "运行sfoundryup失败，无法继续。"
        check_status "运行sfoundryup" "critical"
    else
        log "INFO" "sfoundryup运行完成。"
        # 检查是否已安装sanvil工具
        if [ -f "$HOME/.seismic/bin/sanvil" ]; then
            log "INFO" "sanvil工具已安装在: $HOME/.seismic/bin/sanvil"
        else
            log "ERROR" "无法找到sanvil工具，安装可能不完整。"
            check_status "验证sanvil安装" "critical"
        fi
    fi

    # 清理临时文件
    rm -f run_sfoundryup.sh sfoundryup_output.log

    log "INFO" "sfoundryup配置已完成。"

    # 6. 克隆代码仓库
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

    # 7. 部署合约
    update_step "部署加密合约"
    log "INFO" "开始部署加密合约..."

    echo -e "${YELLOW}正在部署合约，这可能需要几分钟时间...${NC}"
    bash script/deploy.sh
    
    # 检查部署状态
    if [ $? -ne 0 ]; then
        log "ERROR" "使用系统环境部署合约失败，尝试使用Docker作为备选方案..."
        echo -e "${RED}使用系统环境部署合约失败，尝试使用Docker作为备选方案...${NC}"
        
        # 返回安装目录
        cd "$INSTALL_DIR"
        
        # 设置Docker环境
        setup_docker_fallback
        
        # 在Docker中部署
        deploy_in_docker
    else
        log "INFO" "合约部署完成。"
    fi

    # 显示100%进度
    show_progress 100 "部署完成！"
    echo -e "\n\n${GREEN}${BOLD}全部步骤已完成!${NC}\n"

    # 显示执行报告
    cleanup
fi

exit 0
