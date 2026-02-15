# Dotfiles Agent Guide

## What This Repo Is
- This is a personal dotfiles repo with mixed static files and ERB templates.
- Primary authoring branch is `main`; templates are rendered locally via Puppet.
- The setup targets broad compatibility: Linux, Cygwin/Windows, and historically Solaris.

## Branches And Deployment Model
- `main`: source-of-truth files (mostly `*.erb` templates plus static files).
- `preprocessed`: CI-generated branch with rendered outputs checked in alongside templates (for hosts without Puppet).
- CI flow in `.gitlab-ci.yml` runs `./.refresh`, force-adds all files (`git add -f .`) because `.gitignore` is `*`, then commits and force-pushes to `preprocessed`.

## Refresh Entry Points
- `./bin/refresh-dotfiles` is the main updater/renderer.
- `./.refresh` is a Ruby wrapper used by Puppet; on Cygwin it does `setuid('joy')` before execing `bin/refresh-dotfiles --no-fetch`.

## Critical `refresh-dotfiles` Behavior
1. If `.git/` is missing, it downloads and extracts the `preprocessed` tarball and exits.
2. In a git clone, unless `--no-fetch` is passed, it runs `git fetch` then `git reset --hard origin/<current-branch>` and re-execs itself.
3. It renders templates with Puppet when `branch == main` or when repo path is not `$HOME`.
4. Otherwise (typically `preprocessed` in `$HOME`) it only enforces `0600` on `.ssh/config`.

## Template Rendering Internals
- A temporary Puppet manifest is generated from `git ls-files '*.erb'`.
- Each template writes a same-path file without `.erb`, preserving template file mode.
- `.templates` is a ledger of managed rendered files; removed templates are cleaned up from disk.
- Puppet module path is `lib/puppet` (local `dotfiles` module + vendored `stdlib`).
- `FACTER_basedir` is passed to Puppet; `dotfiles` manifest uses this fact.

## Windows/Cygwin Details
- On Cygwin, `bin/refresh-dotfiles` converts paths with `cygpath -am` and uses `puppet.bat` (native Windows Puppet).
- This repo intentionally handles Cygwin shell + native Puppet path boundary issues.
- `.templates` newline handling is guarded (`tr -d '\r'`) for Windows line endings.

## Facts And ERB Dependencies
- Templates rely on Puppet facts including `networking.hostname`, `os.family`, `os.name`, `identity.user`, `memory.system.total_bytes`, `processors.count`, `scaling.gui`, `scaling.text`, `primary_output`, and `monitor_layout`.
- Custom local fact in repo: `lib/puppet/dotfiles/lib/facter/profile.rb` (Gentoo-only).
- Many templates `require 'colorscheme'` from `lib/puppet/dotfiles/lib/colorscheme.rb`.

## Repo Gotchas That Matter For Agents
- `.gitignore` is exactly `*` so untracked files from `$HOME` do not flood `git status` noise in this dotfiles layout.
- Use `git ls-files` for tracked file discovery.
- Use `rg -uu` (or `--no-ignore`) for searching; plain `rg` will often return nothing.
- Adding new tracked files requires `git add -f`.
- Generated files on `main` are usually untracked/ignored unless force-added.
- If SSH-signed git commit/revert/cherry-pick fails in sandboxed execution (for example `ssh_askpass`/passphrase errors), rerun the git command outside the sandbox via escalated execution.

## Commit Message Guidance
- For significant changes, use a clear subject plus an explanatory body.
- Keep the subject concise and scoped (for example `tmux: ...`).
- In the body, focus on why the change was made and key tradeoffs.
- Word-wrap body lines to about 72 columns for readability in git tools.

## Codebase Shape
- Large portions are vendored third-party content.
- `lib/puppet/stdlib`, `.tmux/plugins/*`, and Vim plugin trees have git-subtree-style history (squashed upstream commits plus merge commits like `Merge commit '<hash>' as '<path>'`).
- `.local/share/themes/Breeze-Mine/assets` appears vendored/customized directly (no subtree metadata in history).
- If updating subtree-managed deps, preserve the existing subtree-style workflow and commit-message conventions.
- Avoid broad cleanup/reformatting in vendored trees unless explicitly requested.

## Script Conventions
- Most scripts are `zsh` and use zsh-specific features.
- Bash scripts: `bin/refresh-dotfiles`, `bin/ssh`.
- Ruby scripts: `bin/pdeathsig`, `bin/sway-layout-manager`, `bin/taffybar-status`, `lib/ruby/status.rb.erb`.

## Safe Working Pattern
1. Edit `*.erb` sources on `main`, not generated outputs.
2. Be careful running `./bin/refresh-dotfiles` in a working tree with local edits (it hard-resets by default).
3. Prefer `./bin/refresh-dotfiles --no-fetch` when validating local template changes.
4. When changing path logic, test both Cygwin shell assumptions and native Puppet path requirements.

## Validation Notes
- There is no single top-level test suite for the repo itself.
- Practical checks are script syntax checks (`zsh -n`, `bash -n`, `ruby -c`) and targeted smoke tests like `./bin/refresh-dotfiles --help`.
