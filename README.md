# agent-skills

个人使用的 Codex Agent Skills 集合。当前包含 `update-docs-from-diff`：根据当前分支或工作区的代码变更，按仓库规则同步项目文档。

## 支持范围

- 目前仅在 **Codex** 上验证。
- 其他 Agent 可以尝试安装，但不属于本仓库的兼容承诺。
- Skill 只修改工作区文件，不执行 `git add`、`git commit` 或其他提交操作。

## 环境要求

- Codex
- Git
- POSIX `sh`
- `rg`（ripgrep）
- Node.js / `npx`（仅用于安装和更新）

## 安装

```bash
npx skills add geeknonerd/agent-skills \
  --skill update-docs-from-diff \
  --agent codex \
  --global
```

安装后，在 Codex 中显式调用：

```text
$update-docs-from-diff
```

可选地传入 diff 范围：

```text
$update-docs-from-diff origin/main...HEAD
$update-docs-from-diff HEAD~3
```

## 更新

```bash
npx skills update update-docs-from-diff --global
```

## 卸载

```bash
npx skills remove update-docs-from-diff --agent codex --global
```

## 工作方式

1. 探测 `AGENTS.md`、显式文档规则和目录结构。
2. 从显式范围或自动探测的基线收集 diff。
3. 定位受影响的 README、主题文档、规则和索引。
4. 只更新受影响文档，并执行机械检查。
5. 输出 `Applied`、`Recommended` 和检查结果。

基线探测顺序为 `origin/HEAD`、`origin/main`、`origin/master`、本地 `main`、本地 `master`；没有可比基线时回退到工作区差异。

## 验证

```bash
./tests/check.sh
```

测试会校验 Agent Skills 格式、Shell 语法、基线探测和 `npx skills` 仓库发现。

## 目录

```text
skills/update-docs-from-diff/
├── SKILL.md
├── agents/openai.yaml
└── scripts/
    └── resolve-base.sh
```

## License

[MIT](LICENSE)
