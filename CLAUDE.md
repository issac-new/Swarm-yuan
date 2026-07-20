# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Working language of this repo is **Chinese** (docs, commit messages, inline comments). Match it when editing prose; code/identifiers stay English.

## What this repo is

`swarm-yuan` is a **meta-skill generator**: a bash-based tool that, pointed at any code repository, generates a project-specific development "skill" for AI coding assistants. The generated skill encodes a project's rules as a **16-item feature card** （特征卡， the "legislation") and enforces them with **27 quality gates** （质量门禁， the "enforcement"). It integrates 11 external runtimes (OpenSpec, superpowers, comet, GitNexus, graphify, gsd-core, claude-mem, ocr, gstack, Ruflo, ECC) by **invoking them, never reimplementing**.

There is no compiled artifact and no conventional build — the product is a set of bash scripts, markdown templates/references, and shell gate fragments that get copied into a target skill directory.

## Repository layout (three top-level roles)

- **`swarm-yuan/`** — the generator skill itself. This is the primary thing you edit.
  - `SKILL.md` — the AI entry point / operating manual (the generation pipeline Step 0–10).
  - `install.sh` — one-key installer; auto-detects 7 AI runtimes and copies the skill in.
  - `assets/` — **templates + gates, the source of truth for generated skills.** `precheck.sh` (~2600 lines, all 27 gates), `precheck.conf` (146 config vars), `spec-template.md` (22-section spec), `framework-gates/<fw>.sh` (57 per-framework gate fragments).
  - `references/` — 13 methodology docs + `references/frameworks/<fw>.md` (57 framework rule sources).
  - `scripts/` — the generator `generate-skill.sh`, `self-check.sh`, framework tooling.
  - `tests/` — fixture + e2e tests (see below).
- **`verifier/`** — a self-contained acceptance harness that re-runs the whole suite and compares against a golden vector.
- **`docs/`** — design docs & decision records (`paradigm-decisions.md` explains *why* gates are the way they are — read before "fixing" a gate).

## Common commands

All bash, run from the repo root unless noted. There is no build step; "tests" = the fixture/e2e/verifier suites and shellcheck.

```bash
# --- Install the skill (into a detected AI runtime's skills/ dir) ---
bash swarm-yuan/install.sh                 # auto-detect + install
bash swarm-yuan/install.sh --list          # just list detected runtimes
bash swarm-yuan/install.sh --version       # version + bash version

# --- Self-check (verifies the 11 runtimes; not a unit test) ---
bash swarm-yuan/scripts/self-check.sh --check-only   # detect only, don't install

# --- Generate a skill for some project ---
bash swarm-yuan/scripts/generate-skill.sh <skill-name> <project-dir>
bash swarm-yuan/scripts/generate-skill.sh --upgrade <skill-name> <project-dir>
bash swarm-yuan/scripts/generate-skill.sh --inject-frameworks <skill-dir>

# --- Tests: framework fixture (double-state) for ONE framework ---
# violating/ must FAIL (non-zero exit), compliant/ must PASS (zero exit).
bash swarm-yuan/tests/run-framework-fixture.sh <framework-id>     # e.g. mybatis, vue, koa

# --- Tests: E2E (4-framework injection + gate fail full chain) ---
bash swarm-yuan/tests/e2e/run-e2e.sh

# --- Static check / lint ---
shellcheck -x -e SC2086,SC1090,SC1091,SC2155,SC2034,SC2230,SC2004,SC2312 swarm-yuan/assets/precheck.sh
bash -n swarm-yuan/scripts/self-check.sh   # syntax check

# --- Verify ONE framework ruleset (four-element check) ---
bash swarm-yuan/scripts/verify-framework-ruleset.sh <framework-id>

# --- Run the FULL acceptance suite (fixtures + e2e + shellcheck + metrics) ---
bash verifier/v1/run-verifier.sh all       # or: fixtures | e2e | shellcheck | metrics
```

**Run the full loop for one framework** when changing its gate/rule:
```bash
bash swarm-yuan/scripts/verify-framework-ruleset.sh <id> && \
bash swarm-yuan/tests/run-framework-fixture.sh <id>
```

## The 57-framework system (most edits touch this)

Each of 57 supported frameworks (vue, koa, mybatis, django, gin, kafka, …) has **three coupled artifacts** that must stay consistent:

1. `swarm-yuan/references/frameworks/<fw>.md` — the rules/规律 (frontmatter declares a `深度门槛:` = min number of rules).
2. `swarm-yuan/assets/framework-gates/<fw>.sh` — the executable gate fragment defining a `_fw_<id>_check` function.
3. `swarm-yuan/tests/fixtures/<fw>/{violating,compliant}/` — minimal projects that must trigger / not trigger the gate.

Gate fragments are **injected** into a generated skill's `precheck.sh` between the markers `# >>> swarm-yuan:framework-gates >>>` / `# <<< ... <<<` by `--inject-frameworks`; `--framework <id>` then dynamically dispatches to `_fw_<id>_check`. The marker block is machine-maintained — **never hand-edit inside it.**

**Four-element acceptance** (enforced by `verify-framework-ruleset.sh` and CI): ① component-inventory count ≥ actual × 0.95; ② rule count ≥ the `.md`'s `深度门槛` AND every rule has an `证据:` field; ③ `_fw_<id>_check` exists, `--framework <id>` runs with exit 0; ④ `dev-guide.md §10` has ≥3 framework constraints.

## Key architecture rules

### Cross-platform bash constraint (swarm-yuan's own scripts)
The generator's own scripts must run on **Windows/macOS/Linux**. Windows gets `.bat` wrappers that locate Git Bash/WSL/MSYS2. In bash: **no `declare -A`** (use parallel arrays / strings), use `sed -i.bak` then `rm`, `grep -E`, `date -u`, `$(cd ... && pwd)` instead of `readlink -f`, and `${var}` quoting for C-locale safety. See `swarm-yuan/references/security-spec.md` §六.

### Gates are intentionally conservative
Many gates "sleep" (match nothing) on purpose; `docs/paradigm-decisions.md` documents cases where a naive fix would **wake a sleeping gate and flood real projects with false positives**. Before changing gate matching logic, check that doc and validate against a real project sample, not just the fixture.

## Testing notes

- **No unit-test framework.** Correctness = fixture double-state tests + e2e + shellcheck + the `verifier/` golden-vector comparison.
- **Single test** = `run-framework-fixture.sh <id>` (one framework) or `run-verifier.sh fixtures` (all).
- **Fixture `precheck.conf` uses a `__REPO_ROOT__` placeholder** that the runner substitutes at runtime, so fixtures are machine-independent.
- `verifier/runs/` holds timestamped run logs (append-only record). `verifier/v1/golden-vector.txt` is the expected 57-fixture exit-code vector.
- CI (`.github/workflows/ci.yml`) runs all four jobs on push/PR to `main`: 57 ruleset verifies, 57 fixture double-states, self-check freshness, and shellcheck on core scripts.
