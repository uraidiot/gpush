#!/bin/bash
# set -eo pipefail
# set -x

# 颜色配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 提交类型配置
COMMIT_TYPES=(
    "Feature: 新功能"
    "Fix: BUG修复" 
    "Docs: 文档更新"
    "Style: 代码格式调整"
    "Refactor: 代码重构"
    "Test: 测试相关"
    "Chore: 其他修改"
)

# 初始化变量
COMMIT_TYPE=""
COMMIT_MSG=""
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# 带颜色输出函数
error_echo() { echo -e "${RED}[错误] $1${NC}"; }
warn_echo() { echo -e "${YELLOW}[警告] $1${NC}"; }
info_echo() { echo -e "${BLUE}[信息] $1${NC}"; }
success_echo() { echo -e "${GREEN}[成功] $1${NC}"; }

# 安全获取当前分支（兼容空仓库）
get_current_branch() {
    # 抑制错误并处理空值情况
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ -z "$branch" ] || [ "$branch" == "HEAD" ]; then
        echo ""
    else
        echo "$branch"
    fi
}

# 检测未推送提交
has_unpushed_commits() {
    git fetch origin >/dev/null 2>&1
    local unpushed=$(git rev-list @{u}..HEAD --count)
    [ $unpushed -gt 0 ] && return 0 || return 1
}

# 显示提交类型菜单
show_commit_types() {
    echo -e "\n${CYAN}请选择提交类型：${NC}"
    for i in "${!COMMIT_TYPES[@]}"; do
        echo -e "  ${CYAN}$(($i+1))) ${COMMIT_TYPES[$i]}${NC}"
    done
    echo -e "  ${CYAN}0) 跳过类型选择${NC}"
}

# 生成默认提交信息
generate_default_msg() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[自动提交] $timestamp"
}

# 获取提交信息
get_commit_message() {
    while true; do
        show_commit_types
        read -p "请输入选择编号 (默认0): " type_choice
        
        type_choice=${type_choice:-0}

        case $type_choice in
            0) 
                COMMIT_TYPE=""
                break
                ;;
            [1-7])
                index=$(($type_choice-1))
                COMMIT_TYPE="${COMMIT_TYPES[$index]}"
                break
                ;;
            *)
                warn_echo "无效的选项，请重新输入"
                ;;
        esac
    done

    echo -e "\n${CYAN}请输入提交说明（直接回车使用自动生成）：${NC}"
    read commit_msg

    if [ -n "$commit_msg" ]; then
        [ -n "$COMMIT_TYPE" ] && COMMIT_MSG="$COMMIT_TYPE - $commit_msg" || COMMIT_MSG="$commit_msg"
    else
        [ -n "$COMMIT_TYPE" ] && COMMIT_MSG="$COMMIT_TYPE $(generate_default_msg)" || COMMIT_MSG=$(generate_default_msg)
    fi
}

# 增强版前置检查
precheck() {
    # 检查是否在git仓库
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        error_echo "当前目录不是Git仓库"
        exit 1
    fi

    # 检查远程仓库配置
    if ! git remote get-url origin &>/dev/null; then
        error_echo "未配置远程仓库origin"
        exit 1
    fi

    # 处理空分支情况（新建仓库未提交）
    if [ -z "$CURRENT_BRANCH" ]; then
        warn_echo "当前处于初始状态，尚未创建任何分支"
        return
    fi

    # 保护分支确认
    if [[ "$CURRENT_BRANCH" =~ ^(main|master|develop)$ ]]; then
        warn_echo "你正在保护分支 $CURRENT_BRANCH 上操作"
        read -p "是否继续？(y/n) " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
}

# 文件状态检测
check_status() {
    local changes=$(git status --porcelain | wc -l)
    [ $changes -eq 0 ] && return 1 || return 0
}

# 安全提交
safe_commit() {
    git add -A || {
        error_echo "文件添加失败"
        exit 1
    }
    
    git commit -m "$COMMIT_MSG" || {
        error_echo "提交失败"
        exit 1
    }
}

# 带重试推送
retry_push() {
    local max_retry=3
    local attempt=0
    
    while [ $attempt -lt $max_retry ]; do
        if git pull --rebase origin "$CURRENT_BRANCH" && \
           git push origin "$CURRENT_BRANCH"; then
            return 0
        fi
        
        attempt=$((attempt+1))
        warn_echo "操作失败，正在重试 ($attempt/$max_retry)..."
        sleep 1
    done
    
    error_echo "操作失败，请手动处理"
    exit 1
}

main() {
    echo '开始预检查...'
    precheck

    echo '开始处理未推送提交...'
    # 处理未推送提交
    if has_unpushed_commits; then
        echo -e "${YELLOW}⚠️ 发现未推送的本地提交：${NC}"
        git log @{u}..HEAD --oneline --color=always
        read -p "是否立即推送这些提交？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            retry_push
            success_echo "未推送提交已成功同步到远程仓库"
        else
            warn_echo "已跳过未推送提交"
        fi
    fi

    echo '开始处理工作区变更...'
    # 处理工作区变更
    if check_status; then
        echo -e "\n${CYAN}📦 检测到工作区文件变更：${NC}"
        git status --short

        get_commit_message

        echo -e "\n${CYAN}🚀 即将提交以下信息：${NC}"
        echo -e "  ${GREEN}$COMMIT_MSG${NC}"
        read -p "确认提交？(y/n) " -n 1 -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

        safe_commit
        retry_push

        success_echo "提交成功！最新提交记录：${GREEN}$COMMIT_MSG${NC}"
        git log -1 --pretty=format:"%C(yellow)%h%Creset | %C(cyan)%cd%Creset | %s" --date=format:"%Y-%m-%d %H:%M"
    else
        warn_echo "没有需要提交的文件变更"
    fi
}

trap 'error_echo "脚本异常终止"; exit 1' ERR
main "$@"