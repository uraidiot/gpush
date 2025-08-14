# 自定义最大重试次数
MAX_RETRY=5

# 自定义保护分支
PROTECTED_BRANCHES=(main master develop release/*)

# 自定义提交类型
COMMIT_TYPES=(
    "Feature: 新功能"
    "Fix: BUG修复"
    "Improve: 性能优化"
    "Docs: 文档更新"
    "Style: 代码格式"
)