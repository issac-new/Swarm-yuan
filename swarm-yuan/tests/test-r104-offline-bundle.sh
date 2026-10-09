#!/usr/bin/env bash
# test-r104-offline-bundle.sh — 离线安装包构建器守门测试（R104）
# 覆盖：①清单格式与通道陷阱锁 ②构建器语法与产物模板关键内容 ③安装器协议
# （不实跑构建——npm pack/pip download 非密封；实包验收由收口记录留档）
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# ===== ① 清单格式与通道陷阱 =====
MF="scripts/offline-manifest.conf"
[[ -f "$MF" ]] && ok "1a 清单在位" || { bad "1a 清单缺失"; exit 1; }
# 1b 每行四段管道分隔（runtime|channel|spec|note）
n_bad=0
while IFS='|' read -r a b c d; do
  case "$a" in ''|'#'*) continue ;; esac
  [[ -n "$a" && -n "$b" && -n "$c" && -n "$d" ]] || n_bad=$((n_bad+1))
done < "$MF"
[[ $n_bad -eq 0 ]] && ok "1b 清单行四段格式（${n_bad} 违规）" || bad "1b 清单有 $n_bad 行格式违规"
# 1c 通道陷阱①：graphify 必须走 pip 且包名双 y（裸名 PyPI 无版本/npm 同名异源）
grep -q '^graphify|pip|graphifyy==' "$MF" && ok "1c graphify→pip graphifyy（双 y 陷阱锁）" || bad "1c graphify 通道错误"
# 1d 通道陷阱②：gsd-core 必须用 @opengsd/ 域（裸名占位包）
grep -q '^gsd-core|npm|@opengsd/gsd-core@' "$MF" && ok "1d gsd-core→@opengsd 域名包" || bad "1d gsd-core 裸名违规"
# 1e 通道值合法
grep -E '^[a-z0-9-]+\|(npm|pip|github)\|' "$MF" | wc -l | grep -q '^0$' && bad "1e 无合法行" || ok "1e 通道值枚举合法"
grep -vE '^[a-z0-9-]+\|(npm|pip|github)\||^#|^$' "$MF" | head -1 | grep -q . && bad "1e 存在非法通道行" || ok "1e2 无非法通道行"

# ===== ② 构建器 =====
BD="scripts/make-offline-bundle.sh"
bash -n "$BD" && ok "2a 构建器语法" || bad "2a 语法失败"
# 2b 分发边界与 install.sh 一致（四排除）
grep -q 'research|.swarm-yuan|offline-cache|ci) continue' "$BD" && ok "2b 分发边界四排除" || bad "2b 排除清单漂移"
# 2c pip 用 python3 -m pip（裸 pip 坏解释器坑）
grep -q 'python3 -m pip download' "$BD" && grep -q 'python3 -m pip install' "$BD" && ok "2c python3 -m pip 双点" || bad "2c 裸 pip 残留"
# 2d SWARM_YUAN_DIR 参数化（可从任意位置运行）
grep -q 'SWARM_YUAN_DIR' "$BD" && ok "2d 目录参数化" || bad "2d 缺参数化"
# 2e 无全角紧跟 $var（G20 族——本轮实录坑：$rt（ 触发 unbound；直击常见全角标点四类）
if grep -nE '\$[a-zA-Z_][a-zA-Z0-9_]*[（）：，。「」]' "$BD" | head -3 | grep -q .; then
  bad "2e 疑似全角紧跟 \$var 残留"; else ok "2e 零全角紧跟（G20）"; fi

# ===== ③ 安装器模板关键内容（嵌入 heredoc 断言） =====
grep -q 'install-offline.bat' "$BD" && ok "3a Windows 入口模板" || bad "3a 缺 bat 入口"
grep -q 'Git for Windows' "$BD" && ok "3b README 前置披露 Git Bash" || bad "3b 缺前置说明"
grep -q -- '--with-npm' "$BD" && grep -q -- '--with-pip' "$BD" && ok "3c vendor 旗标" || bad "3c 缺 vendor 旗标"
grep -q 'vendor/npm/\*.tgz' "$BD" && ok "3d npm 本地包免源安装" || bad "3d 缺 tgz 安装"

if [[ $FAIL -eq 0 ]]; then echo "test-r104-offline-bundle: PASS"; else echo "test-r104-offline-bundle: FAIL" >&2; fi
exit $FAIL
