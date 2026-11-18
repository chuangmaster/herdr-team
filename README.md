# herdr-team

在 [herdr](https://herdr.dev) 裡讓一個主 agent 派出多個角色（調查、開發、修正、審查、測試）協作的一組設定：

- 5 個角色 template（`hc run <角色>` 使用）
- `herdr-team`：一次開多個角色，並在新 tab 排成 pane（選用）
- 派工與 worktree 規則，貼進 `CLAUDE.md` 即可

## 支援平台

| 項目 | macOS | Linux | Windows |
|---|---|---|---|
| templates + `hc run` | ✓（已驗證） | 應可用（未測） | 應可用（未測） |
| `herdr-team` script、`install.sh` | ✓（已驗證） | 應可用（未測） | ✗ 這兩個是 bash，原生 Windows 不能直接跑 |

`herdr-team` 需要 `bash`、`jq`、`hc`、`herdr-app`，而且 **herdr 視窗必須在執行中**（它用 `herdr-app do` 開 tab 與 pane）。只有 herdr-core、沒有視窗時會失敗。

開發與測試版本：`herdr-app 0.1.16`、`hc 0.1.21`。

## 安裝

```sh
git clone https://github.com/chuangmaster/herdr-team
cd herdr-team
./install.sh            # 已存在的檔案不會被覆蓋；加 --force 才覆蓋
hc templates            # 應列出 5 個角色
```

`install.sh` 做兩件事：

- `bin/herdr-team` → `~/.local/bin/`（需在 `PATH` 內）
- `templates/*.md` → `~/.config/herdr-core/templates/`

路徑可用 `HERDR_TEAM_BIN_DIR`、`HERDR_CORE_TEMPLATES_DIR` 覆寫。

最後把 [`snippets/CLAUDE.md`](snippets/CLAUDE.md) 的內容貼進你的 `~/.claude/CLAUDE.md`，主 agent 才會遵守派工規則。

Windows：不要跑 `install.sh`，手動把 `templates/*.md` 放進 herdr-core 的 templates 資料夾，只使用 `hc run`。

## 角色

| 角色 | 模型 | 改檔 | 職責 |
|---|---|---|---|
| `bug-finder` | opus | ✗ | 找根因，回報 `檔案:行號`、重現步驟、修正方向、信心程度 |
| `developer` | sonnet | ✓ | 依需求／spec／plan 實作功能並寫單元測試 |
| `fixer` | sonnet | ✓ | 依調查結果修改，只改必要範圍；根因對不上就停下回報 |
| `reviewer` | opus | ✗ | 審查 `<base>...HEAD` 與未 commit 的變更，依嚴重程度回報 |
| `tester` | haiku | 只改測試 | 撰寫、執行測試；揭露的 bug 只回報 |

模型分配是個人偏好：需要推理的用 opus，實作用 sonnet，跑測試用 haiku。要改就編輯 `templates/*.md` 開頭的 `command:`。

每個角色的完整限制（commit 規則、回報格式等）都寫在 template 本身，以 [`templates/`](templates/) 為準。共通原則：不啟動其他 agent、遵守專案自己的 `CLAUDE.md` / `AGENTS.md`、需求不清楚就停下回報。

## 用法

### 基本：`hc run`（只依賴 herdr-core）

```sh
# 1. 會改檔的角色出場前，先開 worktree
git worktree add <repo>/.worktrees/<feature> -b <branch>

# 2. 派角色，--cwd 指向該 worktree
hc run --name <名稱> --cwd <repo>/.worktrees/<feature> developer "依 plan 實作 …"
```

名稱限 `a-z 0-9 - _`、1–32 字元。用 `hc run` 啟動的角色是 **sub-agent**：沒有自己的 pane，只出現在側邊欄、掛在主 agent 底下。要看內容用 `terminal.peek`，要給它 pane 用 `terminal.keep`。

常用選項：`--bg`（不等待）、`--rm`（結束後自動移除）、`--outlive-parent`（主 agent 結束後繼續跑）。

### 進階：`herdr-team`（新 tab + pane）

```sh
herdr-team -C <worktree> -t fix-login \
  bug-finder "登入失敗，查根因" \
  fixer      "等 bug-finder 的結論再動手" \
  tester     "補登入流程的單元測試"
```

排列（最多 4 個角色）：

```
1 個：A          2 個：A | B
3 個：A | B/C    4 個：A/C | B/D
```

- `-C`：工作資料夾（通常是 worktree）；`-t`：tab 名稱。
- `-p`：保留 parent。**從主 agent 執行時加上**，角色會用 `hc send` 把報告回給它，並加 `--outlive-parent`。
- 沒加 `-p` 時不設 parent，避免報告文字被打進一般 shell 當成指令執行。

### 怎麼選

- 要讓你直接看到每個角色在做什麼 → `herdr-team`。
- 由主 agent 自動派工、畫面保持乾淨 → `hc run`。

## 派工規則

完整文字在 [`snippets/CLAUDE.md`](snippets/CLAUDE.md)，重點：

- **不在主 checkout 切 branch**，其他 session 與 tab 共用那個資料夾。
- 會改檔的角色（developer、fixer、tester）先開 worktree。
- **同一功能的所有角色共用同一個 worktree**；唯讀角色（reviewer、bug-finder）也在裡面，才看得到未合併的變更。跨 repo 時兩邊用相同的 feature 與 branch 名稱。
- 同一個 worktree 不要同時跑兩個會改檔的角色，要依序或各給一個。

### Sub-agent 生命週期

template 跑的是互動模式的 `claude`，回報完不會退出，會一直是 `live`（狀態 `done`），要由主 agent 清理：

- **先重用**：同功能的後續工作用 `hc send <t> "任務"` 交給原角色，不要另開。
- **用完就收**：`hc kill <t>`，再 `hc rm <t>`。
- **merge 時收尾**：先清掉該功能剩下的 sub-agent，再 `git worktree remove`。

名稱沒有固定格式，用你看得懂的即可（例如 `<feature>-be-dev`）。

## 專案結構

```
bin/herdr-team          啟動 script（macOS / Linux）
templates/*.md          5 個角色
snippets/CLAUDE.md      派工與生命週期規則，貼進 CLAUDE.md
install.sh              安裝（macOS / Linux）
```

## 相關

- `hc --help`、`hc templates`：herdr-core 說明
- `~/.config/herdr-app/AGENTS.md`：herdr app 完整說明（由 app 每次啟動時重寫，勿改）
