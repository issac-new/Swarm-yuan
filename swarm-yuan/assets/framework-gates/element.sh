# ruleset: element  requires_conf: ELEMENT_SRC_GLOBS
# gates: fw_element_on_demand_import(warn) fw_element_form_rules(warn) fw_element_table_virtual(warn) fw_element_i18n_no_hardcode_cn(warn) fw_element_theme_no_override_component(warn) fw_element_imperative_api(warn) fw_element_form_item_prop(warn) fw_element_dialog_destroy_on_close(warn) fw_element_tree_virtual(warn) fw_element_date_value_format(warn) fw_element_upload_size_limit(fail) fw_element_select_remote_search(warn)
# harvested-from: P5 范例（2026-07-17），规律源自 Element Plus 2.x 官方文档
_fw_element_check() {
  echo "  [element] Element Plus 2.x 框架规律"

  # ---------- 收集源文件清单 ----------
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${ELEMENT_SRC_GLOBS[@]+"${ELEMENT_SRC_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"

  if [[ ${#srcarr[@]} -eq 0 ]]; then
    warn "element: ELEMENT_SRC_GLOBS 未配置或无文件可检"
    return
  fi

  # ====================================================================
  # fw_element_on_demand_import(warn)：检出全量 import 'element-plus'
  # ====================================================================
  local full_imp=""
  local f
  for f in "${srcarr[@]}"; do
    local ln
    ln=$(grep -nE "from ['\"]element-plus['\"]|import ['\"]element-plus['\"]|import ElementPlus" "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && full_imp="${full_imp}${f}:${ln}
"
  done
  _fw_report warn fw_element_on_demand_import "$full_imp" "检出全量 import element-plus（生产须用 unplugin-vue-components 按需引入，否则包体过大）" "未检出全量 import（已按需引入或未使用）"

  # ====================================================================
  # fw_element_form_rules(warn)：表单校验须用 rules，禁手动 if 校验
  # ====================================================================
  local form_bad=""
  for f in "${srcarr[@]}"; do
    if ! grep -qE '<el-form\b' "$f" 2>/dev/null; then
      continue
    fi
    # 含 el-form 但同文件无 :rules= 且有 if 校验字符串
    if ! grep -qE ':rules=|rules=|:model=' "$f" 2>/dev/null; then
      local ln
      ln=$(grep -nE "if[[:space:]]*\([^)]*(\.value|length|===|==)|alert\(['\"]" "$f" 2>/dev/null | head -1 || true)
      [[ -n "$ln" ]] && form_bad="${form_bad}${f}:${ln}
"
    fi
  done
  _fw_report warn fw_element_form_rules "$form_bad" "el-form 未用 :rules 校验（须用 rules + FormInstance.validate，禁手动 if 校验）" "el-form 均用 rules 校验（或无表单）"

  # ====================================================================
  # fw_element_table_virtual(warn)：el-table 大数据须虚拟滚动
  # ====================================================================
  local tbl_bad=""
  for f in "${srcarr[@]}"; do
    if ! grep -qE '<el-table\b' "$f" 2>/dev/null; then
      continue
    fi
    # 含 :data 绑定数组且疑似大数据（命名含 list/rows/data），无 virtual-scroll/virtualScrollbar/lazy
    if grep -qE ':data="[a-zA-Z_]*(list|List|rows|Rows|data|Data)"' "$f" 2>/dev/null; then
      if ! grep -qE 'virtual|virtualScroll|el-table-v2|lazy' "$f" 2>/dev/null; then
        local ln
        ln=$(grep -nE '<el-table\b' "$f" 2>/dev/null | head -1)
        tbl_bad="${tbl_bad}${f}:${ln}
"
      fi
    fi
  done
  _fw_report warn fw_element_table_virtual "$tbl_bad" "el-table 绑定疑似大数据源未配虚拟滚动（>1k 行须用 el-table-v2 或 virtual-scroll）" "el-table 已配虚拟滚动或数据量小（或无表格）"

  # ====================================================================
  # fw_element_i18n_no_hardcode_cn(warn)：禁硬编码中文文案
  # ====================================================================
  local cn_bad=""
  for f in "${srcarr[@]}"; do
    case "$(basename "$f")" in
      *.vue|*.tsx|*.jsx|*.ts|*.js)
        # 模板/JSX 中含中文且无 $t( / t( / i18n 调用
        local ln
        ln=$(grep -nE '[一-龥]{2,}' "$f" 2>/dev/null | grep -vE '\$t\(|\bt\(|i18n|//|/\*|\*' | head -1 || true)
        [[ -n "$ln" ]] && cn_bad="${cn_bad}${f}:${ln}
"
        ;;
    esac
  done
  _fw_report warn fw_element_i18n_no_hardcode_cn "$cn_bad" "检出硬编码中文文案（须用 \$t() i18n，否则无法国际化）" "未检出硬编码中文（或已用 i18n）"

  # ====================================================================
  # fw_element_theme_no_override_component(warn)：禁直接改组件包 SCSS 源
  # ====================================================================
  local th_bad=""
  for f in "${srcarr[@]}"; do
    case "$(basename "$f")" in
      *.scss|*.css)
        # 引用 node_modules/element-plus 的内部变量文件并直接覆盖（非 CSS 变量）
        local ln
        ln=$(grep -nE 'node_modules/element-plus|@use.*element-plus/theme' "$f" 2>/dev/null | head -1 || true)
        [[ -n "$ln" ]] && th_bad="${th_bad}${f}:${ln}
"
        ;;
    esac
  done
  _fw_report warn fw_element_theme_no_override_component "$th_bad" "直接引用 element-plus 内部 SCSS 覆盖（须用 CSS Variables / --el-* 变量覆盖，改源升级即丢）" "未检出直接改组件源（已用 CSS 变量）"

  # ====================================================================
  # fw_element_imperative_api(warn)：命令式 API 须 import 而非挂全局
  # ====================================================================
  local imp_bad=""
  for f in "${srcarr[@]}"; do
    local ln
    ln=$(grep -nE '\bEl(Message|Notification|MessageBox|Loading)\b' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && imp_bad="${imp_bad}${f}:${ln}
"
  done
  # 命令式 API 出现但无 import 语句 → 风险（依赖全局挂载）
  local imp_no_import=""
  if [[ -n "$imp_bad" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local ff
      ff=$(printf '%s\n' "$line" | cut -d: -f1)
      if ! grep -qE "import[[:space:]]+.*El(Message|Notification|MessageBox|Loading)|from ['\"]element-plus['\"]" "$ff" 2>/dev/null; then
        imp_no_import="${imp_no_import}${line}
"
      fi
    done <<< "$imp_bad"
  fi
  _fw_report warn fw_element_imperative_api "$imp_no_import" "ElMessage/ElNotification 等命令式 API 调用未显式 import（依赖全局挂载，SSR/按需引入下失效）" "命令式 API 均显式 import（或未使用）"

  # ====================================================================
  # fw_element_form_item_prop(warn)：el-form-item 须配 prop 与 model 对应
  # ====================================================================
  local prop_bad=""
  for f in "${srcarr[@]}"; do
    if ! grep -qE '<el-form-item\b' "$f" 2>/dev/null; then
      continue
    fi
    # 含 el-form-item 但无 prop= 属性
    local ln
    ln=$(grep -nE '<el-form-item\b' "$f" 2>/dev/null | grep -vE 'prop=|prop:' || true)
    [[ -n "$ln" ]] && prop_bad="${prop_bad}${f}:${ln}
"
  done
  _fw_report warn fw_element_form_item_prop "$prop_bad" "el-form-item 未配 prop（须与 model 字段对应，否则校验/重置失效）" "el-form-item 均配 prop（或无表单项）"

  # ====================================================================
  # fw_element_dialog_destroy_on_close(warn)：el-dialog 须配 destroy-on-close
  # ====================================================================
  local dlg_bad=""
  for f in "${srcarr[@]}"; do
    if ! grep -qE '<el-dialog\b' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE 'destroy-on-close|destroyOnClose' "$f" 2>/dev/null; then
      local ln
      ln=$(grep -nE '<el-dialog\b' "$f" 2>/dev/null | head -1)
      dlg_bad="${dlg_bad}${f}:${ln}
"
    fi
  done
  _fw_report warn fw_element_dialog_destroy_on_close "$dlg_bad" "el-dialog 未配 destroy-on-close（关闭后子组件状态残留，表单/校验不重置）" "el-dialog 均配 destroy-on-close（或无 dialog）"

  # ====================================================================
  # fw_element_tree_virtual(warn)：el-tree 大数据须虚拟滚动
  # ====================================================================
  local tree_bad=""
  for f in "${srcarr[@]}"; do
    if ! grep -qE '<el-tree\b' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE 'virtual|:height|:virtual-line-height|el-tree-v2' "$f" 2>/dev/null; then
      local ln
      ln=$(grep -nE '<el-tree\b' "$f" 2>/dev/null | head -1)
      tree_bad="${tree_bad}${f}:${ln}
"
    fi
  done
  _fw_report warn fw_element_tree_virtual "$tree_bad" "el-tree 未配虚拟滚动（>1k 节点须用 el-tree-v2，否则卡顿）" "el-tree 已配虚拟滚动或数据量小（或无树）"

  # ====================================================================
  # fw_element_date_value_format(warn)：日期组件须配 value-format
  # ====================================================================
  local date_bad=""
  for f in "${srcarr[@]}"; do
    if ! grep -qE '<el-date-picker\b|<el-time-picker\b' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE 'value-format|valueFormat' "$f" 2>/dev/null; then
      local ln
      ln=$(grep -nE '<el-date-picker\b|<el-time-picker\b' "$f" 2>/dev/null | head -1)
      date_bad="${date_bad}${f}:${ln}
"
    fi
  done
  _fw_report warn fw_element_date_value_format "$date_bad" "日期组件未配 value-format（默认返回 Date 对象，序列化/反序列化不一致）" "日期组件均配 value-format（或无日期组件）"

  # ====================================================================
  # fw_element_upload_size_limit(fail)：el-upload 须配文件大小限制
  # ====================================================================
  local up_bad=""
  for f in "${srcarr[@]}"; do
    if ! grep -qE '<el-upload\b' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE 'before-upload|beforeUpload|:limit|:file-size|limit:' "$f" 2>/dev/null; then
      local ln
      ln=$(grep -nE '<el-upload\b' "$f" 2>/dev/null | head -1)
      up_bad="${up_bad}${f}:${ln}
"
    fi
  done
  _fw_report fail fw_element_upload_size_limit "$up_bad" "el-upload 未配 before-upload 大小校验（无限制可上传超大文件致存储耗尽/DoS）" "el-upload 均配大小限制（或无上传）"

  # ====================================================================
  # fw_element_select_remote_search(warn)：el-select 远程搜索须配 remote-method
  # ====================================================================
  local sel_bad=""
  for f in "${srcarr[@]}"; do
    if ! grep -qE '<el-select\b' "$f" 2>/dev/null; then
      continue
    fi
    # 含 filterable 但无 remote-method（疑似本地过滤大数据）
    if grep -qE 'filterable' "$f" 2>/dev/null; then
      if ! grep -qE 'remote-method|remoteMethod|:remote' "$f" 2>/dev/null; then
        local ln
        ln=$(grep -nE 'filterable' "$f" 2>/dev/null | head -1)
        sel_bad="${sel_bad}${f}:${ln}
"
      fi
    fi
  done
  _fw_report warn fw_element_select_remote_search "$sel_bad" "el-select filterable 但未配 remote-method（大数据选项须远程搜索，否则全量渲染卡顿）" "el-select 远程搜索配置合理（或无 filterable）"
}
