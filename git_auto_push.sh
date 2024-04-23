#!/bin/bash

set -e  # 任何命令的退出状态不为0时立即退出脚本

# 获取当前分支
current_branch=$(git symbolic-ref --short HEAD)

# 提示当前分支并手工确认
echo "当前分支是：$current_branch"
read -p "请确认当前分支是否正确（y/n）:" confirm_branch
if [ "$confirm_branch" != "y" ]; then
  echo "操作已取消"
  exit 1
fi

# 检查是否有文件未跟踪或者有修改未提交
if [ -n "$(git status --porcelain)" ]; then
  echo "存在未提交或未跟踪文件，请先提交或添加文件"
  # 添加文件到暂存区
  git add .  # 添加所有文件
  # 选择commit类型, 显示commit类型的中文名称
  read -p "请选择commit类型（feat、fix、docs、style、refactor、test、chore、init）:" commit_type
  # 提示输入commit信息
  read -p "请输入commit信息:" commit_message
  # 执行git commit命令提交代码
  git commit -m "$commit_type($current_branch): $commit_message"
fi

# 检查是否有远程分支和当前分支建立联系
if [ -n "$(git config --get-regexp '^branch\.[^.]*\.remote$')" ]; then
  echo "存在远程分支，正在尝试推送代码"
  # 合并远程分支到本地分支变基
  git pull --rebase origin $current_branch
  # 检查是否有冲突
  if [ -n "$(git status --porcelain)" ]; then
    echo "存在冲突，请手动解决冲突后再次尝试推送代码"
    exit 1
  fi
  # 提示执行推送操作
  read -p "请确认是否要推送代码（y/n）:" confirm_push
  if [ "$confirm_push" != "y" ]; then
    echo "操作已取消"
    exit 1
  fi
  # 执行推送操作
  git push origin $current_branch
  # 提示推送成功
  echo "推送成功"
  # 上传代码到远程仓库

else
  echo "当前分支没有远程分支，请先创建远程分支"
  # 推送当前分支并建立与远程上游的跟踪关系
  git push --set-upstream origin $current_branch
  echo "建立远程跟踪关系成功"
  # 提示执行推送操作
  read -p "请确认是否要推送代码（y/n）:" confirm_push
  if [ "$confirm_push" != "y" ]; then
    echo "操作已取消"
    exit 1
  fi
  # 上传代码到远程仓库
  git push origin $current_branch
fi






