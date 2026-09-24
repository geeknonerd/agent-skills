---
name: update-docs-from-diff
description: Update project documentation from branch diff. Use after implementing a feature, before committing, when README, docs, or AGENTS.md may be affected by code changes.
---

# Update Docs from Diff

以 git diff 为输入，按仓库自身规则更新受影响的 Markdown 文档，输出 Applied/Recommended 双段报告。只改工作区文件，绝不 `git add`/`commit`。不调用 `ce-*`/`superpowers:*`，最多在报告末尾提示"建议手动跑 /ce-compound"。

## 输入与基线

1. 显式传入 `$ARGUMENTS` → 用它当 diff 范围（如 `origin/main...HEAD`、`HEAD~3`、或逗号分隔文件列表）。
2. 没传 → 运行 `scripts/resolve-base.sh` 探测基线：依次尝试 `origin/HEAD`、`origin/main`、`origin/master`、本地 `main`、`master`，跳过与当前 HEAD 相同的基线（无远端或无差异可比时自动跳过，不报错）；脚本打印 `<base>...HEAD`。
3. 脚本打印空行 → 回退未提交变更（`git status --porcelain`）。
4. 工作区也干净 → 回退最近一次 commit（`git show --name-status`）。

无论哪条路径，最终都应执行 `git diff --name-status <range>` 或等价命令产出变更文件清单；任何一步为空都要在报告里写明"无变更可比"。

## 流程

### 0. 规则与文档层发现（不依赖任何外部配置）

按权威降序读取，**缺失即降级，不阻断**：

1. **项目指令**：已在上下文中的 `AGENTS.md`/`CLAUDE.md`——其中的文档规则优先级最高。
2. **显式规则文件**：根 `README.md`、`CONTRIBUTING.md`、`CONTEXT.md`、`docs/development.md`、ADR/规范目录（`plans/adr/`、`docs/decisions/` 等）。
3. **结构推断**：顶层目录与 `docs/` 布局、索引文件（`README.md`、`docs/README.md`、`SUMMARY.md`）、既有 frontmatter 字段、命名模式。
4. **兜底默认**：最小编辑、相对链接、单文档原地更新、索引与实际一致。

若仓库根存在 `.agents-docs-profile.md`，把它当**补充线索**读入；不存在照常运行。无法确定的归属、归档、证据要求一律写进 Recommended，不猜。

### 1. 机械采证（纯 shell，不做判断）

```bash
git diff <range> --name-status
rg -l <changed-path-stems> --glob "*.md"    # 找引用变更路径的文档
rg -n "^- \[" README.md docs/*/README.md    # 索引条目样本
git diff --check                             # 空白错误
```

输出一份原始清单：变更文件、引用它们的文档、索引条目。

### 2. 受影响文档定位

把采证结果按文档层分桶：

- 根 `README.md` 索引与状态行
- 项目/子目录 `README.md`
- `docs/` 主题文档与相对链接
- `AGENTS.md` 规则条目（如新目录需要新增放置规则）
- `CONTEXT.md` 术语（仅当出现新概念时）

桶里没有条目的层直接跳过，不要为了"看起来完整"而写空建议。

### 3. 按发现的规则更新

- **遵守该仓文档规则**（阶段 0 的发现结果）：放置/命名/归档/证据元数据/索引同步，有几条用几条。
- 没有明文规则时用兜底默认：同一主题只保留一个当前文档，迭代原地更新；被替代的移入 `archive/`（若该仓有该约定）。
- **链接**：仓库内用相对路径；引用全局配置用 `~/.codex/...`。
- **索引一致性**：README 项目索引、docs/README 的清单行必须与实际文件一一对应。

### 4. 机械检查（更新后必跑）

```bash
git diff --check
# 相对链接存在性：逐条核对 [text](path) 中 path 在仓库内存在
# 索引一致性：README/docs 索引条目 == 实际文件
# archive 归位：被替代文档确实在 archive/ 下（若该仓有此约定）
```

任一不过 → 回到阶段 3 修，不进报告。无对应约定的检查项标 `n/a`，不要写成 pass。

### 5. 报告

```markdown
## Applied
- `path/to/file.md` — 改了什么、为什么（对应哪个 diff 变更）

## Recommended
- `path/to/file.md` — 需要你判断的事项与理由

## 机械检查
- git diff --check: pass
- 链接存在性: pass | n/a
- 索引一致性: pass | n/a
- archive 归位: pass | n/a

---
建议手动跑 /ce-compound 沉淀本次学习。
```

## 边界

- 只改工作区文件，不 `git add`/`commit`
- 不接 superpowers `finishing-a-development-branch`
- 不搬 GPL-3.0 文本；`sync-docs`（无 LICENSE）只读设计
- 单 agent 顺序跑；3+ 文档大 diff 时慢，升级路径是按 `update-docs` 的分档起并行 subagent
