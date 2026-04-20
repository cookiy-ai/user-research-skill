# CLI / MCP 响应字段裁剪结果

所有改动只影响 `structuredContent.data`。`content` 恒为空数组，顶层不再铺开 `data`。

`-` 前缀表示删除；未带前缀的字段保持不变。

---

## `cookiy_study_create`

```diff
 {
   studyId,
   status,
-  discussion_guide_status_url,
-  current_stage,
-  stage_label,
-  source_tool,
-  status_message,
-  next_recommended_tools,
-  discussion_guide_wait,        // 仅 wait_for_guide=true 时
 }
```

---

## `cookiy_media_upload`

```diff
 {
   s3_key,
-  content_type,
-  file_name,
-  note,
 }
```

---

## `cookiy_guide_get`

```diff
 {
   study_id,
   revision,
   discussion_guide,
   language,
   important_field_review,       // 可选
   quote: {
-    study_id,
-    study_name,
-    required_participants,
-    purchased_participants,
-    price_per_participant_cents,
-    total_cost_cents,
-    shortfall_cents,
-    package_tier,
-    requires_premium,
-    recruit_mode,
   },
 }
```

---

## `cookiy_guide_patch`

```diff
 {
   study_id,
   revision,
   base_revision,
   idempotency_key,
   applied,
-  change_message,
-  discussion_guide,
-  unified_diff,
-  pricing_impact,
-  quote_before,
-  quote_after,
-  idempotent_replay,
-  recruit_reconfigure_status,
-  recruit_reconfigure_confirmation_details,
-  guide_saved,
-  downstream_reconfigure_pending,
-  workflow_state,
-  status_message,
-  next_recommended_tools,
 }
```

---

## `cookiy_interview_list`

```diff
 {
   study_id,
   interviews: [
     {
-      interview_id,
       group_key,
       primary_interview_id,
       latest_completed_interview_id,
       active_interview_id,
       interview_ids,
       status,
       interview_state,
       participant_name,
       duration_seconds,
       recording_count,
       is_simulation,
       interview_type,
       created_at,
     }
   ],
   total,
   limit,
   cursor,
   next_cursor,
   avg_duration_minutes,
   result_granularity,
   grouping_basis,
-  status_breakdown,
-  playback_ready_interview_ids,
   status_message,
   next_recommended_tools,
   presentation_hint,
 }
```

---

## `cookiy_interview_playback_get` · `view=url`

```diff
 {
   interview_id,
   playback_page_url,
   playback_page_expires_at,
-  playback_page_markdown,
 }
```

---

## `cookiy_report_content_get`

```diff
 {
   study_id,
   report_status,
   report_id,
   generated_at,
   title,
   markdown,
   total_aspects,
   total_responses,
-  items,
   report_rendered_markdown,
   status_message,
   next_recommended_tools,
 }
```

---

## `cookiy_quant_survey_detail`

```diff
 {
   survey_id,
   title,
   survey_format,
   language,
   active,
   survey_public_url,
-  respondent_urls_base,
   public_link_warning,
   creation_summary_markdown,
 }
```

---

## `cookiy_quant_survey_report`

```diff
 {
   survey_id,
   completion_status,
   response_row_count,
   question_count,
-  quota_count,
-  completion_rate,
   completion_funnel: {
     completion_rate,
     ...
   },
-  report_summary: {
-    headline,
-    key_points,
-    parsing_ok,
-  },
-  summary_raw,
-  raw_results,
-  raw_participants,
   question_summaries,
   quota_summaries: [
     {
       quota_id,
       name,
       limit,
       completed,
       active,
-      raw,
     }
   ],
   next_recommended_tools,
   status_message,
 }
```

---

## `cookiy_quant_survey_admin_link`

### 未配置 bridge

```diff
 {
-  configured,
   admin_login_url,               // null
-  admin_login_page_url,
-  ls_uid,
-  ls_username,
-  status_message,
+  token_ttl_seconds,             // 0
 }
```

### 成功路径

```diff
 {
-  configured,
   admin_login_url,
-  admin_login_page_url,
-  ls_uid,
-  ls_username,
-  target_survey_id,
   token_ttl_seconds,
-  usage_hint,
-  status_message,
 }
```

---

## `cookiy_activity_get`

```diff
 {
   study_id,
   current_stage,
-  stage_label,
   waiting_for_user,
   blocking_reason,
   sources: {
     study: {
       available,
       status,
-      stage_label,
       status_message,
       waiting_for_user,
       blocking_reason,
       progress_ratio,
       progress_text,
     },
     guide: {
       available,
       status,
-      stage_label,
       status_message,
       waiting_for_user,
       blocking_reason,
       progress_ratio,
       progress_text,
     },
     recruit: {
       available,
       status,
-      stage_label,
       status_message,
       waiting_for_user,
       blocking_reason,
       progress_ratio,
       progress_text,
     },
     report: {
       available,
       status,
-      stage_label,
       status_message,
       waiting_for_user,
       blocking_reason,
       progress_ratio,
       progress_text,
     },
     simulated_interview: {
       available,
       status,
-      stage_label,
       status_message,
       waiting_for_user,
       blocking_reason,
       progress_ratio,
       progress_text,
     } | null,
   },
   activity_summary_text,
 }
```

