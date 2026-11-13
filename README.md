# herdr-team

我的 herdr 使用規範：派工流程、角色、layout 與快捷鍵。

> 整理日期：2026-11-14
> 這份是**摘要**。真正生效的是下面「設定檔位置」列的原始檔，修改規則請改原始檔，再回來同步這份文件。

---

## 1. 設定檔位置

### 我自己的規則（可改）

| 檔案 | 用途 |
|---|---|
| `~/.claude/CLAUDE.md`（`## herdr` 段） | 派工與 worktree 規則 |
| `~/.config/herdr-core/templates/*.md` | `hc run <角色>` 的角色定義 |

### 介面設定（`~/.config/herdr-app/`）

| 檔案 | 用途 |
|---|---|
| `layouts/main-procs.json` | 目前使用的 layout（由 `main` 0.1.13 clone） |
| `keys.json` | 快捷鍵 |
| `settings.json` | 外觀（zoom 1、音效開、dark） |
| `shared.json` | mod 狀態（目前 layout、agents 排序 `grouped`、側欄收合等） |
| `mods/` | 各面板 mod |

### 官方文件（勿改，會被覆寫）

- `~/.config/herdr-app/AGENTS.md`：herdr app 完整說明
- `hc --help`：herdr-core CLI 說明
- core 設定檔應在 `~/.config/herdr-core/config.toml`（目前不存在，用預設值）

---

## 2. 派工流程

一個主 agent（例如 Claude Code）負責規劃與協調，用 `hc run` 派出子 agent 做實際工作。子 agent 的 `parent` 會記成主 agent，所以在 agents 清單裡會掛在主 agent 底下。

```
主 agent（主 checkout，只協調不改檔）
 ├─ <feature>-be-dev     developer   → 後端 worktree
 ├─ <feature>-fe-dev     developer   → 前端 worktree
 ├─ <feature>-be-review  reviewer    → 後端 worktree
 └─ <feature>-be-fix     fixer       → 後端 worktree
```

### 標準步驟

1. **開 worktree**（會改檔的角色出場前）
   ```sh
   git worktree add <repo>/.worktrees/<feature> -b <branch>
   ```
   前後端跨 repo 時，兩邊用**相同的 `<feature>` 與 branch 名稱**。
2. **派角色**，`--cwd` 指向該 worktree：
   ```sh
   hc run --name <feature>-be-dev --cwd <repo>/.worktrees/<feature> developer "依 plan 實作 …"
   ```
3. **依序**跑：developer → reviewer → fixer → (tester) → reviewer …
4. **merge 後清理**：
   ```sh
   git worktree remove <repo>/.worktrees/<feature>
   ```
   並關掉已完成的子 agent terminal。

### Worktree 規則

- **絕不在 repo 主 checkout 切 branch**：其他 session 和 tab 共用那個資料夾。
- 會改檔的角色（developer、fixer、tester）派出前，一定先建好 worktree。
- 同一個 feature 的所有角色共用**同一個** worktree；唯讀角色（reviewer、bug-finder）也可以在裡面。
- **同一個 worktree 裡，不要同時跑兩個會改檔的角色**：要嘛依序跑，要嘛各給一個 worktree。

---

## 3. 角色（templates）

| 角色 | 模型 | 改檔 | 職責 |
|---|---|---|---|
| `bug-finder` | opus | ✗ | 找根因，回報 `檔案:行號`、重現步驟、修正方向、信心程度 |
| `developer` | sonnet | ✓ | 依需求／spec／plan 實作功能並寫單元測試 |
| `fixer` | sonnet | ✓ | 依調查結果修改，只改必要範圍；根因對不上就停下回報 |
| `reviewer` | opus | ✗ | 審查 `<base>...HEAD` 與未 commit 的變更，依嚴重程度回報 |
| `tester` | haiku | 只改測試 | 撰寫、執行測試；揭露的 bug 只回報 |

### 所有角色共同限制

- 不啟動其他 agent（只有主 agent 能派工）。
- 遵守該專案自己的 `CLAUDE.md` / `AGENTS.md`（風格、測試範圍、遷移檔等）。
- 需求不清楚、範圍要擴大時，停下來回報，不自行假設。

### Commit 規則（developer / fixer / tester）

- 只在 worktree 裡 commit。判斷方式：`git rev-parse --git-dir` ≠ `git rev-parse --git-common-dir` 才是 worktree；相同就不 commit，改在回報中列出變更。
- 只 `git add` 自己改的檔案（指名路徑），禁用 `git add -A` / `git add .`。
- 完成一個可獨立運作的段落就 commit，不要累積到最後。
- 訊息遵循專案慣例。
- **不 push、不切 branch、不 rebase、不改寫既有 commit。**

---

## 4. Layout（`main-procs`）

```
┌──────────────┬──────────────────────────────────────────┐
│ brand        │ tabs-procs（tab 列）                      │
├──────────────┼────────────────────────────┬─────────────┤
│ spaces       │                            │ 右側面板     │
│              │   main（目前 tab 的 panes） │ （預設隱藏） │
├──────────────┤                            │ files       │
│ agents       │                            │ changes     │
│ （grouped，   │                            │ processes   │
│  子 agent 樹）│                            │ tokens      │
├──────────────┼────────────────────────────┴─────────────┤
│ footer       │ workspace-status                         │
└──────────────┴──────────────────────────────────────────┘
  268px                                         368px
```

與原版 `main` 的差異：

- tab 列改用 `tabs-procs` mod。
- 右側面板 stack 新增 `processes`（resource-monitor）與 `tokens`（token-usage）。

其他：側欄目前是收合狀態（`cmd-b` 切換），pane 有 30px 標題列、圓角 10、間距 8。

---

## 5. 常用快捷鍵

| 按鍵 | 動作 |
|---|---|
| `cmd-n` / `cmd-t` | 新 space / 新 tab |
| `ctrl-1…9` / `cmd-1…9` | 切換 space / tab |
| `cmd-alt-[` `]` | 上一個 / 下一個 space |
| `cmd-[` `]` | 上一個 / 下一個 agent |
| `cmd-d` / `cmd-shift-d` | 向右 / 向下分割 pane |
| `cmd-shift-enter` | pane 放大 |
| `cmd-alt-方向` | 移動焦點到相鄰 pane |
| `cmd-b` | 切換側欄 |
| `cmd-p` | picker |
| `cmd-shift-p` | 指令面板 |
| `cmd-shift-l` | 切換 layout |
| `f2` / `shift-f2` | 重新命名 tab / space |
| `ctrl-,`（terminal 內） | 輸入全形逗號「，」 |
| `ctrl-v`（terminal 內） | 貼上圖片 |

---

## 6. 常用 `hc` 指令

```sh
hc ls                          # 列出 terminal／agent（含 parent、template、status）
hc templates                   # 列出角色
hc run --name <名稱> --cwd <dir> <角色> "任務"   # 派工並等待
#   --bg 不等待、--rm 結束後自動移除、--outlive-parent 父 agent 結束後繼續跑
hc --help                      # 完整說明
```
