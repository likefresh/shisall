#!/bin/bash
#########################################################
# 加密合约交互自动化脚本
# 功能：自动安装Bun、安装节点依赖并执行交易
# 运行环境：Ubuntu 22.04 LTS
# 作者：Shell脚本专家
# 日期：2025-04-01
#########################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 日志文件设置
LOG_DIR="$HOME/.encrypted_contract_logs"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d_%H%M%S)_execution.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/SeismicSystems/try-devnet.git"
PROJECT_DIR="try-devnet"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_message=$2
    local is_critical=${3:-true}
    
    echo -e "${RED}错误${NC}: $error_message" | tee -a "$LOG_FILE"
    if [ "$is_critical" = true ]; then
        echo -e "${RED}这是一个严重错误，脚本将终止执行。${NC}" | tee -a "$LOG_FILE"
        echo "执行报告已保存到: $LOG_FILE"
        exit "$exit_code"
    else
        echo -e "${YELLOW}这是一个非严重错误，脚本将继续执行。${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
}

# 进度显示函数
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percentage=$((current * 100 / total))
    local completed=$((percentage / 2))
    local remaining=$((50 - completed))
    
    printf "${BLUE}[%-${completed}s${NC}${YELLOW}%-${remaining}s${NC}] ${GREEN}%d%%${NC} %s\r" "$(printf '%0.s#' $(seq 1 $completed))" "$(printf '%0.s.' $(seq 1 $remaining))" "$percentage" "$message"
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# 记录日志函数
log_message() {
    local message=$1
    local level=${2:-"INFO"}
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [ "$level" = "INFO" ]; then
        echo -e "${BLUE}[$level]${NC} $message"
    elif [ "$level" = "SUCCESS" ]; then
        echo -e "${GREEN}[$level]${NC} $message"
    elif [ "$level" = "WARNING" ]; then
        echo -e "${YELLOW}[$level]${NC} $message"
    elif [ "$level" = "ERROR" ]; then
        echo -e "${RED}[$level]${NC} $message"
    fi
}

# 检查系统环境
check_environment() {
    log_message "正在检查系统环境..." "INFO"
    
    # 检查是否为Ubuntu 22.04
    if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
        log_message "警告：此脚本针对Ubuntu 22.04进行优化，当前系统可能不兼容。" "WARNING"
    fi
    
    # 检查curl是否安装
    if ! command -v curl &> /dev/null; then
        log_message "curl未安装，正在安装..." "INFO"
        sudo apt update && sudo apt install -y curl || handle_error 1 "无法安装curl"
        log_message "curl安装成功" "SUCCESS"
    fi
    
    # 检查网络连接
    # if ! ping -c 1 google.com &> /dev/null && ! ping -c 1 baidu.com &> /dev/null; then
    #     handle_error 2 "网络连接不可用，请检查您的网络设置" true
    # fi
    
    log_message "环境检查完成" "SUCCESS"
}

# 安装Bun
install_bun() {
    log_message "开始安装Bun..." "INFO"
    
    # 检查Bun是否已安装
    if command -v bun &> /dev/null; then
        local current_version=$(bun --version)
        log_message "Bun已安装（版本：$current_version），跳过安装步骤" "INFO"
        return 0
    fi
    
    # 下载并安装Bun
    log_message "正在下载并安装Bun..." "INFO"
    
    if curl -fsSL https://bun.sh/install | bash >> "$LOG_FILE" 2>&1; then
        # 加载Bun到当前会话
        export PATH="$HOME/.bun/bin:$PATH"
        export BUN_INSTALL="$HOME/.bun"
        log_message "Bun安装成功" "SUCCESS"
        
        # 验证安装
        if ! command -v bun &> /dev/null; then
            handle_error 3 "Bun已安装但在PATH中不可用，请手动将~/.bun/bin添加到PATH中" false
        fi
    else
        handle_error 3 "Bun安装失败" true
    fi
}

# 克隆仓库
clone_repository() {
    log_message "开始克隆仓库..." "INFO"
    
    # 检查是否已经存在项目目录
    if [ -d "$PROJECT_DIR" ]; then
        log_message "项目目录'$PROJECT_DIR'已存在" "INFO"
        read -p "是否要重新克隆仓库？这将删除现有目录 (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$PROJECT_DIR"
        else
            log_message "使用现有项目目录" "INFO"
            return 0
        fi
    fi
    
    # 克隆仓库及其子模块
    log_message "正在克隆仓库及其子模块..." "INFO"
    git clone --recurse-submodules "$REPO_URL" "$PROJECT_DIR" >> "$LOG_FILE" 2>&1 || handle_error 10 "无法克隆仓库" true
    
    log_message "仓库克隆成功" "SUCCESS"
}

# 安装Node依赖
install_dependencies() {
    log_message "开始安装Node依赖..." "INFO"
    
    # 进入正确的项目目录
    if [ ! -d "$PROJECT_DIR" ]; then
        log_message "项目目录'$PROJECT_DIR'不存在，将尝试克隆仓库" "WARNING"
        clone_repository
    fi
    
    # 进入contract目录
    cd "$PROJECT_DIR/packages/contract/" || handle_error 5 "无法进入contract目录" true
    
    # 安装依赖
    log_message "正在安装依赖项..." "INFO"
    
    bun install >> "$LOG_FILE" 2>&1 || handle_error 6 "依赖项安装失败" true
    
    log_message "Node依赖安装成功" "SUCCESS"
}

# 发送交易
send_transactions() {
    log_message "开始发送交易..." "INFO"
    
    # 确保我们在正确的目录中
    if [[ "$PWD" != *"$PROJECT_DIR/packages/contract"* ]]; then
        cd "$PROJECT_DIR/packages/contract/" || handle_error 5 "无法进入contract目录" true
    fi
    
    # 检查脚本是否存在
    if [ ! -f "script/transact.sh" ]; then
        log_message "在当前目录未找到交易脚本" "WARNING"
        # 尝试查找脚本
        local script_path=$(find "$PROJECT_DIR" -name "transact.sh" 2>/dev/null | head -n 1)
        
        if [ -n "$script_path" ]; then
            log_message "找到交易脚本: $script_path" "INFO"
            cd "$(dirname "$script_path")/.." || handle_error 8 "无法切换到脚本所在目录" true
        else
            handle_error 7 "交易脚本不存在 (script/transact.sh)" true
        fi
    fi
    
    # 添加可执行权限
    chmod +x script/transact.sh || handle_error 8 "无法为交易脚本添加可执行权限" false
    
    # 执行交易脚本
    log_message "正在执行交易脚本..." "INFO"
    
    if bash script/transact.sh >> "$LOG_FILE" 2>&1; then
        log_message "交易发送成功" "SUCCESS"
    else
        handle_error 9 "交易发送失败" true
    fi
}

# 生成摘要报告
generate_report() {
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    local minutes=$((execution_time / 60))
    local seconds=$((execution_time % 60))
    
    echo -e "\n${GREEN}========== 执行摘要报告 ==========${NC}"
    echo -e "${BLUE}执行时间${NC}: $minutes 分 $seconds 秒"
    echo -e "${BLUE}日志位置${NC}: $LOG_FILE"
    
    # 检查资源使用情况
    echo -e "${BLUE}系统资源使用情况${NC}:"
    echo -e "  CPU使用率: $(top -b -n1 | grep "Cpu(s)" | awk '{print $2}')%"
    echo -e "  内存使用率: $(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)%"
    echo -e "  磁盘使用率: $(df -h . | tail -n 1 | awk '{print $5}')"
    
    # 检查Bun和项目状态
    if command -v bun &> /dev/null; then
        echo -e "${BLUE}Bun状态${NC}: ${GREEN}已安装${NC} ($(bun --version))"
    else
        echo -e "${BLUE}Bun状态${NC}: ${RED}未安装${NC}"
    fi
    
    # 检查交易结果
    echo -e "${BLUE}交易状态${NC}: ${GREEN}已执行${NC} (详情请查看日志)"
    
    echo -e "${GREEN}========== 报告结束 ==========${NC}"
    echo -e "\n使用方法：${YELLOW}bash $(basename "$0") [--help|--clean|--log]${NC}"
    echo -e "  --help  : 显示帮助信息"
    echo -e "  --clean : 清理临时文件"
    echo -e "  --log   : 仅显示日志位置"
}

# 显示帮助
show_help() {
    echo -e "${BLUE}加密合约交互自动化脚本${NC}"
    echo -e "用法: bash $(basename "$0") [选项]"
    echo -e ""
    echo -e "选项:"
    echo -e "  --help    显示此帮助信息"
    echo -e "  --clean   清理临时文件并退出"
    echo -e "  --log     显示日志位置并退出"
    echo -e "  --skip-bun  跳过Bun安装步骤"
    echo -e ""
    echo -e "GitHub部署:"
    echo -e "  git clone https://github.com/your-username/encrypted-contract-automation.git"
    echo -e "  cd encrypted-contract-automation"
    echo -e "  chmod +x interact_contract.sh"
    echo -e "  ./interact_contract.sh"
    echo -e ""
    echo -e "常见问题排查:"
    echo -e "  1. Bun安装失败: 检查网络连接或手动安装Bun"
    echo -e "  2. 依赖安装失败: 检查项目结构和Bun版本"
    echo -e "  3. 交易失败: 查看日志了解详细错误信息"
    exit 0
}

# 清理函数
clean_up() {
    log_message "正在清理..." "INFO"
    
    # 清理可能的临时文件
    find "$LOG_DIR" -type f -name "*.tmp" -delete
    
    # 保留最近10个日志文件
    if [ "$(ls -1 "$LOG_DIR" | wc -l)" -gt 10 ]; then
        ls -t "$LOG_DIR" | tail -n +11 | xargs -I {} rm "$LOG_DIR/{}"
        log_message "已清理旧日志文件" "INFO"
    fi
    
    log_message "清理完成" "SUCCESS"
    echo "日志位置: $LOG_FILE"
    exit 0
}

# 处理命令行参数
process_args() {
    case "$1" in
        --help)
            show_help
            ;;
        --clean)
            clean_up
            ;;
        --log)
            echo "最新日志位置: $(ls -t "$LOG_DIR" | head -n1)"
            exit 0
            ;;
        --skip-bun)
            SKIP_BUN=true
            log_message "将跳过Bun安装步骤" "INFO"
            ;;
        *)
            ;;
    esac
}

# 主函数
main() {
    local start_time=$(date +%s)
    local total_steps=5  # 增加了一个步骤
    local current_step=0
    
    log_message "加密合约交互自动化脚本开始执行" "INFO"
    echo "日志将保存到: $LOG_FILE"
    
    # 更新进度
    current_step=$((current_step + 1))
    show_progress "$current_step" "$total_steps" "检查系统环境"
    check_environment
    
    # 克隆仓库
    current_step=$((current_step + 1))
    show_progress "$current_step" "$total_steps" "克隆仓库"
    clone_repository
    
    # 安装Bun
    if [ "$SKIP_BUN" != true ]; then
        current_step=$((current_step + 1))
        show_progress "$current_step" "$total_steps" "安装Bun"
        install_bun
    else
        log_message "已跳过Bun安装步骤" "INFO"
        current_step=$((current_step + 1))
        show_progress "$current_step" "$total_steps" "已跳过Bun安装"
    fi
    
    # 安装依赖
    current_step=$((current_step + 1))
    show_progress "$current_step" "$total_steps" "安装Node依赖"
    install_dependencies
    
    # 发送交易
    current_step=$((current_step + 1))
    show_progress "$current_step" "$total_steps" "发送交易"
    send_transactions
    
    # 生成报告
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    log_message "脚本执行完成，耗时: $execution_time 秒" "SUCCESS"
    
    generate_report
}

# 处理参数
process_args "$@"

# 执行主函数
main
