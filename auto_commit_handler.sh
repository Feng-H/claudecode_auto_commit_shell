#!/bin/bash
# Claude Code Auto Commit Handler
# 在Claude Code会话结束时自动执行git commit

set -euo pipefail
set +H  # 禁用历史扩展，避免JavaScript中的!被bash解释

# 配置文件路径
CONFIG_FILE="$HOME/.claude/ac_config.env"
PROMPT_TEMPLATE_ZH="$HOME/.claude/templates/commit_prompt_zh.txt"

# 日志文件（可选，用于调试）
LOG_FILE="$HOME/.claude/ac_handler.log"

# 日志函数（不记录敏感内容）
log() {
    local message="$*"
    # 过滤掉可能包含敏感信息的内容
    echo "$message" | grep -vE "(password|secret|key|token|api_key|diff_content)" >> "$LOG_FILE" 2>/dev/null || true
}

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # 默认配置
        COMMIT_LANGUAGE="${COMMIT_LANGUAGE:-zh-CN}"
        AUTO_INIT="${AUTO_INIT:-true}"
        MAX_DIFF_LINES="${MAX_DIFF_LINES:-200}"
        USE_CLAUDE_API="${USE_CLAUDE_API:-true}"
        API_TIMEOUT="${API_TIMEOUT:-30}"
    fi
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log "错误: 命令 $1 未找到"
        return 1
    fi
}

# 检查并初始化git仓库
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log "当前目录不是git仓库: $PWD"

        if [ "$AUTO_INIT" = "true" ]; then
            log "正在初始化git仓库..."
            git init
            log "Git仓库初始化完成"

            # 设置默认分支名（如果git版本支持）
            if git config --global init.defaultBranch &>/dev/null; then
                DEFAULT_BRANCH=$(git config --global init.defaultBranch)
                git checkout -b "$DEFAULT_BRANCH" 2>/dev/null || true
            fi
        else
            log "AUTO_INIT=false，跳过初始化"
            return 1
        fi
    fi

    return 0
}

# 检查是否有变更
check_changes() {
    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
        log "没有检测到变更，跳过commit"
        return 1
    fi
    return 0
}

# 获取git diff内容
get_diff() {
    local max_lines="${1:-200}"

    # 先获取所有变更的文件
    local changed_files
    changed_files=$(git diff --name-only --diff-filter=ACMR 2>/dev/null | head -20)
    local changed_files_staged
    changed_files_staged=$(git diff --name-only --staged --diff-filter=ACMR 2>/dev/null | head -20)

    # 获取diff内容，限制行数
    local diff_content=""
    if [ -n "$changed_files" ]; then
        diff_content=$(git diff --unified=3 --no-color 2>/dev/null | head -n "$max_lines")
    fi

    # 同时获取staged的diff
    if [ -n "$changed_files_staged" ]; then
        local staged_diff
        staged_diff=$(git diff --staged --unified=3 --no-color 2>/dev/null | head -n "$max_lines")
        if [ -n "$staged_diff" ]; then
            diff_content="${diff_content}${staged_diff}"
        fi
    fi

    # 如果没有常规diff，检查是否有未跟踪的文件（新仓库场景）
    if [ -z "$diff_content" ]; then
        local untracked_files
        untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null | head -20)
        if [ -n "$untracked_files" ]; then
            diff_content="# 新增文件 (未跟踪):\n"
            while IFS= read -r file; do
                diff_content="${diff_content}+ ${file}\n"
            done <<< "$untracked_files"
        fi
    fi

    echo "$diff_content"
}

# 使用Claude API生成commit消息
generate_commit_message_claude() {
    local diff_content="$1"

    # 检查是否安装了node
    if ! check_command node; then
        log "错误: 未找到node命令，无法调用Claude API"
        return 1
    fi

    # 读取提示词模板
    local prompt_template
    if [ -f "$PROMPT_TEMPLATE_ZH" ]; then
        prompt_template=$(cat "$PROMPT_TEMPLATE_ZH")
    else
        # 备用提示词
        prompt_template="请根据以下git diff生成一条commit消息。格式: <type>: <subject>\n\n- <detail1>\n\n${diff_content}"
    fi

    # 替换{{DIFF_CONTENT}}占位符
    local prompt
    prompt="${prompt_template//\{\{DIFF_CONTENT\}\}/$(echo "$diff_content" | sed 's/"/\\"/g' | tr '\n' '\\n')}"

    # 检查API Key
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        log "警告: 未设置ANTHROPIC_API_KEY环境变量"
    fi

    # 默认 Base URL
    local base_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
    log "使用 API endpoint: $base_url"

    # 从 URL 中提取 hostname 和 port
    local api_host
    local api_port
    if [[ "$base_url" =~ ^https?://([^/:]+)(:([0-9]+))? ]]; then
        api_host="${BASH_REMATCH[1]}"
        api_port="${BASH_REMATCH[3]:-443}"
    else
        api_host="api.anthropic.com"
        api_port="443"
    fi

    # 使用Node.js调用Claude API
    local commit_msg
    commit_msg=$(ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" ANTHROPIC_BASE_URL="$base_url" node -e "
        const https = require('https');
        const url = require('url');

        const apiKey = process.env.ANTHROPIC_API_KEY || '';
        const baseUrl = process.env.ANTHROPIC_BASE_URL || 'https://api.anthropic.com';
        const prompt = $(echo "$prompt" | jq -Rs .);

        if (!apiKey) {
            console.error('SECURITY_ALERT: 未找到ANTHROPIC_API_KEY');
            process.exit(1);
        }

        // 解析 URL - 如果 base_url 已包含路径，则使用完整路径
        const parsedUrl = url.parse(baseUrl);
        const isHttps = parsedUrl.protocol === 'https:';
        const httpModule = isHttps ? https : require('http');

        // 处理路径：如果 base_url 已包含 /v1/messages 或类似路径，则使用它
        let apiPath = '/v1/messages';
        if (parsedUrl.pathname && parsedUrl.pathname !== '/') {
            // base_url 已包含路径，拼接完整路径
            apiPath = parsedUrl.pathname + (parsedUrl.pathname.endsWith('/') ? 'v1/messages' : '/v1/messages');
        }

        const data = JSON.stringify({
            model: 'claude-sonnet-4-5-20250929',
            max_tokens: 1024,
            messages: [{
                role: 'user',
                content: prompt
            }]
        });

        const options = {
            hostname: parsedUrl.hostname || 'api.anthropic.com',
            port: parsedUrl.port || (isHttps ? 443 : 80),
            path: apiPath,
            method: 'POST',
            headers: {
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
                'dangerously-direct-browser-access': 'false'
            }
        };

        // 使用Promise包装异步请求
        const makeRequest = () => {
            return new Promise((resolve, reject) => {
                const req = httpModule.request(options, (res) => {
                    let responseData = '';
                    res.on('data', (chunk) => {
                        responseData += chunk;
                    });
                    res.on('end', () => {
                        try {
                            const parsed = JSON.parse(responseData);
                            if (parsed.error) {
                                reject(new Error('API Error: ' + parsed.error.message));
                            } else if (parsed.content && parsed.content[0] && parsed.content[0].text) {
                                resolve(parsed.content[0].text.trim());
                            } else {
                                reject(new Error('No content in response'));
                            }
                        } catch (e) {
                            // 在解析错误时包含原始响应的前200字符用于调试
                            reject(new Error('Error parsing response: ' + e.message + '. Response: ' + responseData.substring(0, 200)));
                        }
                    });
                });

                req.on('error', (error) => {
                    reject(new Error('API Error: ' + error.message));
                });

                req.setTimeout(${API_TIMEOUT:-30}000, () => {
                    req.destroy();
                    reject(new Error('Request timeout'));
                });

                req.write(data);
                req.end();
            });
        };

        // 使用async/await等待响应
        (async () => {
            try {
                const result = await makeRequest();
                console.log(result);
            } catch (error) {
                console.error('Error:', error.message);
                process.exit(1);
            }
        })();
    " 2>&1)

    if [ $? -eq 0 ] && [ -n "$commit_msg" ]; then
        echo "$commit_msg"
        return 0
    else
        log "Claude API调用失败"
        return 1
    fi
}

# 生成本地commit消息（备用方案）
generate_commit_message_local() {
    local diff_content="$1"

    # 简单分析diff内容
    local added=$(echo "$diff_content" | grep -c "^+" || true)
    local deleted=$(echo "$diff_content" | grep -c "^-" || true)

    # 获取变更的文件列表
    local files
    files=$(git diff --name-only 2>/dev/null | head -5)

    # 确定类型
    local type="chore"
    local icon="🧹"
    if echo "$files" | grep -qE "\.(md|txt)$"; then
        type="docs"
        icon="📝"
    elif echo "$files" | grep -qE "test|spec"; then
        type="test"
        icon="✅"
    elif [ "$added" -gt "$deleted" ]; then
        type="feat"
        icon="✨"
    fi

    # 生成commit消息
    cat <<EOF
${type}(*): 自动保存工作进度 $(date '+%Y-%m-%d %H:%M')

${icon} 自动提交 Claude Code 会话变更

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
}

# 执行git commit
do_commit() {
    local commit_msg="$1"

    # 检查是否有敏感信息警告
    if [[ "$commit_msg" == *"SECURITY_ALERT"* ]]; then
        log "警告: 检测到敏感信息，取消commit"
        echo "🚨 安全警告: 检测到可能的敏感信息，已取消自动commit"
        git reset 2>/dev/null || true
        return 1
    fi

    # 执行git add和commit
    git add . 2>/dev/null || true

    if git commit -m "$commit_msg" 2>/dev/null; then
        log "Commit成功"
        echo "✅ 自动commit成功"
        echo "$commit_msg" | head -n 10
        return 0
    else
        log "Commit失败"
        echo "❌ 自动commit失败"
        return 1
    fi
}

# 主函数
main() {
    log "=== Auto Commit Handler 开始 ==="
    log "当前目录: $PWD"

    # 加载配置
    load_config

    # 检查git仓库
    if ! check_git_repo; then
        return 0
    fi

    # 检查是否有变更
    if ! check_changes; then
        return 0
    fi

    # 获取diff内容
    log "正在获取git diff..."
    local diff_content
    diff_content=$(get_diff "$MAX_DIFF_LINES")

    if [ -z "$diff_content" ]; then
        log "没有获取到diff内容"
        return 0
    fi

    log "Diff内容 (前100字符): ${diff_content:0:100}..."

    # 生成commit消息
    log "正在生成commit消息..."
    local commit_msg=""

    if [ "$USE_CLAUDE_API" = "true" ]; then
        # 优先使用Claude API
        commit_msg=$(generate_commit_message_claude "$diff_content")
    fi

    # 备用方案
    if [ -z "$commit_msg" ]; then
        log "使用本地模板生成commit消息"
        commit_msg=$(generate_commit_message_local "$diff_content")
    fi

    # 执行commit
    if [ -n "$commit_msg" ]; then
        do_commit "$commit_msg"
    fi

    log "=== Auto Commit Handler 结束 ==="
}

# 执行主函数
main
