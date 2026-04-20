# CLI / MCP 响应字段一览（未在本次修改中调整）

本次 trim 未涉及的 `cookiy.sh` 命令，及其当前 `structuredContent.data` 字段。仅列字段名，嵌套对象用 `{}` 表示、数组用 `[]`。

> `study status` 已纳入本次修改范围，MCP 侧 `cookiy_activity_get` 合并了 `cookiy_study_get` 的字段，CLI 改为单次调用。字段详情见 `cli-response-trim-fields.md`。

---

## `study list` · `cookiy_study_list`

```
{
  list: [
    {
      studyId,
      projectName,
      state,
      createdAt,
    }
  ],
  total,
  limit,
  cursor,
  next_cursor,
  status_message,
  next_recommended_tools,
  presentation_hint: {
    preferred_format,
    primary_id_field,
    columns: [],
    pagination_fields: [],
  },
}
```

---

## `study interview playback content` · `cookiy_interview_playback_get` · `view=transcript`

```
{
  interview_id,
  transcript,
  turn_count,
  transcript_available,
  playback_type,
}
```

---

## `study run-synthetic-user start` · `cookiy_simulated_interview_generate`

```
{
  study_id,
  job_id,
  status,
  ready,
  failed,
  message,
  total_count,
  completed_count,
  failed_count,
  updated_at,
  queued_at,
  started_at,
  completed_at,
  failed_at,
  resolved_targets,
  failed_personas,
  debit_transaction_id,
  error_code,
  error_name,
  error_data,
  status_url,
  current_stage,
  stage_label,
  source_tool,
  status_message,
  next_recommended_tools,
  simulated_interview_wait,       // 仅 --wait=true 时
}
```

---

## `study report generate` · `cookiy_report_generate`

```
{
  study_id,
  report_status,
  generation_request_id,
  status_message,
}
```

---

## `study report link` · `cookiy_report_share_link_get`

```
{
  study_id,
  report_status,
  share_url,
  share_password,
  status_message,
  next_recommended_tools,
}
```

---

## `study report wait` · `cookiy_report_status` (wait) → `cookiy_report_share_link_get`

`--wait` 分支阻塞到报告完成再调用 share-link，最终输出 = `cookiy_report_share_link_get` 的字段（见上）。

阻塞过程中的 `cookiy_report_status` 单次快照字段：

```
{
  study_id,
  report_status,
  generation_requested,
  generation_request_id,
  report_id,
  generated_at,
  status_message,
  next_recommended_tools,
  // 以下来自 buildReportStatusSupplement
  workflow_state,
  waiting_for_user,
  blocking_reason,
  progress_ratio,
  progress_text,
}
```

---

## `quant list` · `cookiy_quant_survey_list`

```
{
  surveys: [],               // LimeSurvey list_surveys 原样数组
  count,
  list_scope,                // "per_user" | "shared_admin"
  list_filter_username,
  study_id_note,
  next_recommended_tools,
  status_message,
}
```

---

## `quant create` · `cookiy_quant_survey_create`

```
{
  survey_id,
  title,
  language,
  active,
  survey_public_url,
  respondent_urls_base,
  survey_format,
  creation_summary_markdown,
  activation_note,
  recruit_complete_end_url,
  recruit_pass_through_question_created,
  recruit_end_url_mode,
  recruit_completion_hint,
  recruit_redirect_note,
  public_link_warning,
  next_recommended_tools,
  status_message,
}
```

---

## `quant update` · `cookiy_quant_survey_patch`

```
{
  survey_id,
  survey_updated,
  next_recommended_tools,
  status_message,
}
```

---

## `quant status` · `cookiy_quant_survey_status`

```
{
  survey_id,
  completed_responses,
  incomplete_responses,
  full_responses,
  next_recommended_tools,
  status_message,
}
```

---

## `recruit start` · `cookiy_recruit_create`

**预览分支（无 `confirmation_token`）或 guide 已变更触发的二次预览：**

```
{
  // 来自 buildRecruitPreview
  study_summary: {},
  targeting_preview: {},
  confirmation_token,
  // 顶层 promote
  sample_size,
  interview_duration_minutes,
  target_group,
  derived_languages,
  payment_quote,
  // MCP 补充
  status,                        // 仅 guide 变更二次预览
  current_stage,
  stage_label,
  workflow_state,
  preview_only,
  external_draft_created,
  external_supplier_project_created,
  external_launch_started,
  confirmation_reason,           // 仅 guide 变更二次预览
  waiting_for_user,
  blocking_reason,
  progress_ratio,
  progress_text,
  source_tool,
  status_message,
  next_recommended_tools,
  presentation_hint,             // 仅首次预览
  forbidden_claims,
  recruit_preview_markdown,
}
```

**确认分支（携带 `confirmation_token`，成功）：** 透传后端 `/v1/studies/:id/recruit` 响应（内含 `study_id, recruit_project_id, recruit_channel_id, target_participants, ...`）。

---

## `billing balance` · `cookiy_balance_get`

```
{
  balance_summary,               // "Wallet balance: $X.XX (N cents)"
}
```

---

## `billing checkout` · `cookiy_billing_cash_checkout`

```
{
  // 透传 /v1/billing/cash-credit/checkout 响应
  checkout_url,
  amount_cents,
  currency,
  session_id,
  expires_at,
  // MCP 补充
  cash_checkout_user_instructions,
}
```

---

## `billing price-table` · `cookiy_billing_price_table`

```
{
  items: [
    { action, price }
  ],
}
```

---

## `billing transactions` · `cookiy_billing_transactions`

CLI 侧 `jq` 取 `.` 或 `.data` 数组后直接输出数组：

```
[
  {
    id,
    created_at,
    type,
    amount_cents,
    currency,
    quantity,
    description,
    study_id,
    survey_id,
    product_id,
    status,
    debit_transaction_id,
    metadata,
  }
]
```

