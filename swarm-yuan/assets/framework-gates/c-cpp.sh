# ruleset: c-cpp  requires_conf: C_CPP_GLOBS
# gates: fw_ccpp_unsafe_str(fail) fw_ccpp_gets(fail) fw_ccpp_memleak(warn) fw_ccpp_format_str(warn) fw_ccpp_raii(warn) fw_ccpp_const(warn) fw_ccpp_nullptr(warn) fw_ccpp_static_cast(warn) fw_ccpp_clang_tidy(warn) fw_ccpp_std_string(warn)
_fw_c_cpp_check() {
  echo "  [c-cpp] C/C++ 框架规律"
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${C_CPP_GLOBS[@]+"${C_CPP_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do [[ -n "$ln" ]] && srcarr+=("$ln"); done <<< "$srcs"
  [[ ${#srcarr[@]} -eq 0 ]] && { warn "c-cpp: C_CPP_GLOBS 未配置或无文件可检"; return; }

  # fw_ccpp_unsafe_str(fail)
  local bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    local hits; hits=$(echo "$code" | grep -nE '\b(strcpy|strcat|sprintf)\s*\(' 2>/dev/null || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report fail fw_ccpp_unsafe_str "$bad" "不安全字符串函数（CWE-120/676）" "未检出不安全字符串函数"

  # fw_ccpp_gets(fail)
  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE '\bgets\s*\(' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report fail fw_ccpp_gets "$bad" "gets() 已移除（CWE-242）" "未检出 gets()"

  # fw_ccpp_memleak(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE '\bmalloc\s*\(' && ! echo "$code" | grep -qE '\bfree\s*\('; then
      bad="${bad}${f}: malloc 无 free\n"
    fi
  done
  _fw_report warn fw_ccpp_memleak "$bad" "malloc 无 free（CWE-401）" "内存管理正确"

  # fw_ccpp_format_str(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE 'printf\s*\(\s*[a-zA-Z_]' | grep -vE 'printf\s*\(\s*"' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report warn fw_ccpp_format_str "$bad" "printf 格式串拼接（CWE-134）" "printf 格式串正确"

  # fw_ccpp_raii(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE '\bnew\s+' && ! echo "$code" | grep -qE 'unique_ptr|shared_ptr|make_unique|make_shared'; then
      bad="${bad}${f}: 裸 new 无智能指针\n"
    fi
  done
  _fw_report warn fw_ccpp_raii "$bad" "裸 new 无智能指针" "RAII/智能指针使用正确"

  # fw_ccpp_const(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    echo "$f" | grep -qE '\.(c|cpp|cc|cxx)$' || continue
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if ! echo "$code" | grep -qE '\bconst\b'; then
      bad="${bad}${f}: 无 const 关键字\n"
    fi
  done
  _fw_report warn fw_ccpp_const "$bad" "无 const correctness" "const 使用正确"

  # fw_ccpp_nullptr(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE '=\s*NULL\b|=\s*0\s*;' | grep -vE 'nullptr' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report warn fw_ccpp_nullptr "$bad" "NULL/0 替代 nullptr" "nullptr 使用正确"

  # fw_ccpp_static_cast(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE '\((int|char|void|double|float|long|short)\s*\*' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report warn fw_ccpp_static_cast "$bad" "C 风格强转（CWE-704）" "static_cast 使用正确"

  # fw_ccpp_clang_tidy(warn)
  local ct_found=0
  for f in "${srcarr[@]}"; do
    echo "$f" | grep -qE '\.clang-tidy$' && ct_found=1
  done
  [[ $ct_found -eq 0 ]] && warn "fw_ccpp_clang_tidy: 无 .clang-tidy 文件" || pass "fw_ccpp_clang_tidy: clang-tidy 配置存在"

  # fw_ccpp_std_string(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    echo "$f" | grep -qE '\.cpp$' || continue
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE 'char\s*\*' && ! echo "$code" | grep -qE 'std::string|#include\s*<string>'; then
      bad="${bad}${f}: char* 无 std::string\n"
    fi
  done
  _fw_report warn fw_ccpp_std_string "$bad" "char* 无 std::string" "std::string 使用正确"
}
