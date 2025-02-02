#!/bin/bash

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 恢复默认颜色

# 函数：推送代码并处理结果
push_code() {
    echo -e "${YELLOW}开始推送代码...${NC}"
    git push
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}代码已成功推送到远程仓库。${NC}"
    else
        echo -e "${RED}推送失败。请检查网络或权限。${NC}"
        exit 1
    fi
}

# 获取当前分支
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}无法获取当前分支。请确保你在一个Git仓库中。${NC}"
    exit 1
fi

# 检查远程分支是否存在
if ! git ls-remote --exit-code origin "$current_branch" >/dev/null 2>&1; then
    echo -e "${YELLOW}远程分支 origin/$current_branch 不存在。${NC}"
    read -p "是否创建并推送该分支？(y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        git push --set-upstream origin "$current_branch"
        exit $?
    else
        echo -e "${RED}操作已取消。${NC}"
        exit 1
    fi
fi

# 获取未推送的提交差异
diff=$(git log "origin/$current_branch..HEAD")

# 分支未推送提交逻辑
if [ -z "$diff" ]; then
    echo -e "${YELLOW}开始自动流程...${NC}"
    status=$(git status --porcelain)
    
    if [ -z "$status" ]; then
        echo -e "${GREEN}没有文件修改。退出。${NC}"
        exit 0
    else
        echo -e "${YELLOW}检测到未提交的修改...${NC}"
        read -p "是否暂存修改（Stash）？(y/n): " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            git stash
            echo -e "${GREEN}修改已暂存，可通过 git stash pop 恢复。${NC}"
            exit 0
        fi

        read -p "是否在分支 ${current_branch} 提交代码？(y/n): " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            # 添加文件
            git add .
            if [ $? -ne 0 ]; then
                echo -e "${RED}git add 失败。请检查文件状态。${NC}"
                exit 1
            fi
            echo -e "${GREEN}已执行 git add .${NC}"

            # 提交代码
            read -p "请输入 commit 信息: " commit_msg
            git commit -m "$commit_msg"
            if [ $? -ne 0 ]; then
                echo -e "${RED}git commit 失败。请检查提交信息。${NC}"
                exit 1
            fi

            # 拉取远程代码（带冲突处理指引）
            echo -e "${YELLOW}开始拉取远程代码...${NC}"
            git pull -r
            if [ $? -ne 0 ]; then
                echo -e "${RED}git pull 失败。请按以下步骤操作：${NC}"
                echo "1. 手动解决冲突后执行: git add ."
                echo "2. 继续变基操作: git rebase --continue"
                echo "3. 重新运行此脚本"
                exit 1
            fi

            # 推送代码
            push_code
        else
            echo -e "${YELLOW}操作已取消。${NC}"
            exit 0
        fi
    fi
else
    # 处理未推送的提交
    echo -e "${YELLOW}检测到未推送的提交。${NC}"
    read -p "是否直接推送？(y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        # 检查分支是否落后
        if git status | grep -q "Your branch is behind"; then
            echo -e "${YELLOW}当前分支落后于远程分支，正在变基更新...${NC}"
            git pull --rebase
            if [ $? -ne 0 ]; then
                echo -e "${RED}变基失败。请手动解决冲突后重试。${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}可以直接推送代码。${NC}"
        fi
        push_code
    else
        echo -e "${YELLOW}操作已取消。${NC}"
        exit 0
    fi
fi