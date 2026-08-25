#!/usr/bin/env bash
# test-codex-adapter.sh — Codex 适配器 deny 协议锚（audit-2026-08-25 P0：
# 生成的 PreToolUse 命令若带 `|| true`/`2>/dev/null`，exit 2+stderr 透传被抵消，拦截恒失效）
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
TMP="$(mktemp -d /tmp/codexad.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# 渲染 hooks.json（render_tool_codex_hooks 只依赖 $1，无需 common.sh）
# shellcheck disable=SC1091
. "assets/tool-adapters/codex.sh"
mkdir -p "$TMP/proj"
render_tool_codex_hooks "$TMP/proj" >/dev/null 2>&1
HJ="$TMP/proj/.codex/hooks.json"

# 态1 hooks.json 生成
[[ -f "$HJ" ]] && ok "态1 hooks.json 生成" || { bad "态1 hooks.json 未生成"; exit 1; }

# 态2 PreToolUse 指向 codex-gate-wrapper
grep -q 'codex-gate-wrapper.sh' "$HJ" && ok "态2 PreToolUse 接 wrapper" || bad "态2 wrapper 未接线"

# 态3 PreToolUse 行无 || true（exit 2 必须可达 Codex）
pre_line=$(grep 'codex-gate-wrapper' "$HJ")
if printf '%s' "$pre_line" | grep -q '|| true'; then
  bad "态3 PreToolUse 含 || true（deny 被吞）"
else
  ok "态3 PreToolUse 无 || true"
fi

# 态4 PreToolUse 行无 2>/dev/null（stderr 原因须透传给模型）
if printf '%s' "$pre_line" | grep -q '2>/dev/null'; then
  bad "态4 PreToolUse 含 2>/dev/null（透传被丢）"
else
  ok "态4 PreToolUse 无 2>/dev/null"
fi

# 态5 wrapper 自身 deny 路径：构造 deny JSON 输入，断言 exit 2 + stderr 非空
mkdir -p "$TMP/skill/scripts"
cp assets/hooks/codex-gate-wrapper.sh assets/hooks/fail-gate-hook.sh "$TMP/skill/scripts/" 2>/dev/null || true
deny_in='{"tool_name":"Bash","tool_input":{"command":"rm -rf *"}}'
# wrapper 依赖 fail-gate-hook 输出 deny JSON；fail-gate-hook 需要 conf——此处仅断言 wrapper 对 deny JSON 的协议转换：
# 用假 fail-gate-hook 直接输出 deny JSON，验证 wrapper 的 exit 2 + stderr 透传
cat > "$TMP/skill/scripts/fail-gate-hook.sh" <<'FEOF'
#!/usr/bin/env bash
printf '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"测试拒绝","additionalContext":"替代方案X"}}\n'
FEOF
chmod +x "$TMP/skill/scripts/fail-gate-hook.sh"
err=$(cd "$TMP/skill" && printf '%s' "$deny_in" | bash scripts/codex-gate-wrapper.sh 2>&1 >/dev/null); rc=$?
[[ $rc -eq 2 ]] && ok "态5 deny → exit 2" || bad "态5 exit=${rc}（应为 2）"
printf '%s' "$err" | grep -q "测试拒绝" && ok "态6 stderr 透传原因" || bad "态6 stderr=$err"

# 态7 放行路径 exit 0
cat > "$TMP/skill/scripts/fail-gate-hook.sh" <<'FEOF'
#!/usr/bin/env bash
printf '{"hookSpecificOutput":{"permissionDecision":"allow"}}\n'
FEOF
(cd "$TMP/skill" && printf '%s' "$deny_in" | bash scripts/codex-gate-wrapper.sh >/dev/null 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态7 allow → exit 0" || bad "态7 exit=${rc}（应为 0）"

if [[ $FAIL -eq 0 ]]; then echo "test-codex-adapter: PASS"; else echo "test-codex-adapter: FAIL" >&2; fi
exit $FAIL
