#!/bin/bash
# Claude Code Auto Commit 功能卸载脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 确认卸载
confirm_uninstall() {
    echo "=========================================="
    echo " Claude Code Auto Commit 卸载向导"
    echo "=========================================="
    echo ""
    echo "此操作将删除以下文件:"
    echo "  - ~/.claude/ac_config.env"
    echo "  - ~/.claude/scripts/auto_commit_handler.sh"
    echo "  - ~/.claude/templates/commit_prompt_zh.txt"
    echo "  - ~/.claude/ac_handler.log"
    echo ""
    echo "并且将从 ~/.claude/settings.json 中移除 hooks 配置"
    echo ""
    read -p "确认卸载? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "取消卸载"
        exit 0
    fi
}

# 删除文件
remove_files() {
    print_info "删除文件..."

    [ -f ~/.claude/ac_config.env ] && rm ~/.claude/ac_config.env && print_info "已删除 ac_config.env"
    [ -f ~/.claude/scripts/auto_commit_handler.sh ] && rm ~/.claude/scripts/auto_commit_handler.sh && print_info "已删除 auto_commit_handler.sh"
    [ -f ~/.claude/templates/commit_prompt_zh.txt ] && rm ~/.claude/templates/commit_prompt_zh.txt && print_info "已删除 commit_prompt_zh.txt"
    [ -f ~/.claude/ac_handler.log ] && rm ~/.claude/ac_handler.log && print_info "已删除 ac_handler.log"

    # 清空目录
    [ -d ~/.claude/scripts ] && [ -z "$(ls -A ~/.claude/scripts 2>/dev/null)" ] && rmdir ~/.claude/scripts 2>/dev/null && print_info "已删除空目录 scripts"
    [ -d ~/.claude/templates ] && [ -z "$(ls -A ~/.claude/templates 2>/dev/null)" ] && rmdir ~/.claude/templates 2>/dev/null && print_info "已删除空目录 templates"

    print_info "文件删除完成 ✓"
}

# 清理 .gitignore 配置
clean_gitignore() {
    print_info "清理 .gitignore 配置..."

    local global_gitignore="$HOME/.gitignore_global"

    if [ ! -f "$global_gitignore" ]; then
        print_info ".gitignore_global 不存在，跳过"
        return
    fi

    # 检查是否配置了日志忽略
    if ! grep -q "ac_handler.log" "$global_gitignore" 2>/dev/null; then
        print_info ".gitignore_global 中未找到日志配置，跳过"
        return
    fi

    # 删除相关配置行
    local temp_file="$global_gitignore.tmp"
    grep -v -E "^# Claude Code Auto Commit 日志|^\.claude/ac_handler\.log$" "$global_gitignore" > "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$global_gitignore"
    print_info "已从 .gitignore_global 移除日志配置"

    # 如果文件为空，删除它
    if [ ! -s "$global_gitignore" ]; then
        rm "$global_gitignore"
        print_info "已删除空的 .gitignore_global"
    fi
}

# 移除 hooks 配置
remove_hooks() {
    print_info "移除 hooks 配置..."

    local settings_file="$HOME/.claude/settings.json"

    if [ ! -f "$settings_file" ]; then
        print_warn "settings.json 不存在，跳过"
        return
    fi

    # 检查是否配置了 hooks
    if ! grep -q '"SessionEnd"' "$settings_file" 2>/dev/null; then
        print_warn "未找到 SessionEnd hooks 配置，跳过"
        return
    fi

    # 使用 Python 移除 hooks
    if command -v python3 &> /dev/null; then
        print_info "使用 Python 更新 settings.json..."
        python3 << PYTHON_SCRIPT
import json

# 读取现有配置
with open('$settings_file', 'r') as f:
    try:
        config = json.load(f)
    except json.JSONDecodeError:
        print('Error: Invalid JSON in settings.json')
        exit(1)

# 移除 hooks
if 'hooks' in config:
    del config['hooks']
    print('✓ 已移除 hooks 配置')

# 写回文件
with open('$settings_file', 'w') as f:
    json.dump(config, f, indent=4, ensure_ascii=False)

print('✓ settings.json 更新完成')
PYTHON_SCRIPT
    else
        print_warn "未找到 Python3，请手动编辑 ~/.claude/settings.json"
        print_warn "删除 'hooks' 部分"
    fi
}

# 显示卸载完成信息
show_completion() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}卸载完成！${NC}"
    echo "=========================================="
    echo ""
    echo "下一步操作:"
    echo "  1. 重新加载 Hooks:"
    echo "     - 在 Claude Code 中按 Cmd+Shift+H"
    echo "     - 选择 'Reload hooks'"
    echo ""
    echo "  2. 或重启 Claude Code"
    echo ""
    echo "感谢使用 Claude Code Auto Commit!"
    echo ""
}

# 主函数
main() {
    confirm_uninstall
    echo ""
    remove_files
    echo ""
    clean_gitignore
    echo ""
    remove_hooks
    echo ""
    show_completion
}

# 执行主函数
main
