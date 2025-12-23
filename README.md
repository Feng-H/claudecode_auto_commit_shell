# Claude Code 自动Commit 功能

Claude Code 会话结束时自动执行 git commit 的功能，使用 Claude API 生成规范的中文 commit 消息。

[English Documentation](README_EN.md) | 中文文档

## 功能特性

- ✅ **自动触发**：Claude Code 会话结束时自动执行
- ✅ **智能生成消息**：使用 Claude API 分析代码变化，生成规范的 commit 消息
- ✅ **中文/英文支持**：可配置中文或英文 commit 消息
- ✅ **自动初始化**：非 git 项目自动执行 git init
- ✅ **安全检查**：检测敏感信息，防止意外提交
- ✅ **自定义 API Endpoint**：支持自定义 Claude API 地址（兼容代理）
- ✅ **配置灵活**：支持多种配置选项
- ✅ **优雅降级**：API 失败时自动使用本地模板生成消息

---

## 快速安装

### 方法一：一键安装脚本（推荐）

```bash
cd /path/to/claudecode/auto-commit
bash install.sh
```

### 方法二：手动安装

#### 步骤1：创建目录结构

```bash
mkdir -p ~/.claude/scripts ~/.claude/templates
```

#### 步骤2：复制文件

```bash
# 复制配置文件
cp ac_config.env ~/.claude/

# 复制脚本
cp auto_commit_handler.sh ~/.claude/scripts/

# 复制提示词模板
cp commit_prompt_zh.txt ~/.claude/templates/
```

#### 步骤3：设置执行权限

```bash
chmod +x ~/.claude/scripts/auto_commit_handler.sh
```

#### 步骤4：配置 Hooks

编辑 `~/.claude/settings.json`，添加以下内容：

```json
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
```

**注意**：如果已有 `settings.json`，只需合并 `hooks` 部分，保留原有的 `env` 配置。

#### 步骤5：激活 Hooks

1. 在 Claude Code 中按 `Cmd+Shift+H` 打开 Hooks 菜单
2. 选择 "Reload hooks"
3. 或者重启 Claude Code

---

## 配置说明

编辑 `~/.claude/ac_config.env` 自定义配置：

```bash
# Commit消息语言: zh-CN (中文) 或 en (英文)
COMMIT_LANGUAGE=zh-CN

# 如果不是git仓库，是否自动初始化
AUTO_INIT=true

# 最大分析diff行数（避免token浪费）
MAX_DIFF_LINES=200

# 使用Claude API生成commit消息
USE_CLAUDE_API=true

# API超时时间（秒）
API_TIMEOUT=30
```

### 环境变量

> **⚠️ 重要提醒**
>
> **不要**将 `ANTHROPIC_API_KEY` 和 `ANTHROPIC_BASE_URL` 放入 `~/.claude/settings.json` 中！
> 这样会导致 API 调用失败。请将它们配置在环境变量中。

确保设置 `ANTHROPIC_API_KEY` 环境变量：

```bash
# macOS (zsh) - 添加到 ~/.zshrc
echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.zshrc
source ~/.zshrc

# Linux (bash) - 添加到 ~/.bashrc
echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

**可选**：如果使用代理或自定义 API endpoint，设置 `ANTHROPIC_BASE_URL`：

```bash
# macOS (zsh) - 例如使用 Cloudflare Workers 代理
echo 'export ANTHROPIC_BASE_URL="https://your-proxy.workers.dev"' >> ~/.zshrc
source ~/.zshrc

# Linux (bash)
echo 'export ANTHROPIC_BASE_URL="https://your-proxy.workers.dev"' >> ~/.bashrc
source ~/.bashrc
```

---

## Commit 消息格式

### 中文格式（默认）

```
feat(core): 实现PDCA项目管理系统核心功能

✨ 新增Plan/Do/Check/Act四个阶段的Agent实现
✨ 实现项目状态跟踪和阶段转换机制
🔧 集成Claude API进行智能分析和决策

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### 类型图标

| Type | 图标 | 说明 |
|------|------|------|
| feat | ✨ | 新功能 |
| fix | 🐛 | Bug修复 |
| docs | 📝 | 文档更新 |
| style | 💄 | 代码格式 |
| refactor | 🔧 | 重构 |
| perf | ⚡ | 性能优化 |
| test | ✅ | 测试相关 |
| chore | 🧹 | 构建/工具 |

---

## 使用方法

1. **正常使用 Claude Code**
   - 在项目中使用 Claude Code 进行开发
   - 不需要任何额外操作

2. **自动提交**
   - 当您退出 Claude Code 会话时
   - 脚本自动检测 git 状态
   - 如有变更，自动生成 commit 消息并提交

3. **查看结果**
   - 退出后查看 git log: `git log -1`
   - 查看是否成功自动提交

---

## 测试

### 创建测试环境

```bash
# 创建测试目录
mkdir -p ~/test-auto-commit && cd ~/test-auto-commit

# 初始化git仓库
git init

# 创建测试文件
echo "test content" > test.txt

# 启动 Claude Code
claude
```

### 验证自动提交

1. 在 Claude Code 中进行一些操作
2. 退出 Claude Code
3. 检查是否自动提交：

```bash
cd ~/test-auto-commit
git log -1
git status
```

---

## 故障排除

### Hooks 没有触发

**症状**：退出 Claude Code 后没有自动提交

**解决方案**：
1. 检查 hooks 配置：`cat ~/.claude/settings.json`
2. 重新加载 hooks：在 Claude Code 中按 `Cmd+Shift+H`，选择 "Reload hooks"
3. 检查脚本权限：`ls -la ~/.claude/scripts/auto_commit_handler.sh`
4. 查看日志：`cat ~/.claude/ac_handler.log`

### API 调用失败

**症状**：生成 commit 消息失败

**解决方案**：
1. 检查 API Key：`echo $ANTHROPIC_API_KEY`
2. 检查网络连接
3. 查看日志：`cat ~/.claude/ac_handler.log`
4. 备用方案：设置 `USE_CLAUDE_API=false` 使用本地模板

### 脚本执行错误

**症状**：shell 脚本报错

**解决方案**：
1. 检查 Node.js 是否安装：`node --version`
2. 检查 jq 是否安装：`jq --version`
3. 手动运行脚本调试：`~/.claude/scripts/auto_commit_handler.sh`

### Commit 消息格式不符合预期

**解决方案**：
1. 编辑提示词模板：`~/.claude/templates/commit_prompt_zh.txt`
2. 调整 `MAX_DIFF_LINES` 参数
3. 切换到本地模板模式：`USE_CLAUDE_API=false`

---

## 卸载

```bash
# 删除 hooks 配置
# 编辑 ~/.claude/settings.json，删除 hooks 部分

# 删除文件
rm ~/.claude/ac_config.env
rm ~/.claude/scripts/auto_commit_handler.sh
rm ~/.claude/templates/commit_prompt_zh.txt
rm ~/.claude/ac_handler.log

# 重新加载 hooks
# 在 Claude Code 中按 Cmd+Shift+H，选择 "Reload hooks"
```

---

## 文件结构

```
~/.claude/
├── settings.json                    # [修改] Claude Code 配置
├── ac_config.env                    # [新建] 自动commit配置
├── scripts/
│   └── auto_commit_handler.sh      # [新建] 核心处理脚本
├── templates/
│   └── commit_prompt_zh.txt         # [新建] 中文提示词模板
└── ac_handler.log                   # [自动] 日志文件
```

---

## 工作原理

```
Claude Code 会话结束
         ↓
SessionEnd Hook 触发
         ↓
auto_commit_handler.sh 执行
         ↓
    ┌─────────────────────┐
    │  1. 加载配置         │
    │  2. 检查git仓库      │
    │  3. 检测变更         │
    │  4. 获取diff         │
    │  5. 生成commit消息   │
    │  6. 执行git commit   │
    └─────────────────────┘
```

---

## 系统要求

- **Claude Code**: 已安装并正常使用
- **Git**: 已安装并配置
- **Node.js**: 用于调用 Claude API（可选）
- **jq**: 用于 JSON 处理（可选）

---

## 参考资源

- [Claude Code Hooks 文档](https://code.claude.com/docs/en/hooks)
- [Conventional Commits 规范](https://www.conventionalcommits.org/)
- [Gemini CLI auto-commit](https://github.com/) - 灵感来源

---

## 许可证

GPL-3.0 License

本项目采用 GNU General Public License v3.0 开源协议。

---

## 贡献

欢迎提交 Issue 和 Pull Request！

---

## 更新日志

### v1.1.0 (2025-12-23)
- ✨ 新增支持自定义 API Endpoint (`ANTHROPIC_BASE_URL`)
- ✨ 兼容代理服务（如 Cloudflare Workers）
- 🔧 优化 API 调用错误处理
- 📝 更新文档说明

### v1.0.0 (2024-12-23)
- 初始版本
- 支持 Claude API 生成 commit 消息
- 支持中文和英文
- 支持自动初始化 git 仓库
- 支持敏感信息检测
