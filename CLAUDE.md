# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Claude Code hook extension that automatically creates git commits when Claude Code sessions end. It uses the Claude API to generate intelligent, conventional commit messages in Chinese or English.

## Architecture

The system consists of four core components that work together:

1. **Hook Configuration** (`~/.claude/settings.json`) - Registers the SessionEnd hook
2. **Handler Script** (`auto_commit_handler.sh`) - Main execution logic
3. **Configuration** (`ac_config.env`) - User settings (language, API usage, diff limits)
4. **Prompt Template** (`commit_prompt_zh.txt`) - Template for Claude API to format commit messages

### Execution Flow

```
SessionEnd Hook Triggered
    ↓
auto_commit_handler.sh
    ↓
Load Config → Check Git Repo → Check Changes → Get Diff → Generate Message → Commit
```

### Key Functions in Handler Script

- `load_config()` - Sources `ac_config.env` with defaults
- `check_git_repo()` - Auto-initializes if `AUTO_INIT=true`
- `check_changes()` - Returns non-zero if nothing changed
- `get_diff()` - Collects both unstaged and staged diff (limited by `MAX_DIFF_LINES`)
- `generate_commit_message_claude()` - Calls Claude Messages API via Node.js
- `generate_commit_message_local()` - Fallback local message generation
- `do_commit()` - Executes git add/commit with security check

## Common Commands

### Installation
```bash
bash install.sh        # One-click install
```

### Uninstallation
```bash
bash uninstall.sh      # Remove all files and hooks
```

### Testing After Installation
```bash
mkdir ~/test-auto-commit && cd ~/test-auto-commit
git init
echo "test content" > test.txt
claude                  # Start Claude Code, then exit
git log -1              # Verify auto-commit worked
```

### Viewing Logs
```bash
cat ~/.claude/ac_handler.log    # Debug log (filtered for sensitive content)
```

## Configuration

All configuration lives in `~/.claude/ac_config.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `COMMIT_LANGUAGE` | `zh-CN` | Commit message language (`zh-CN` or `en`) |
| `AUTO_INIT` | `true` | Auto-run `git init` in non-git directories |
| `MAX_DIFF_LINES` | `200` | Limit diff analysis to avoid token waste |
| `USE_CLAUDE_API` | `true` | Use Claude API (falls back to local if false) |
| `API_TIMEOUT` | `30` | API timeout in seconds |

### Environment Variables

`ANTHROPIC_API_KEY` must be set for Claude API mode:
```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

## Commit Message Format

The tool generates Conventional Commits with emoji icons:

```
<type>(<scope>): <subject>

<icon> <detail bullet 1>
<icon> <detail bullet 2>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

Supported types: `feat` (✨), `fix` (🐛), `docs` (📝), `style` (💄), `refactor` (🔧), `perf` (⚡), `test` (✅), `chore` (🧹)

## Installation Files

| File | Destination | Purpose |
|------|-------------|---------|
| `ac_config.env` | `~/.claude/` | Configuration file |
| `auto_commit_handler.sh` | `~/.claude/scripts/` | Executable handler script |
| `commit_prompt_zh.txt` | `~/.claude/templates/` | Chinese prompt template |
| `install.sh` | (run once) | Automated installer |
| `uninstall.sh` | (run once) | Automated uninstaller |

## Modifying the Handler

When editing `auto_commit_handler.sh`:

1. **Preserve error handling**: The script uses `set -euo pipefail` for safety
2. **Log appropriately**: Use `log()` function, not `echo` (filters sensitive content)
3. **Maintain backwards compatibility**: Check for command existence before using
4. **Security**: The `do_commit()` function checks for `SECURITY_ALERT` in generated messages

## Adding Language Support

To add a new language (e.g., English prompts):

1. Create `commit_prompt_en.txt` with translated template
2. Add language detection in `generate_commit_message_claude()`
3. Update `COMMIT_LANGUAGE` documentation

## Debugging

If hooks don't trigger:
1. Verify hooks configuration: `cat ~/.claude/settings.json`
2. Reload hooks: Press `Cmd+Shift+H` in Claude Code → "Reload hooks"
3. Check script permissions: `ls -la ~/.claude/scripts/auto_commit_handler.sh`
4. Review logs: `cat ~/.claude/ac_handler.log`

If API calls fail:
1. Verify `ANTHROPIC_API_KEY` is set
2. Check network connectivity to `api.anthropic.com`
3. Set `USE_CLAUDE_API=false` to use local fallback
4. Increase `API_TIMEOUT` if needed

## Dependencies

- **Required**: `git`, `bash`
- **Optional**: `node` (for Claude API), `jq` (for JSON processing), `python3` (for install script)
- If `node` is missing, falls back to local message generation
