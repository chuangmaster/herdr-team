#!/usr/bin/env bash
# 安裝 herdr-team：script 與 5 個角色 template。
# 不會覆蓋已存在的檔案；要覆蓋請加 --force。
set -euo pipefail

force=0
[[ "${1:-}" == "--force" ]] && force=1

here="$(cd "$(dirname "$0")" && pwd)"
bin_dir="${HERDR_TEAM_BIN_DIR:-$HOME/.local/bin}"
tpl_dir="${HERDR_CORE_TEMPLATES_DIR:-$HOME/.config/herdr-core/templates}"

for cmd in hc herdr-app jq; do
  command -v "$cmd" >/dev/null || { echo "找不到 $cmd，請先安裝" >&2; exit 1; }
done

mkdir -p "$bin_dir" "$tpl_dir"

put() { # put <來源> <目標>
  if [[ -e "$2" && $force -eq 0 ]]; then
    echo "略過（已存在）：$2"
  else
    cp "$1" "$2" && echo "已安裝：$2"
  fi
}

put "$here/bin/herdr-team" "$bin_dir/herdr-team"
chmod +x "$bin_dir/herdr-team"
for f in "$here"/templates/*.md; do
  put "$f" "$tpl_dir/$(basename "$f")"
done

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) echo "注意：$bin_dir 不在 PATH 裡" ;;
esac

echo
echo "完成。派工規則請把 snippets/CLAUDE.md 的內容貼進你的 ~/.claude/CLAUDE.md。"
echo "驗證：hc templates"
