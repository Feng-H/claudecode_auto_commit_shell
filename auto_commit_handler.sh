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

# 获取项目上下文信息
get_project_context() {
    local context=""
    local max_context_lines=50

    # 读取 CLAUDE.md（如果存在）
    if [ -f "CLAUDE.md" ]; then
        local claude_md=$(head -n "$max_context_lines" CLAUDE.md 2>/dev/null)
        if [ -n "$claude_md" ]; then
            context="${context}## CLAUDE.md (项目指引):\n${claude_md}\n\n"
        fi
    fi

    # 读取 README.md（如果存在）
    if [ -f "README.md" ]; then
        local readme=$(head -n 30 README.md 2>/dev/null)
        if [ -n "$readme" ]; then
            context="${context}## README.md (项目说明):\n${readme}\n\n"
        fi
    fi

    # 获取项目基本信息
    local project_name=$(basename "$PWD")
    local git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local git_remote=$(git remote get-url origin 2>/dev/null || echo "无远程仓库")

    # 组装基本信息（放在文件内容之前）
    local basic_info="## 项目基本信息:\n"
    basic_info="${basic_info}- 项目名: ${project_name}\n"
    basic_info="${basic_info}- 当前分支: ${git_branch}\n"
    basic_info="${basic_info}- 远程仓库: ${git_remote}\n\n"

    context="${basic_info}${context}"

    echo -e "$context"
}

# 获取变更统计信息
get_diff_stats() {
    local stats=""

    # 获取未staged的变更文件
    local changed_files=$(git diff --name-status --no-color 2>/dev/null | head -20)
    if [ -n "$changed_files" ]; then
        stats="${stats}### 未暂存变更 (Unstaged):\n${changed_files}\n"
    fi

    # 获取staged的变更文件
    local staged_files=$(git diff --staged --name-status --no-color 2>/dev/null | head -20)
    if [ -n "$staged_files" ]; then
        stats="${stats}### 已暂存变更 (Staged):\n${staged_files}\n"
    fi

    # 获取未跟踪文件
    local untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null | head -20)
    if [ -n "$untracked_files" ]; then
        stats="${stats}### 新增文件 (Untracked):\n"
        while IFS= read -r file; do
            stats="${stats}A  ${file}\n"
        done <<< "$untracked_files"
    fi

    echo -e "$stats"
}

# 获取git diff内容
get_diff() {
    local max_lines="${1:-500}"  # 增加到500行

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
            if [ -n "$diff_content" ]; then
                diff_content="${diff_content}\n\n## Staged Changes:\n${staged_diff}"
            else
                diff_content="${staged_diff}"
            fi
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

    echo -e "$diff_content"
}

# 使用Claude API生成commit消息
generate_commit_message_claude() {
    local diff_content="$1"
    local project_context="$2"
    local diff_stats="$3"

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

    # 替换占位符
    # 注意替换顺序，先替换长内容
    local prompt="$prompt_template"
    prompt="${prompt//\{\{DIFF_CONTENT\}\}/$diff_content}"
    prompt="${prompt//\{\{DIFF_STATS\}\}/$diff_stats}"
    prompt="${prompt//\{\{PROJECT_CONTEXT\}\}/$project_context}"

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

${icon} 自动提交会话变更
EOF
}

# 清理commit消息（去除代码块包裹等格式问题）
clean_commit_message() {
    local msg="$1"

    # 去除可能存在的 ``` 代码块包裹
    # 情况1: 开头有 ```
    if [[ "$msg" =~ ^\`\`\` ]]; then
        msg=$(echo "$msg" | sed '1d' | sed '$d')
    fi

    # 情况2: 开头有 ``` 后面有语言标识
    msg=$(echo "$msg" | sed 's/^\`\`\`[a-z]*\n//')

    # 去除尾部可能残留的 ```
    msg=$(echo "$msg" | sed 's/\n\`\`\`$//')

    # 去除首尾空白行
    msg=$(echo "$msg" | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

    # 去除开头的 "```" 可能（单行情况）
    msg=$(echo "$msg" | sed 's/^[[:space:]]*\`\`\`[[:space:]]*//')

    echo "$msg"
}

# 执行git commit
do_commit() {
    local commit_msg="$1"

    # 清理消息格式
    commit_msg=$(clean_commit_message "$commit_msg")

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

    # 获取项目上下文
    log "正在收集项目上下文..."
    local project_context
    project_context=$(get_project_context)

    # 获取变更统计
    log "正在获取变更统计..."
    local diff_stats
    diff_stats=$(get_diff_stats)

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
        commit_msg=$(generate_commit_message_claude "$diff_content" "$project_context" "$diff_stats")
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
