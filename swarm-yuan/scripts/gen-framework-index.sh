#!/usr/bin/env bash
# 用法: gen-framework-index.sh —— 扫描 references/frameworks/*.md（跳过 _template.md）
#       提取每个文件 frontmatter 的 ruleset_id + §1 探查信号表前几列，
#       组装成 markdown 信号汇总索引，重写 references/exploration-guide.md 中
#       `# >>> framework-signal-index >>>` / `# <<< framework-signal-index <<<` 标记区块。
#       区块不存在则报错退出 1 并提示 T4 须加入标记区块。
set -u
BASE="$(cd "$(dirname "${0}")/.." && pwd)"
FW_DIR="${BASE}/references/frameworks"
GUIDE="${BASE}/references/exploration-guide.md"
BEGIN_MARK="# >>> framework-signal-index >>>"
END_MARK="# <<< framework-signal-index <<<"

if [[ ! -f "${GUIDE}" ]]; then
  echo "✗ exploration-guide.md 不存在: ${GUIDE}" >&2
  exit 1
fi

if ! grep -qF "${BEGIN_MARK}" "${GUIDE}" || ! grep -qF "${END_MARK}" "${GUIDE}"; then
  echo "✗ ${GUIDE} 中缺少 framework-signal-index 标记区块（${BEGIN_MARK} / ${END_MARK}）。" >&2
  echo "  T4 须在 exploration-guide.md §C+.0.5 加入标记区块后本脚本才能重写。" >&2
  exit 1
fi

# 收集各规则文件（跳过 _template.md），按文件名排序保证幂等输出
FILES=""
for f in "${FW_DIR}"/*.md; do
  [[ -f "${f}" ]] || continue
  case "$(basename "${f}")" in
    _template.md) continue ;;
  esac
  FILES="${FILES}
${f}"
done
FILES="$(printf '%s\n' "${FILES}" | grep -E '^/.' | sort)"

# 组装索引到临时文件（awk 多行字符串经 -v 传递在 BSD awk 下报 "newline in string"，
# 故改为先写文件再用 getline 注入，三平台兼容）
IDX_FILE="$(mktemp /tmp/fwidx.XXXXXX)"
{
  printf '| ruleset_id | 信号类型 | 模式 | 置信度 |\n'
  printf '|------------|---------|------|-------|\n'
  while IFS= read -r f; do
    [[ -z "${f}" ]] && continue
    rid=""
    rid=$(sed -n 's/^ruleset_id: *//p' "${f}" | head -1)
    rid="${rid:-$(basename "${f}" .md)}"
    # §1 节范围：从 "## §1" 行到下一个 "## §" 行前
    awk -v rid="${rid}" '
      /^## §1/ { in1=1; next }
      /^## §/ { in1=0 }
      in1 && /^\|/ {
        line=$0
        # 跳过表头与分隔行
        if (line ~ /^\| *信号类型/ || line ~ /^\|[-:| ]+\|$/) next
        # 在行首插入 rid 列：把原行去掉首 "|"，前置 "| rid |"
        sub(/^\|/, "", line)
        print "| " rid " |" line
      }
    ' "${f}"
    # 若无数据行，输出占位行（占位不算 _template 引导语占位符，是机械填充的缺失标记）
    rows=$(awk -v rid="${rid}" '
      /^## §1/ { in1=1; next }
      /^## §/ { in1=0 }
      in1 && /^\|/ {
        line=$0
        if (line ~ /^\| *信号类型/ || line ~ /^\|[-:| ]+\|$/) next
        c++
      }
      END { print c+0 }
    ' "${f}")
    if [[ "${rows}" -eq 0 ]]; then
      printf '| %s | <无 §1 信号行> | - | - |\n' "${rid}"
    fi
  done <<EOF
${FILES}
EOF
} > "${IDX_FILE}"

N="$(printf '%s\n' "${FILES}" | grep -c '^/.')"

# 重写标记区块（awk 分段 + getline 注入索引文件 + 临时文件 mv，兼容三平台）
TMP_BODY="$(mktemp /tmp/fwbody.XXXXXX)"
awk -v beg="${BEGIN_MARK}" -v end="${END_MARK}" -v idxfile="${IDX_FILE}" '
  $0 == beg { print; while ((getline l < idxfile) > 0) print l; inblk=1; next }
  $0 == end { print end; inblk=0; next }
  !inblk { print }
' "${GUIDE}" > "${TMP_BODY}"

mv "${TMP_BODY}" "${GUIDE}"
rm -f "${IDX_FILE}"

echo "已重写索引（${N} 个框架）"
