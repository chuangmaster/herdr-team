## herdr team

### Dispatching agents with `hc run`: worktree rules

- Never switch branches in a repo's main checkout. Other sessions and tabs share that folder, and a checkout changes the files under them.
- Before dispatching any role that edits files (developer, fixer, tester), create a worktree for the feature: `git worktree add <repo>/.worktrees/<feature> -b <branch>`, and point each role's `--cwd` at it.
- All roles working on the same feature share that one feature worktree. Read-only roles (reviewer, bug-finder) may work in it too.
- For a feature that spans repos (backend and frontend), create a worktree in each repo with the same `<feature>` name and branch name.
- Do not run two roles that edit files in the same worktree at the same time. Run them in sequence, or give each one its own worktree.
- When the feature is merged, remove its worktrees with `git worktree remove`.

### Sub-agent lifecycle

Sub-agents started from templates run interactive `claude`, so they stay live (status `done`) after reporting. Clean them up yourself:

- Reuse before spawning. For follow-up work on the same feature (another fix round, a re-review), send it to the existing role with `hc send <t> "<task>"` instead of starting a new one (no `fix2`).
- Once you have a sub-agent's report and won't send it more work, end it: `hc kill <t>`, then `hc rm <t>`.
- When the feature is merged, kill and remove every remaining sub-agent of that feature before removing its worktrees.
