# Claude Code Auto Commit Feature

Automatically execute git commit when Claude Code session ends, using Claude API to generate standardized commit messages.

[中文文档](README.md) | English Documentation

## Features

- **Auto-trigger**: Automatically executes when Claude Code session ends
- **Smart Message Generation**: Uses Claude API to analyze code changes and generate standardized commit messages
- **Chinese/English Support**: Configurable Chinese or English commit messages
- **Auto-initialization**: Automatically runs git init in non-git repositories
- **Security Check**: Detects sensitive information to prevent accidental commits
- **Custom API Endpoint**: Supports custom Claude API addresses (proxy-compatible)
- **Flexible Configuration**: Supports multiple configuration options
- **Graceful Degradation**: Falls back to local template when API fails

---

## Quick Installation

### Method 1: One-click Installation Script (Recommended)

```bash
cd /path/to/claudecode/auto-commit
bash install.sh
```

### Method 2: Manual Installation

#### Step 1: Create Directory Structure

```bash
mkdir -p ~/.claude/scripts ~/.claude/templates
```

#### Step 2: Copy Files

```bash
# Copy configuration file
cp ac_config.env ~/.claude/

# Copy script
cp auto_commit_handler.sh ~/.claude/scripts/

# Copy prompt template
cp commit_prompt_zh.txt ~/.claude/templates/
```

#### Step 3: Set Execute Permissions

```bash
chmod +x ~/.claude/scripts/auto_commit_handler.sh
```

#### Step 4: Configure Hooks

Edit `~/.claude/settings.json` and add the following:

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

**Note**: If you already have a `settings.json`, just merge the `hooks` section while keeping your existing `env` configuration.

#### Step 5: Activate Hooks

1. Press `Cmd+Shift+H` in Claude Code to open the Hooks menu
2. Select "Reload hooks"
3. Or restart Claude Code

---

## Configuration

Edit `~/.claude/ac_config.env` to customize configuration:

```bash
# Commit message language: zh-CN (Chinese) or en (English)
COMMIT_LANGUAGE=zh-CN

# Automatically initialize if not a git repository
AUTO_INIT=true

# Maximum diff lines to analyze (avoid token waste)
MAX_DIFF_LINES=200

# Use Claude API to generate commit messages
USE_CLAUDE_API=true

# API timeout (seconds)
API_TIMEOUT=30
```

### Environment Variables

> **⚠️ Important Warning**
>
> **DO NOT** put `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL` in `~/.claude/settings.json`!
> This will cause API calls to fail. Please configure them in environment variables.

Ensure `ANTHROPIC_API_KEY` environment variable is set:

```bash
# macOS (zsh) - Add to ~/.zshrc
echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.zshrc
source ~/.zshrc

# Linux (bash) - Add to ~/.bashrc
echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

**Optional**: If using a proxy or custom API endpoint, set `ANTHROPIC_BASE_URL`:

```bash
# macOS (zsh) - For example, using Cloudflare Workers proxy
echo 'export ANTHROPIC_BASE_URL="https://your-proxy.workers.dev"' >> ~/.zshrc
source ~/.zshrc

# Linux (bash)
echo 'export ANTHROPIC_BASE_URL="https://your-proxy.workers.dev"' >> ~/.bashrc
source ~/.bashrc
```

---

## Commit Message Format

### Chinese Format (Default)

```
feat(core): 实现PDCA项目管理系统核心功能

✨ 新增Plan/Do/Check/Act四个阶段的Agent实现
✨ 实现项目状态跟踪和阶段转换机制
🔧 集成Claude API进行智能分析和决策

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### Type Icons

| Type  | Icon  | Description           |
|-------|-------|-----------------------|
| feat  | ✨    | New feature           |
| fix   | 🐛    | Bug fix               |
| docs  | 📝    | Documentation update  |
| style | 💄    | Code formatting       |
| refactor | 🔧 | Refactoring           |
| perf  | ⚡    | Performance improvement |
| test  | ✅    | Test related          |
| chore | 🧹    | Build/Tooling         |

---

## Usage

1. **Use Claude Code Normally**
   - Develop in your project with Claude Code
   - No additional operations needed

2. **Auto Commit**
   - When you exit the Claude Code session
   - The script automatically detects git status
   - If there are changes, it automatically generates a commit message and commits

3. **View Results**
   - After exiting, check git log: `git log -1`
   - Verify if auto-commit succeeded

---

## Testing

### Create Test Environment

```bash
# Create test directory
mkdir -p ~/test-auto-commit && cd ~/test-auto-commit

# Initialize git repository
git init

# Create test file
echo "test content" > test.txt

# Start Claude Code
claude
```

### Verify Auto Commit

1. Perform some operations in Claude Code
2. Exit Claude Code
3. Check if auto-commit occurred:

```bash
cd ~/test-auto-commit
git log -1
git status
```

---

## Troubleshooting

### Hooks Not Triggering

**Symptom**: No auto-commit after exiting Claude Code

**Solutions**:
1. Check hooks configuration: `cat ~/.claude/settings.json`
2. Reload hooks: Press `Cmd+Shift+H` in Claude Code, select "Reload hooks"
3. Check script permissions: `ls -la ~/.claude/scripts/auto_commit_handler.sh`
4. View logs: `cat ~/.claude/ac_handler.log`

### API Call Failed

**Symptom**: Failed to generate commit message

**Solutions**:
1. Check API Key: `echo $ANTHROPIC_API_KEY`
2. Check network connectivity
3. View logs: `cat ~/.claude/ac_handler.log`
4. Fallback: Set `USE_CLAUDE_API=false` to use local template

### Script Execution Error

**Symptom**: Shell script error

**Solutions**:
1. Check if Node.js is installed: `node --version`
2. Check if jq is installed: `jq --version`
3. Manually run script for debugging: `~/.claude/scripts/auto_commit_handler.sh`

### Commit Message Format Not as Expected

**Solutions**:
1. Edit prompt template: `~/.claude/templates/commit_prompt_zh.txt`
2. Adjust `MAX_DIFF_LINES` parameter
3. Switch to local template mode: `USE_CLAUDE_API=false`

---

## Uninstallation

```bash
# Remove hooks configuration
# Edit ~/.claude/settings.json, remove hooks section

# Remove files
rm ~/.claude/ac_config.env
rm ~/.claude/scripts/auto_commit_handler.sh
rm ~/.claude/templates/commit_prompt_zh.txt
rm ~/.claude/ac_handler.log

# Reload hooks
# Press Cmd+Shift+H in Claude Code, select "Reload hooks"
```

---

## File Structure

```
~/.claude/
├── settings.json                    # [Modified] Claude Code configuration
├── ac_config.env                    # [New] Auto commit configuration
├── scripts/
│   └── auto_commit_handler.sh      # [New] Core processing script
├── templates/
│   └── commit_prompt_zh.txt         # [New] Chinese prompt template
└── ac_handler.log                   # [Auto] Log file
```

---

## How It Works

```
Claude Code Session Ends
         ↓
SessionEnd Hook Triggered
         ↓
auto_commit_handler.sh Executes
         ↓
    ┌─────────────────────┐
    │  1. Load config      │
    │  2. Check git repo   │
    │  3. Detect changes   │
    │  4. Get diff         │
    │  5. Generate message │
    │  6. Execute commit   │
    └─────────────────────┘
```

---

## System Requirements

- **Claude Code**: Installed and working normally
- **Git**: Installed and configured
- **Node.js**: For calling Claude API (optional)
- **jq**: For JSON processing (optional)

---

## Resources

- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks)
- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Gemini CLI auto-commit](https://github.com/) - Inspiration source

---

## License

GPL-3.0 License

This project is licensed under the GNU General Public License v3.0.

---

## Contributing

Issues and Pull Requests are welcome!

---

## Changelog

### v1.1.0 (2025-12-23)
- ✨ Added support for custom API Endpoint (`ANTHROPIC_BASE_URL`)
- ✨ Compatible with proxy services (e.g., Cloudflare Workers)
- 🔧 Improved API call error handling
- 📝 Updated documentation

### v1.0.0 (2024-12-23)
- Initial version
- Support for Claude API to generate commit messages
- Support for Chinese and English
- Support for automatic git repository initialization
- Support for sensitive information detection
