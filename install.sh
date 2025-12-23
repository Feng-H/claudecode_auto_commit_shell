#!/bin/bash
# Claude Code Auto Commit 功能一键安装脚本

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

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查文件是否存在
check_files() {
    print_info "检查安装文件..."

    local missing_files=()

    [ ! -f "$SCRIPT_DIR/ac_config.env" ] && missing_files+=("ac_config.env")
    [ ! -f "$SCRIPT_DIR/auto_commit_handler.sh" ] && missing_files+=("auto_commit_handler.sh")
    [ ! -f "$SCRIPT_DIR/commit_prompt_zh.txt" ] && missing_files+=("commit_prompt_zh.txt")

    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "缺少以下文件:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi

    print_info "所有安装文件检查通过 ✓"
}

# 创建目录结构
create_directories() {
    print_info "创建目录结构..."

    mkdir -p ~/.claude/scripts
    mkdir -p ~/.claude/templates

    print_info "目录创建完成 ✓"
}

# 复制文件
copy_files() {
    print_info "复制文件..."

    # 复制配置文件
    if [ -f ~/.claude/ac_config.env ]; then
        print_warn "ac_config.env 已存在，跳过"
    else
        cp "$SCRIPT_DIR/ac_config.env" ~/.claude/
        print_info "已复制 ac_config.env"
    fi

    # 复制脚本
    cp "$SCRIPT_DIR/auto_commit_handler.sh" ~/.claude/scripts/
    print_info "已复制 auto_commit_handler.sh"

    # 复制提示词模板
    cp "$SCRIPT_DIR/commit_prompt_zh.txt" ~/.claude/templates/
    print_info "已复制 commit_prompt_zh.txt"
}

# 设置执行权限
set_permissions() {
    print_info "设置执行权限..."

    chmod +x ~/.claude/scripts/auto_commit_handler.sh

    print_info "权限设置完成 ✓"
}

# 配置 git 忽略日志文件
configure_gitignore() {
    print_info "配置 .gitignore..."

    # 在用户主目录添加全局 gitignore（如果不存在）
    local global_gitignore="$HOME/.gitignore_global"

    if [ ! -f "$global_gitignore" ]; then
        touch "$global_gitignore"
        print_info "已创建 .gitignore_global"
    fi

    # 检查是否已配置
    if ! grep -q "ac_handler.log" "$global_gitignore" 2>/dev/null; then
        echo "" >> "$global_gitignore"
        echo "# Claude Code Auto Commit 日志" >> "$global_gitignore"
        echo ".claude/ac_handler.log" >> "$global_gitignore"
        print_info "已添加日志文件到 .gitignore_global"

        # 提示用户配置全局 gitignore
        if ! git config --global core.excludesfile &>/dev/null; then
            print_warn "建议运行以下命令启用全局 .gitignore:"
            echo "     git config --global core.excludesfile ~/.gitignore_global"
        fi
    else
        print_info ".gitignore_global 已配置，跳过"
    fi
}

# 配置 hooks
configure_hooks() {
    print_info "配置 hooks..."

    local settings_file="$HOME/.claude/settings.json"
    local hooks_file="$HOME/.claude/settings.json.tmp"

    # 如果 settings.json 不存在，创建新的
    if [ ! -f "$settings_file" ]; then
        print_info "创建新的 settings.json..."
        cat > "$settings_file" << 'EOF'
{
    "hooks": {
        "SessionEnd": [
            {
                "matcher": "*",
                "hooks": [
                    {
                        "type": "command",
                        "command": "~/.claude/scripts/auto_commit_handler.sh",
                        "timeout": 30
                    }
                ]
            }
        ]
    }
}
EOF
        print_info "settings.json 创建完成 ✓"
        return
    fi

    # 检查是否已配置 hooks
    if grep -q '"SessionEnd"' "$settings_file" 2>/dev/null; then
        print_warn "SessionEnd hooks 已配置，跳过"
        return
    fi

    # 使用 Python 添加 hooks（处理 JSON 格式）
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

# 添加 hooks
config['hooks'] = {
    'SessionEnd': [
        {
            'matcher': '*',
            'hooks': [
                {
                    'type': 'command',
                    'command': '~/.claude/scripts/auto_commit_handler.sh',
                    'timeout': 30
                }
            ]
        }
    ]
}

# 写回文件
with open('$settings_file', 'w') as f:
    json.dump(config, f, indent=4, ensure_ascii=False)

print('✓ settings.json 更新完成')
PYTHON_SCRIPT
    else
        print_warn "未找到 Python3，请手动配置 hooks"
        print_warn "请在 ~/.claude/settings.json 中添加以下内容:"
        cat << 'EOF'

{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/scripts/auto_commit_handler.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
EOF
    fi
}

# 检查环境变量
check_env() {
    print_info "检查环境配置..."

    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        print_warn "未设置 ANTHROPIC_API_KEY 环境变量"
        echo ""
        echo "请设置您的 API Key:"
        echo "  export ANTHROPIC_API_KEY=\"your-api-key-here\""
        echo ""
        echo "建议添加到 ~/.zshrc 或 ~/.bashrc:"
        echo "  echo 'export ANTHROPIC_API_KEY=\"your-api-key\"' >> ~/.zshrc"
    else
        print_info "ANTHROPIC_API_KEY 已设置 ✓"
    fi
}

# 显示安装完成信息
show_completion() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}安装完成！${NC}"
    echo "=========================================="
    echo ""
    echo "下一步操作:"
    echo "  1. 重新加载 Hooks:"
    echo "     - 在 Claude Code 中按 Cmd+Shift+H"
    echo "     - 选择 'Reload hooks'"
    echo ""
    echo "  2. 或重启 Claude Code"
    echo ""
    echo "配置文件位置:"
    echo "  - 配置: ~/.claude/ac_config.env"
    echo "  - 脚本: ~/.claude/scripts/auto_commit_handler.sh"
    echo "  - 模板: ~/.claude/templates/commit_prompt_zh.txt"
    echo ""
    echo "查看日志:"
    echo "  cat ~/.claude/ac_handler.log"
    echo ""
    echo "详细文档: $SCRIPT_DIR/README.md"
    echo ""
}

# 主函数
main() {
    echo "=========================================="
    echo " Claude Code Auto Commit 安装向导"
    echo "=========================================="
    echo ""

    echo "此安装将会："
    echo "  1. 创建 ~/.claude/ 目录下的配置和脚本文件"
    echo "  2. 修改 ~/.claude/settings.json 添加 hooks 配置"
    echo "  3. 不会修改任何系统文件或用户数据"
    echo ""
    read -p "继续安装? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "取消安装"
        exit 0
    fi
    echo ""

    check_files
    echo ""
    create_directories
    echo ""
    copy_files
    echo ""
    set_permissions
    echo ""
    configure_gitignore
    echo ""
    configure_hooks
    echo ""
    check_env
    echo ""
    show_completion
}

# 执行主函数
main
