#!/bin/bash

# 增强脚本健壮性
set -e

# 定义常量
COMMIT_TYPES=("feat" "fix" "docs" "style" "refactor" "test" "chore" "init")
COMMIT_TYPES_DESC=("新增" "修复" "文档" "样式" "重构" "测试" "构建" "初始化")

# 获取当前分支
current_branch=$(git symbolic-ref --short HEAD)
echo "当前分支是：$current_branch"

# 提示当前分支并手工确认
read -p "请确认当前分支是否正确（y/n）:" confirm_branch
if [ "$confirm_branch" != "y" ]; then
  echo "操作已取消"
  exit 1
fi

# 检查是否有文件未跟踪或者有修改未提交
status=$(git status --porcelain)
if [ -n "$status" ]; then
  echo "存在未提交或未跟踪文件，请先提交或添加文件"
  git add .
  # 选择commit类型, 显示commit类型的中文名称
  echo "请选择commit类型："
  for i in "${!COMMIT_TYPES[@]}"; do
    echo "$i. ${COMMIT_TYPES[$i]} - ${COMMIT_TYPES_DESC[$i]}"
  done
  read -p "请输入数字选择commit类型（默认为0：${COMMIT_TYPES[0]})：" commit_index
  commit_index=${commit_index:-0}
  commit_type=${COMMIT_TYPES[$commit_index]}
  read -p "请输入commit信息:" commit_message
  git commit -m "$commit_type($current_branch): $commit_message"
fi

# 获取当前分支的远程跟踪分支
remote_branch=$(git rev-parse --abbrev-ref ${current_branch}@{upstream} 2>&1)

if [ $? -ne 0 ]; then # 检查命令执行是否成功
  echo "获取远程跟踪分支失败"
  exit 1
fi

if [ -z "$remote_branch" ]; then
  echo "当前分支 '$current_branch' 没有远程跟踪分支."
  echo "尝试建立远程跟踪关系..."
  git push -u origin $current_branch
  echo "建立远程跟踪关系成功"
  read -p "请确认是否要推送代码（y/n）:" confirm_push
  if [ "$confirm_push" != "y" ]; then
    echo "操作已取消"
    exit 1
  fi
  git push origin $current_branch
else
  echo "当前分支 '$current_branch' 与远程跟踪分支 '$remote_branch' 建立了联系."
  git pull --rebase origin $current_branch
  if [ $? -ne 0 ]; then
    echo "合并远程分支到本地分支变基失败"
    exit 1
  fi
  if [ -n "$(git status --porcelain)" ]; then
    echo "存在冲突，请手动解决冲突后再次尝试推送代码"
    exit 1
  fi
  read -p "请确认是否要推送代码（y/n）:" confirm_push
  if [ "$confirm_push" != "y" ]; then
    echo "操作已取消"
    exit 1
  fi
  git push origin $current_branch
  echo "推送成功"
fi