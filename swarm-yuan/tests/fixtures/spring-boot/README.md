# spring-boot fixture 说明

- violating 主触发 3 个 fail 意图：@Transactional 同类自调用 / Actuator exposure.include=* / javax import。
- 断言登记：**2/3 主触发已断言**（`violating/expected-fail-ids`：
  `fw_sboot_transactional_selfinvoke`、`fw_sboot_jakarta_migration`）。
- 第三个主触发 `fw_sboot_actuator_expose` 对 violating/application.yml 的**嵌套 YAML**
  （`management.endpoints.web.exposure.include` 分层写法）当前门禁不识别（只匹配点平铺键），
  属判定面扩张，**留 P1-1**（先断言后修，见实施计划 §四 P1-1 与 §六不做清单 5）。
- 2026-07-20 修复：`spring-boot.sh` 方法名提取字符类 `[A-Za-z0-9_<>,.\[\] ]` → `[][A-Za-z0-9_<>,. ]`
  （POSIX 安全写法，`]` 置首为字面），修复前 BSD grep 下提取为空、selfinvoke 门禁沉睡。
