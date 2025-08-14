#!/bin/bash

# 加载配置文件 - 与autopush_optimized.sh相同的逻辑
# 首先尝试加载工作区中的config.sh
WORKSPACE_CONFIG="$(dirname "$0")/config.sh"
[ -f "$WORKSPACE_CONFIG" ] && source "$WORKSPACE_CONFIG"

# 然后尝试加载用户主目录下的配置文件
USER_CONFIG="$HOME/.gpush/config.sh"
[ -f "$USER_CONFIG" ] && source "$USER_CONFIG"

# 测试COMMIT_TYPES是否正确加载
if [ -z "$COMMIT_TYPES" ]; then
    echo "COMMIT_TYPES未加载成功"
else
    echo "COMMIT_TYPES加载成功，包含以下类型："
    for i in "${!COMMIT_TYPES[@]}"; do
        echo "  $((i+1))) ${COMMIT_TYPES[$i]}"
    done
fi