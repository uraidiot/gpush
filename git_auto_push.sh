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

# 检查是否有文件未跟踪
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "存在未跟踪文件，请先添加或忽略文件"
  # 将文件添加到暂存区
  git add .  # 添加所有文件
  # 选择commit类型
  read -p "请选择commit类型（feat、fix、docs、style、refactor、test、chore,init）:" commit_type
  # 提示输入commit信息
  read -p "请输入commit信息:" commit_message
  # 执行git commit命令提交代码
  git commit -m "$commit_type($current_branch): $commit_message"
fi

# 检查当前分支是否有对应的远程分支
remote_branch=$(git branch -r --contains $current_branch)
if [ -z "$remote_branch" ]; then
  # 推送当前分支并建立与远程上游的跟踪
  git push --set-upstream origin $current_branch
  echo "推送成功，建立与远程上游的跟踪"
  # 提示是否推送当前分支
  read -p "当前分支已存在远程分支，是否推送当前分支（y/n）:" push_branch
  if [ "$push_branch" == "y" ]; then
    # 执行git push命令上传代码到远程仓库
    git push
  fi
else
  # 检查当前分支是否落后于远程分支
  git fetch
  if [ -n "$(git log --oneline @{upstream}..$current_branch)" ]; then
    # 提示是否拉取远程分支
    read -p "当前分支落后于远程分支，是否拉取远程分支（y/n）:" pull_remote
    if [ "$pull_remote" == "y" ]; then
      # 执行git pull --rebase
      git pull --rebase
    fi
  fi

  # 检查是否存在冲突
  if [ -n "$(git ls-files --unmerged)" ]; then
    echo "存在冲突，请手工解决冲突并提交"
    exit 1
  else
    # 执行git push命令上传代码到远程仓库
    git push
  fi
fi





