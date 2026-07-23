# ruleset: dotnet  requires_conf: DOTNET_GLOBS
# gates: fw_dotnet_sql_injection(fail) fw_dotnet_password_hash(fail) fw_dotnet_cors(fail) fw_dotnet_https(warn) fw_dotnet_auth(warn) fw_dotnet_async(warn) fw_dotnet_di(warn) fw_dotnet_logging(warn) fw_dotnet_ef_migration(warn) fw_dotnet_nullable(warn)
_fw_dotnet_check() {
  echo "  [dotnet] .NET / C# 框架规律"
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${DOTNET_GLOBS[@]+"${DOTNET_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do [[ -n "$ln" ]] && srcarr+=("$ln"); done <<< "$srcs"
  [[ ${#srcarr[@]} -eq 0 ]] && { warn "dotnet: DOTNET_GLOBS 未配置或无文件可检"; return; }

  # fw_dotnet_sql_injection(fail)
  local bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    local hits; hits=$(echo "$code" | grep -nE 'ExecuteSqlRaw.*\$"|\$".*SELECT|\$".*INSERT|\$".*WHERE|CommandText.*\$"|CommandText.*\+' 2>/dev/null || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report fail fw_dotnet_sql_injection "$bad" "SQL 拼接注入风险（CWE-89）" "未检出 SQL 拼接"

  # fw_dotnet_password_hash(fail)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -iE 'password\s*=\s*[^"]|^.*(password|Password)\s*=\s*[a-zA-Z_]' 2>/dev/null | grep -q . && ! echo "$code" | grep -qiE 'Hash|BCrypt|PBKDF2|Argon2'; then
      bad="${bad}${f}: 密码明文赋值无哈希\n"
    fi
  done
  _fw_report fail fw_dotnet_password_hash "$bad" "密码明文存储（CWE-916）" "未检出密码明文存储"

  # fw_dotnet_cors(fail)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE 'AllowAnyOrigin' && echo "$code" | grep -qE 'AllowCredentials'; then
      bad="${bad}${f}: AllowAnyOrigin + AllowCredentials（CWE-942）\n"
    fi
  done
  _fw_report fail fw_dotnet_cors "$bad" "CORS AllowAnyOrigin+AllowCredentials（CWE-942）" "CORS 配置正确"

  # fw_dotnet_https(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE 'Configure\b|WebHost' && ! echo "$code" | grep -qE 'UseHttpsRedirection'; then
      bad="${bad}${f}: 无 UseHttpsRedirection\n"
    fi
  done
  _fw_report warn fw_dotnet_https "$bad" "无 HTTPS 重定向（CWE-319）" "HTTPS 配置正确"

  # fw_dotnet_async(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE '\.Result\b|\.Wait\(\)' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report warn fw_dotnet_async "$bad" ".Result/.Wait() 死锁风险（CWE-833）" "async/await 使用正确"

  # fw_dotnet_di(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE 'new\s+HttpClient\s*\(\)|new\s+DbContext\s*\(' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report warn fw_dotnet_di "$bad" "直接 new 服务实例（建议 DI 注入）" "DI 使用正确"

  # fw_dotnet_logging(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE 'Console\.(WriteLine|Write)\(' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report warn fw_dotnet_logging "$bad" "Console.WriteLine 生产代码（CWE-209）" "未检出 Console.WriteLine"

  # fw_dotnet_nullable(warn)
  bad=""
  local has_nullable=0
  for f in "${srcarr[@]}"; do
    echo "$f" | grep -qE '\.cs$' || continue
    _fw_strip_comments_c "$f" 2>/dev/null | grep -qE '#nullable enable' && has_nullable=1
    echo "$f" | grep -qE '\.csproj$' && grep -qE '<Nullable>enable</Nullable>' "$f" 2>/dev/null && has_nullable=1
  done
  [[ $has_nullable -eq 0 ]] && warn "fw_dotnet_nullable: 未启用 nullable 引用类型（CWE-476）" || pass "fw_dotnet_nullable: nullable 引用类型已启用"

  # fw_dotnet_auth(warn) + fw_dotnet_ef_migration(warn) - simplified
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE '\[Http(Get|Post|Put|Delete)' && ! echo "$code" | grep -qE '\[Authorize\]'; then
      bad="${bad}${f}: 端点无 [Authorize]\n"
    fi
  done
  _fw_report warn fw_dotnet_auth "$bad" "端点无 [Authorize]（CWE-306）" "身份验证配置正确"

  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE 'ExecuteSqlRaw.*CREATE\s+TABLE' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report warn fw_dotnet_ef_migration "$bad" "裸 SQL 迁移（建议 EF Core Migrations）" "EF Core 迁移使用正确"
}
