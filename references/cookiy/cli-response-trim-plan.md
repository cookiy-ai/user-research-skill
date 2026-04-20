# CLI / MCP 响应瘦身方案（草案）

面向：**Cookiy API / MCP 工具返回体**（以及 CLI 通过 `emit_tool_result` 暴露给终端的那一层）。目标：减少重复与噪音，便于 CLI 与自动化只消费稳定、可推导的字段。

---

## 1. `study guide update`（`cookiy_guide_patch`）

**期望成功响应只保留：**


| 字段                | 类型      |
| ----------------- | ------- |
| `study_id`        | string  |
| `revision`        | string  |
| `base_revision`   | string  |
| `idempotency_key` | string  |
| `applied`         | boolean |


其余字段若存在，建议不再下发（或由服务端统一裁剪）。

---

## 2. `study create`（`cookiy_study_create`，无 `--wait`）

**期望只返回：**


| 字段        | 类型     |
| --------- | ------ |
| `studyId` | string |
| `status`  | string |


（若当前返回更多字段，做白名单裁剪。）

---

## 3. `study status`（当前为两次调用：`cookiy_study_get` + `cookiy_activity_get`）

**行为变更：**

- **合并为一次 CLI 输出**：一个 JSON 对象，而不是两行两个对象。
- **合并策略**：将 activity 相关字段并入 study 根对象（或与现有约定一致的一层结构），避免客户端再拼。

**可从合并结果中删除（第二份 / activity 侧常见冗余）：**

- 顶层 `**stage_label`**，以及 `**sources.*.stage_label`**（若结构中有嵌套 `sources`）。
- `**current_stage**` 及与阶段缩写相关的 `**s**` 类字段（按你们内部字段名对齐；原则是去掉与 `stage_label` 同类的重复展示）。

（具体键名以实现为准；本条的意图是：**阶段信息只保留一套**，不要两套标签。）

---

## 4. `file_name`（媒体上传）

- **语义**：可选；表示 MCP 入参中的**原始文件名**。
- **CLI 现状**：`cookiy.sh` 的 `study upload` 只组装 `image_data` / `image_url` / `content_type`，**不传 `file_name`**，因此在纯 CLI 场景下 `**file_name` 一般为 `null**`。
- **约定**：仅当调用方显式传入文件名时，响应里才可能出现非空字符串。

（若响应里需要文档化，在 OpenAPI/MCP 描述里写清即可。）

---

## 5. `study upload`（`cookiy_media_upload`）

**期望只返回：**


| 字段       | 类型     |
| -------- | ------ |
| `s3_key` | string |


---

## 6. `study guide get`（`cookiy_guide_get`）

**从 `quote` 对象中移除（若整段为报价/计费展示，可整块不暴露给 CLI）：**

- `required_participants`
- `purchased_participants`
- `price_per_participant_cents`
- `total_cost_cents`
- `shortfall_cents`
- `package_tier`
- `requires_premium`
- `recruit_mode`

（CLI 若仍需计费信息，应走专门 billing 接口，而不是 guide 内嵌。）

---

## 7. `study interview list`（`cookiy_interview_list`）


| 动作     | 字段                             | 理由                                                                             |
| ------ | ------------------------------ | ------------------------------------------------------------------------------ |
| 删      | `status_breakdown`             | 仅对**当前页** interviews 聚合，与 `total`（全局条数）易混淆；需要时由客户端对当页 `status` 计数。             |
| 删      | `playback_ready_interview_ids` | 可由每行 `latest_completed_interview_id` 与 `status` + `interview_id` 规则推导。         |
| 删（二选一） | `interview_id`                 | 与 `primary_interview_id`、`active_interview_id` 重叠；若保留后两者，可删除行级 `interview_id`。 |


---

## 8. `study interview playback` · `view=url`（`cookiy_interview_playback_get`）

- 删除 `**playback_page_markdown`**（string）。

---

## 9. `study report content`（`cookiy_report_content_get`）

- 删除 `**items`**（数组，含空数组情况）。

---

## 10. 审计脚本：`quant create` 失败（脚本问题）

**原因（与 skill 对齐）：** `references/cookiy/cookiy-quant-schema.md` 要求问题使用字段 `**type`**（如 `list_radio`），**不是 `kind`**。示例里亦为 `type`。

**落地：** 在 `cli_audit_shapes.py` 的 `quant create --json` 载荷中，把问题上的 `kind` 改为 `**type`**，并保证与 schema 一致（`groups[].questions[]` 等）。

**参考：** 同目录 `cookiy-quant-schema.md` 与 `cookiy-quant.md`。

**本仓库状态：** `cli_audit_shapes.py` 已改为使用 `**type`**（与 schema 一致）；若仍失败，再对照预览环境 API 报错逐字段排查。

---

## 11. `quant get`（`cookiy_quant_survey_detail`）

- 删除 `**respondent_urls_base`**。

---

## 12. `quant report`（`cookiy_quant_survey_report`）

**建议删除（重复）：**


| 字段                    | 理由                                                       |
| --------------------- | -------------------------------------------------------- |
| 根上的 `completion_rate` | 与 `completion_funnel.completion_rate` 同源同值，只保留 funnel 内。 |
| `quota_count`         | 与 `quota_summaries.length` 等价，需要个数时用数组长度。                |


**可选删除（产品取舍）：**


| 字段               | 理由                              |
| ---------------- | ------------------------------- |
| `report_summary` | 自然语言复述下方已有指标；若 CLI 只要机器可读结构可去掉。 |


**备注：** 若当前出现 **exit 2** 等，需单独排查工具层/超时/权限；与字段裁剪正交。

---

## 13. `quant admin-link`（`cookiy_quant_survey_admin_link`）

**有无 `--survey-id` 两种调用，响应均只保留：**


| 字段                  | 类型     |
| ------------------- | ------ |
| `admin_login_url`   | string |
| `token_ttl_seconds` | number |


其余字段（如 `configured`、`ls_uid`、`ls_username`、`target_survey_id` 等）若需保留给 Web 控制台，可仅在非 CLI 通道返回，或另设 `verbose` 开关。

**审计脚本说明：** 若本地报告中 `**quant admin-link (no --survey-id)` 出现 exit 127**，多为 **shell/路径问题**（命令未找到），与 API 字段无关；应检查 `bash cookiy.sh` 与参数是否被正确解析。

---

## 实施顺序建议

1. **后端/MCP**：按工具逐个加「响应白名单」或 JSON 序列化层裁剪（与现有客户端兼容性评估后上线）。
2. **CLI**：`study status` 若服务端已合并，可删 `cookiy.sh` 里两次 `invoke` 拼接逻辑，改为单次调用（若提供新工具或合并端点）。
3. `**cookiy.sh`**：可选后续支持 `study upload --file-name` 映射到 MCP `file_name`。
4. **本仓库**：修正 `cli_audit_shapes.py` 中 `quant create` 的 JSON（`type` 字段），并重新生成 `cli-response-structure-audit.md`。

---

## 不在本文范围

- `**recruit`** 相关命令（按你方要求未纳入审计与裁剪列表）。