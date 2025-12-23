# 快速开始

## 一键安装

```bash
cd auto-commit
bash install.sh
```

## 激活 Hooks

在 Claude Code 中按 `Cmd+Shift+H`，选择 "Reload hooks"

## 完成！

现在退出 Claude Code 会话时，会自动执行 git commit

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `install.sh` | 一键安装脚本 |
| `uninstall.sh` | 卸载脚本 |
| `ac_config.env` | 配置文件 |
| `auto_commit_handler.sh` | 核心处理脚本 |
| `commit_prompt_zh.txt` | 提示词模板 |
| `README.md` | 完整文档 |

---

## 手动安装

如果一键安装脚本无法使用，请参考 [README.md](README.md) 中的手动安装步骤。

---

## 配置 API Key

设置 `ANTHROPIC_API_KEY` 环境变量：

```bash
export ANTHROPIC_API_KEY="your-api-key-here"

# 添加到 ~/.zshrc 永久生效
echo 'export ANTHROPIC_API_KEY="your-api-key"' >> ~/.zshrc
```

---

## 测试

```bash
mkdir ~/test-auto-commit && cd ~/test-auto-commit
echo "test" > test.txt
claude  # 启动 Claude Code，然后退出
git log -1  # 查看自动提交结果
```
