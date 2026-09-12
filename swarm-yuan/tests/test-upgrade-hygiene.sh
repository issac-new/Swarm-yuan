#!/usr/bin/env bash
# test-upgrade-hygiene.sh — R25-D1 回归锚：--upgrade 备份目录不入库
#
# 真实执勤暴露（2026-09-12 R25 轮）：generate-skill.sh 在 SKILL_DIR 创建 .upgrade-backup-<stamp>/
# 但无任何忽略声明，用户项目 `git add -A` 时备份目录整体吸入版本库（样本项目单次 upgrade
# 制造 1.8 万行垃圾提交）。修复：copy_universal_templates 三路径（create/upgrade/resume）
# 幂等写 SKILL_DIR/.gitignore 声明 `.upgrade-backup-*/`。
#
# 本测试走真实 create → git 入库 → upgrade 全链路，断言 git 视角的真实效果（check-ignore），
# 非"文件存在"表面断言；含幂等断言（二次 upgrade 不重复追加）。
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
GEN="scripts/generate-skill.sh"
TMP="$(mktemp -d /tmp/upg.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 最小目标项目（git 仓库） ---
PROJ="$TMP/demo-proj"
mkdir -p "$PROJ/src"
cat > "$PROJ/package.json" <<'EOF'
{ "name": "demo-proj", "version": "1.0.0", "dependencies": { "express": "^4.19.0" } }
EOF
echo "console.log('demo');" > "$PROJ/src/index.js"
git -C "$PROJ" init -q
git -C "$PROJ" config user.email t@t.local
git -C "$PROJ" config user.name t
git -C "$PROJ" add -A
git -C "$PROJ" commit -qm init

# --- 1. create：.gitignore 随骨架生成 ---
out=$(bash "$GEN" demo-proj "$PROJ" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "create exit 0" || bad "create exit=$rc: $(echo "$out" | tail -3)"
SKILL_DIR="$PROJ/.claude/skills/demo-proj"
[[ -f "$SKILL_DIR/.gitignore" ]] && ok "create 后 .gitignore 存在" || bad "create 后缺 .gitignore"
grep -qF '.upgrade-backup-*/' "$SKILL_DIR/.gitignore" && ok ".gitignore 声明 .upgrade-backup-*/" || bad ".gitignore 缺声明: $(cat "$SKILL_DIR/.gitignore")"

# --- 2. 骨架入库 → upgrade → 备份目录对 git 不可见 ---
git -C "$PROJ" add -A
git -C "$PROJ" commit -qm skeleton
out=$(bash "$GEN" --upgrade demo-proj "$PROJ" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "upgrade exit 0" || bad "upgrade exit=$rc: $(echo "$out" | tail -3)"
_backup=$(find "$SKILL_DIR" -maxdepth 1 -type d -name '.upgrade-backup-*' | head -1)
[[ -n "$_backup" ]] && ok "upgrade 产生备份目录" || bad "未产生备份目录"
git -C "$PROJ" check-ignore -q "$_backup" && ok "git check-ignore 命中备份目录" || bad "备份目录未被忽略"
_status=$(git -C "$PROJ" status --porcelain)
echo "$_status" | grep -q '.upgrade-backup-' && bad "git status 出现备份目录（add -A 将吸入）" || ok "git status 无备份目录（add -A 安全）"

# --- 3. 幂等：二次 upgrade 不重复追加 ---
_lines1=$(grep -cF '.upgrade-backup-*/' "$SKILL_DIR/.gitignore")
bash "$GEN" --upgrade demo-proj "$PROJ" >/dev/null 2>&1
_lines2=$(grep -cF '.upgrade-backup-*/' "$SKILL_DIR/.gitignore")
[[ "$_lines1" -eq 1 && "$_lines2" -eq 1 ]] && ok "二次 upgrade 幂等（声明仅 1 行）" || bad "幂等破坏: $_lines1 → $_lines2"

# --- 4. 用户自有 .gitignore 条目不被覆盖 ---
echo "custom-artifact/" >> "$SKILL_DIR/.gitignore"
bash "$GEN" --upgrade demo-proj "$PROJ" >/dev/null 2>&1
grep -qF 'custom-artifact/' "$SKILL_DIR/.gitignore" && ok "用户自有条目保留" || bad "用户条目被清掉"

# --- 5. R25-PR1 回归锚：create 自动注入框架门禁（配置与执法体不脱节）---
# 实仓回归实证（flask/mybatis-3）：create 探测 ACTIVE_FRAMEWORKS 写入 conf 却不注入
# 门禁片段，激活后跑门禁即 advisory "框架已激活但无门禁实现"。修复：create 自动注入。
PYPROJ="$TMP/demo-flask"
mkdir -p "$PYPROJ"
printf 'flask>=3.0\n' > "$PYPROJ/requirements.txt"
out=$(bash "$GEN" demo-flask "$PYPROJ" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态5 create（flask 声明）exit 0" || bad "态5 create exit=$rc"
PYSKILL="$PYPROJ/.claude/skills/demo-flask"
grep -q '_fw_flask_check()' "$PYSKILL/scripts/precheck.sh" \
  && ok "态5 create 后 _fw_flask_check 已注入（无需手动 --inject-frameworks）" \
  || bad "态5 create 未自动注入框架门禁（配置与执法体脱节）"
grep -qE '^# >>> swarm-yuan:framework-gates >>>' "$PYSKILL/scripts/precheck.sh" \
  && ok "态5 注入区块标记存在" || bad "态5 缺注入区块标记"
# 态5b（PR1b）：lite 档无 arch.conf——框架清单须落主 conf（此前探测结果丢失、注入永跳）
grep -qE '^ACTIVE_FRAMEWORKS=\("flask"\)' "$PYSKILL/scripts/precheck.conf" \
  && ok "态5b lite 档框架清单落主 conf" || bad "态5b lite conf 缺框架清单: $(grep -A1 ACTIVE_FRAMEWORKS "$PYSKILL/scripts/precheck.conf" | head -2)"

# --- 6. R25-PR1（standard 档）：显式升档 create 同样自动注入 ---
PYPROJ2="$TMP/demo-flask-std"
mkdir -p "$PYPROJ2" "$PYPROJ2/src" "$PYPROJ2/tests"
printf 'flask>=3.0\n' > "$PYPROJ2/requirements.txt"
for i in $(seq 1 90); do echo "x" > "$PYPROJ2/src/m$i.py"; done
printf 'def test_x():\n    assert True\n' > "$PYPROJ2/tests/test_x.py"
out=$(bash "$GEN" --profile standard demo-flask-std "$PYPROJ2" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态6 standard create exit 0" || bad "态6 create exit=$rc"
grep -q '_fw_flask_check()' "$PYPROJ2/.claude/skills/demo-flask-std/scripts/precheck.sh" \
  && ok "态6 standard create 后 _fw_flask_check 已注入" \
  || bad "态6 standard create 未自动注入"

[[ $FAIL -eq 0 ]] && { echo "PASS test-upgrade-hygiene"; exit 0; } || { echo "FAIL test-upgrade-hygiene" >&2; exit 1; }
