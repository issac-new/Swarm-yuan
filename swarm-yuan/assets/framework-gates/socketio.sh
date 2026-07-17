# ruleset: socketio  requires_conf: SOCKETIO_FILE_GLOBS SOCKETIO_NAMESPACE_REQUIRED SOCKETIO_FORBIDDEN_BARE_SOCKET
# gates: fw_socketio_namespace(warn) fw_socketio_no_bare_socket(warn)
# harvested-from: ncwk-dev precheck.sh:2582-2601 (2026-07-17)
_fw_socketio_check() {
  echo "  [socketio] Socket.IO 4.8 框架规律"
  local files fa=()
  files=$(_fw_resolve_globs "${SOCKETIO_FILE_GLOBS[@]+"${SOCKETIO_FILE_GLOBS[@]}"}" | sort -u)
  [[ -z "$files" ]] && { warn "socketio: 无文件可检"; return; }
  while IFS= read -r ln; do fa+=("$ln"); done <<< "$files"
  # 规律1: 须命名空间 setup
  if [[ "$SOCKETIO_NAMESPACE_REQUIRED" == "1" ]]; then
    local setup; setup=$(_fw_grep_count "setup.*[Ss]ocket.*[Nn]amespace|io\.of\(" "${fa[@]}")
    if [[ "$setup" -gt 0 ]]; then pass "socketio: 命名空间 setup ($setup 处)"
    else warn "socketio: 未检出命名空间 setup"; fi
  fi
  # 规律2: 禁裸 socket.on
  if [[ -n "$SOCKETIO_FORBIDDEN_BARE_SOCKET" ]]; then
    local hits; hits=$(grep -rnE "$SOCKETIO_FORBIDDEN_BARE_SOCKET" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then pass "socketio: 无裸 socket.on"
    else warn "socketio: 检出裸 socket.on（建议 setup 封装）: $hits"; fi
  fi
}


