# Contributing to swarm-yuan

Thank you for your interest in contributing. This document describes the development workflow, testing requirements, and release process.

## Quick Start

```bash
git clone https://github.com/issac-new/Swarm-yuan.git && cd Swarm-yuan
bash install.sh        # Install the generator (auto-detects Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi)
```

## Development Workflow

### 1. Worktree Discipline (mandatory)

All changes must go through a git worktree in `.claude/worktrees/<type>/<name>`:

```bash
git worktree add .claude/worktrees/fix/<slug> -b fix/<slug> origin/main
cd .claude/worktrees/fix/<slug>
# ... make changes ...
git add -A && git commit -m "fix(scope): description"
git fetch origin --prune && git rebase origin/main
git push -u origin fix/<slug>
```

Then merge to main:

```bash
cd /path/to/main/worktree
git checkout main && git pull --ff-only origin main
git merge --no-ff fix/<slug> -m "Merge branch 'fix/<slug>' — description"
git push origin main
git worktree remove .claude/worktrees/fix/<slug>
git branch -d fix/<slug> && git push origin --delete fix/<slug>
git worktree prune
```

**Limits**: ≤3 concurrent worktrees; one task per worktree; no cross-worktree cherry-picking.

### 2. Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>
```

Types: `feat` / `fix` / `docs` / `refactor` / `chore` / `test` / `perf`
Scope: module or concept area (e.g., `precheck`, `hooks`, `template`, `consistency`)
Subject: concise description in present tense, Chinese or English matching repo history

### 3. Testing Requirements

**All changes must pass the full battery before merging**:

```bash
# Self-check (machine reconciliation: facts.conf vs implementation truth)
cd swarm-yuan && bash scripts/self-check.sh --check-only

# Full verifier (fixtures 79 dual-state + gate-fixtures 48 + e2e + gen-e2e + golden + cli-ab)
bash verifier/v1/run-verifier.sh all
```

**Gate-specific testing**: If your change touches gates or frameworks, also run:
- `bash swarm-yuan/tests/run-framework-fixture.sh <framework-id>` (affected frameworks)
- `bash swarm-yuan/tests/run-gate-fixture.sh <gate-id>` (affected gates)

**Regression prevention**: Every fix must include a test or fixture that locks the behavior:
- New gate behavior → add/modify `tests/fixtures/<fw>/` dual-state fixture
- CLI behavior change → verify `cli-ab-test.sh` byte-equivalence
- Workflow change → verify `run-e2e.sh` / `run-gen-e2e.sh`

### 4. Code Standards

- **Bash 3.2 compatibility** (macOS default): No `declare -A`, no `readarray`, `${var}` not `$var` adjacent to multibyte characters
- **BSD-safe sed**: Use `sed -i.bak + rm` pattern; POSIX character classes (`[[:space:]]`), not GNU extensions (`\s`, `\+`)
- **Error handling**: `set -euo pipefail` in new scripts; `set -uo pipefail` (no `-e`) allowed only when individual failures must not halt overall run (document the reason in comments)
- **Variable quoting**: Always quote expansions (`"$VAR"`) unless word-splitting is intentional
- **Function size**: Prefer <100 lines; large functions must have internal section comments (`# 1. Detect # 2. Inject # 3. Update`)
- **UTC timestamps**: Use `date -u` for all timestamp generation (avoid timezone-dependent behavior)

### 5. Documentation Standards

- **Single source of truth**: All counts/metrics go in `swarm-yuan/assets/facts.conf`; documentation must not hardcode numbers (self-check enforces this)
- **README.md** is the single document (five-layer progression: 理念→设计→架构→实现→使用+引用); no separate docs/ except `docs/research/` (调研证据链)
- **SKILL.md** (generator entry) follows the same five-layer structure; target-skill templates must not contain process/version content (terminal-state only)
- **Release notes** follow the format: 痛点→设计思路→使用指南→验证矩阵 (see [v2.6 release](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.6))

## Pull Request Process

1. **Create worktree** and implement (see §1)
2. **Run full battery** locally (see §3) — all must pass
3. **Push branch** and open PR (or merge directly for maintainers)
4. **CI must be green** (ubuntu/macos/windows matrix) before merge
5. **Merge with `--no-ff`** to preserve task boundary
6. **Cleanup worktree and branch** after merge

## Release Process

1. **Feature freeze** on main (all planned changes merged, CI green)
2. **Update CHANGELOG.md** (add new section following Keep a Changelog format)
3. **Update README badge** version (if applicable)
4. **Create annotated tag**: `git tag -a vX.Y.Z -m "swarm-yuan vX.Y.Z — summary"`
5. **Create GitHub Release** with structured notes (痛点→设计→使用→验证矩阵)
6. **Mark as Latest** (only one Latest at a time)

## Code Review

- **Self-review** required: Run `git diff` and verify every change is intentional
- **Worktree discipline enforced**: Reviewer checks that all changes came through a worktree (branch name matches commit scope)
- **Test evidence required**: PR description must reference which tests/fixtures were run and their results
- **No work-in-progress commits**: Commits must be complete and verifiable (no "WIP" or "tmp")

## Questions?

Open an issue with prefix `[Question]` or `[Proposal]`. For security-related questions, follow [SECURITY.md](SECURITY.md) guidelines.
