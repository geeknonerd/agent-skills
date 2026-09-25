---
name: update-docs-from-diff
description: Update project documentation from the branch diff and the current conversation context. Use after implementing or discussing a change, before committing, when README, docs, or AGENTS.md may be affected.
---

# Update Docs from Diff

以 git diff 和当前会话上下文为输入，按仓库自身规则更新受影响的 Markdown 文档，输出 Applied/Recommended 双段报告。只改工作区文件，绝不 `git add`/`commit`。不调用 `ce-*`/`superpowers:*`，最多在报告末尾提示"建议手动跑 /ce-compound"。

## 输入与基线

### diff 范围

1. 显式传入 `$ARGUMENTS` 且是范围或文件列表 → 用它当 diff 范围（如 `origin/main...HEAD`、`HEAD~3`、逗号分隔文件路径）。
2. `$ARGUMENTS` 是自然语言意图（如"根据上下文和当前修改，更新相关文档"）→ 不当作路径，按默认基线执行。
3. 没传 → 运行 `scripts/resolve-base.sh` 探测基线：依次尝试 `origin/HEAD`、`origin/main`、`origin/master`、本地 `main`、`master`，跳过与当前 HEAD 相同的基线（无远端或无差异可比时自动跳过，不报错）；脚本打印 `<base>...HEAD`。
4. 脚本打印空行 → 回退未提交变更（`git status --porcelain`）。
5. 工作区也干净 → 回退最近一次 commit（`git show --name-status`）。

无论哪条路径，最终都应执行 `git diff --name-status <range>` 或等价命令产出变更文件清单；任何一步为空都要在报告里写明"无变更可比"，并转入"无 diff 模式"。

### 会话上下文

- **范围**：本次会话中用户的决定、偏好、纠正，以及用户明确采纳的外部资料。你自己的探索、未被用户确认的推理不算输入。
- **窗口**：自上次文档同步点以来；定位不到就覆盖整段会话，并在报告里写明实际窗口。
- **压缩后**：只依据当前可见内容；已被压缩、无法确认的部分写进 Recommended，不猜。
- **角色**：会话上下文是意图与决策来源，不是事实来源。代码行为、接口、数据、数字仍必须由 diff、代码或文件核验。

## 流程

### 0. 规则与文档层发现（不依赖任何外部配置）

按权威降序读取，**缺失即降级，不阻断**：

1. **项目指令**：已在上下文中的 `AGENTS.md`/`CLAUDE.md`——其中的文档规则优先级最高，即本次会话的权威副本。
2. **显式规则文件**：根 `README.md`、`CONTRIBUTING.md`、`CONTEXT.md`、`docs/development.md`、ADR/规范目录（`plans/adr/`、`docs/decisions/` 等）。
3. **结构推断**：顶层目录与 `docs/` 布局、索引文件（`README.md`、`docs/README.md`、`SUMMARY.md`）、既有 frontmatter 字段、命名模式。
4. **兜底默认**：最小编辑、相对链接、单文档原地更新、索引与实际一致。

**项目指令缺失时不得静默降级**：上下文中没有 `AGENTS.md`/`CLAUDE.md`（fresh subagent、其他宿主等）时，报告必须写明"项目规则未加载"，并最多执行一次只读 fallback——按宿主发现顺序（项目根→当前目录）读 `AGENTS.override.md`/`AGENTS.md`/`CLAUDE.md`，在报告中标注读取的文件与时间；不受信任项目、越界路径或读取失败时不读，按兜底默认执行并如实报告。

**不要自建第二规则源**：不逐轮重读指令文件，不把磁盘内容与上下文副本静默合并，不用 mtime/git 判断新旧。会话中改了 `AGENTS.md` 而上下文未刷新时，提示用户新开会话或重启，而不是自行追新。

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

**无 diff 模式**：工作区干净且没有可比提交时不要直接结束。改为只依据会话上下文，把已确认的决策映射到**纯决策型文档**（`CONTEXT.md`、ADR、`plans/`、README 状态行）；代码行为描述类文档不动，报告写明"来源仅会话上下文"。

### 3. 按发现的规则更新

- **会话决策分级**：`user-directed`（用户看过取舍后自己选定）、`user-approved`（你提议后用户明确同意）才算依据；你的单方提议最多进 Recommended。
- **冲突裁决**：
  - 会话说法与 diff/代码冲突 → 以代码事实写正文，冲突写进报告；
  - 会话决策次优但可行 → 保留决策并附冲突标注；
  - 已被证明不可行、错误或具破坏性 → 停止该处更新并报告，不静默覆盖。
- **隐私硬边界**：凭据、密钥、个人信息、用户声明"仅讨论、不要落盘"的内容一律不写入文档；不复制会话原文，只写结论；报告只提示"存在未写入的敏感内容"。
- **遵守该仓文档规则**（阶段 0 的发现结果）：放置/命名/归档/证据元数据/索引同步，有几条用几条。
- 没有明文规则时用兜底默认：同一主题只保留一个当前文档，迭代原地更新；被替代的移入 `archive/`（若该仓有该约定）。
- **证据标注**：目标仓有证据规则就跟随；默认给来自会话的结论标 `（会话决策，<日期>）`。
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
- `path/to/file.md` — 改了什么、为什么（来源：diff <range> 或 会话上下文）

## Recommended
- `path/to/file.md` — 需要你判断的事项与理由

## 机械检查
- git diff --check: pass
- 链接存在性: pass | n/a
- 索引一致性: pass | n/a
- archive 归位: pass | n/a
- 项目规则加载: 上下文 | fallback(<file>) | 未加载

## 未写入
- （可选）存在未写入的敏感内容或未确认决策

---
建议手动跑 /ce-compound 沉淀本次学习。
```

## 边界

- 只改工作区文件，不 `git add`/`commit`
- 只读当前对话；不搜索 session 日志、transcript 或其他历史会话
- 不接 superpowers `finishing-a-development-branch`
- 不搬 GPL-3.0 文本；`sync-docs`（无 LICENSE）只读设计
- 单 agent 顺序跑；3+ 文档大 diff 时慢，升级路径是按 `update-docs` 的分档起并行 subagent
