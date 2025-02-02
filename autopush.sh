#!/bin/bash

# 启用严格错误检查模式
set -eo pipefail

# 配置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 清除颜色

# 初始化参数
COMMIT_MSG=""
MAX_RETRY=3
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# 带颜色输出函数
error_echo() { echo -e "${RED}[错误] $1${NC}"; }
warn_echo() { echo -e "${YELLOW}[警告] $1${NC}"; }
info_echo() { echo -e "${BLUE}[信息] $1${NC}"; }
success_echo() { echo -e "${GREEN}[成功] $1${NC}"; }

# 帮助信息
show_help() {
    echo -e "使用方法:"
    echo -e "  $0 [-m|--message] <提交信息>"
    echo -e "  $0 -h|--help"
    echo -e "\n选项:"
    echo -e "  -m, --message   设置提交信息 (必须)"
    echo -e "  -h, --help      显示帮助信息"
    exit 0
}

# 前置检查函数
precheck() {
    # 检查是否在git仓库
    if [ -z "$CURRENT_BRANCH" ]; then
        error_echo "当前目录不是Git仓库"
        exit 1
    fi

    # 检查远程仓库配置
    if ! git remote get-url origin &>/dev/null; then
        error_echo "未配置远程仓库origin"
        exit 1
    fi

    # 检查是否在主分支保护
    if [[ "$CURRENT_BRANCH" =~ ^(main|master|develop)$ ]]; then
        warn_echo "你正在保护分支 $CURRENT_BRANCH 上操作"
        read -p "是否继续？(y/n) " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
}

# 状态检测函数优化
check_status() {
    # 使用更可靠的状态检测方式
    local changes=0
    while IFS= read -r line; do
        case "${line:0:2}" in
            '??') ((untracked++)) ;;
            ' M') ((modified++))  ;;
            'D ') ((deleted++))   ;;
            'A ') ((added++))     ;;
            'R ') ((renamed++))   ;;
            'C ') ((copied++))    ;;
        esac
        ((changes++))
    done < <(git status --porcelain)

    if [ $changes -eq 0 ]; then
        echo -e "${YELLOW}没有检测到文件变更${NC}"
        exit 0
    fi

    # 显示详细变更信息
    echo -e "${BLUE}检测到以下变更："
    [ $untracked -gt 0 ] && echo -e "  ➕ 未跟踪文件: $untracked"
    [ $modified -gt 0 ]  && echo -e "  ✏️ 修改文件: $modified"
    [ $deleted -gt 0 ]   && echo -e "  ❌ 删除文件: $deleted"
    [ $added -gt 0 ]     && echo -e "  ✅ 新增文件: $added"
    [ $renamed -gt 0 ]   && echo -e "  🏷️ 重命名文件: $renamed"
    [ $copied -gt 0 ]    && echo -e "  ⎘ 复制文件: $copied"
    echo -e "${NC}"
}

# 增强版智能添加
smart_add() {
    # 处理特殊字符文件名
    find . -path ./.git -prune -o -print0 | xargs -0 -I{} git add "{}" 2>/dev/null || {
        # 处理添加失败的特殊文件
        local retry_count=0
        while [ $retry_count -lt 3 ]; do
            echo -e "${YELLOW}正在尝试第 $((retry_count+1)) 次添加文件...${NC}"
            git add -A >/dev/null 2>&1 && return 0
            ((retry_count++))
            sleep 1
        done
        echo -e "${RED}文件添加失败，以下文件可能需要手动处理：${NC}"
        git status --porcelain | grep -E '^(\?\?|..)' | sed 's/^/  /'
        exit 1
    }
}

# 生成提交信息
generate_commit_message() {
    date_str=$(date +"%Y-%m-%d %H:%M:%S")
    echo "自动提交于 $date_str"
}

# 提交处理
commit_changes() {
    local attempt=0
    until [ $attempt -ge $MAX_RETRY ]; do
        git commit -m "$COMMIT_MSG" && return 0
        attempt=$((attempt+1))
        warn_echo "提交失败，正在重试 (第 $attempt 次)..."
        sleep 1
    done
    error_echo "提交失败，已达到最大重试次数"
    exit 1
}

# 推送处理
push_changes() {
    local attempt=0
    until [ $attempt -ge $MAX_RETRY ]; do
        git pull --rebase origin "$CURRENT_BRANCH" && \
        git push origin "$CURRENT_BRANCH" && return 0
        
        attempt=$((attempt+1))
        warn_echo "推送失败，正在重试 (第 $attempt 次)..."
        sleep $((attempt * 2))
    done
    
    error_echo "推送失败，请手动处理"
    exit 1
}

# 主执行流程
main() {
    # 参数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--message)
                COMMIT_MSG="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            *)
                error_echo "未知参数: $1"
                show_help
                ;;
        esac
    done

    [ -z "$COMMIT_MSG" ] && COMMIT_MSG=$(generate_commit_message)

    precheck
    check_status || exit 0
    smart_add
    commit_changes
    push_changes

    success_echo "代码已成功提交并推送到 origin/$CURRENT_BRANCH"
    git log -1 --pretty=format:"提交哈希: %C(yellow)%h%Creset | 时间: %C(cyan)%cd%Creset | 信息: %s"
}

# 异常捕获
trap 'error_echo "脚本异常终止"; exit 1' ERR
main "$@"