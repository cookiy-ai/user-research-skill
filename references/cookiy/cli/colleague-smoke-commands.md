# Cookiy shell CLI — 同事上手即用（复制粘贴）

## 你需要准备什么

1. **Cookiy 凭据（生产）**：见下方 **第一步**：用 `./cookiy.sh --credentials "$HOME/.mcp/cookiy/credentials.json" login` 写入默认路径；**无需 Node、无需装 MCP。** 也可用 `COOKIY_CREDENTIALS` 指向其他文件（`login` 与后续命令用同一路径）。
2. **本仓库路径**：克隆或同步 `cookiy-skill` 后进入仓库根目录。

---

## 第一步：进入仓库并登录（在仓库根目录执行）

```bash
cd /path/to/cookiy-skill
CLI="$(pwd)/cookiy.sh"
"$CLI" --credentials "$HOME/.mcp/cookiy/credentials.json" login
```

浏览器完成登录/注册后，把地址栏里的回调 URL 粘贴回终端。然后可用 `"$CLI" doctor` 自检。

若凭据不在默认路径，可设：

```bash
# export COOKIY_CREDENTIALS="$HOME/.mcp/cookiy/credentials.json"
```

**粘贴规范：** 两条命令之间必须**换行**或写 `&&`，不要粘成 `doctor$CLI` 连在一起。

---

## 第二步：Study ID（默认已填，可直接用）

下面这个 **`STUDY_ID`** 已在团队账号下验证：**讨论指南为 ready**，适合跑 study / guide / progress / recruit / report 等命令。

```bash
export STUDY_ID='019d47d9-e4da-7407-89c3-90d943fd4adb'
```

- **项目名称（便于对照）：** Online Checkout Abandonment Study  
- **若你用的是自己的 Cookiy 账号、无权限访问该 study：** 先执行下面的「自选 study」，把 `STUDY_ID` 换成列表里你有权限的 UUID。

**自选 study（替换上面的 export）：**

```bash
$CLI doctor
$CLI study list --limit 20
export STUDY_ID='从列表里复制的 studyId / study_id（UUID）'
$CLI study get --study-id "$STUDY_ID"
$CLI study guide status --study-id "$STUDY_ID"
```

---

## 第三步：Quant（数字 sid，与 study 无关）

先列表，再设一个 `sid`（纯数字）：

```bash
$CLI quant list
export SURVEY_ID='487898'
```

若 `487898` 在你环境下不存在，从 `quant list` 输出里任选一个 `sid` 替换即可。

---

## 健康检查

```bash
$CLI --version
$CLI doctor
$CLI help overview
$CLI help quantitative
```

---

## Study

```bash
$CLI study list --limit 10
$CLI study get --study-id "$STUDY_ID"
$CLI study progress --study-id "$STUDY_ID"
$CLI study activity --study-id "$STUDY_ID"
$CLI study show --study-id "$STUDY_ID" --part record
$CLI study show --study-id "$STUDY_ID" --part progress
$CLI study show --study-id "$STUDY_ID" --part both
$CLI study guide status --study-id "$STUDY_ID"
$CLI study guide get --study-id "$STUDY_ID"
```

可选（会新建 study、可能计费，一般联调可跳过）：

```bash
# $CLI study create --query 'Smoke: one-line goal' --language en --wait
```

---

## Interview

```bash
$CLI interview list --study-id "$STUDY_ID"
$CLI interview list --study-id "$STUDY_ID" --include-simulation true
```

回放（需列表里先有 `interview_id`）：

```bash
# export INTERVIEW_ID='从 interview list 复制'
# $CLI interview playback --study-id "$STUDY_ID" --interview-id "$INTERVIEW_ID"
```

模拟访谈与任务状态：

```bash
$CLI interview simulate start --study-id "$STUDY_ID"
$CLI interview simulate start --study-id "$STUDY_ID" --json '{"persona_count":1}'
$CLI interview simulate start --study-id "$STUDY_ID" --wait
# export JOB_ID='从 simulate start 的 JSON 里复制 job_id'
$CLI interview simulate status --study-id "$STUDY_ID" --job-id "$JOB_ID"
```

---

## Recruit

```bash
$CLI recruit status --study-id "$STUDY_ID"
$CLI recruit start --study-id "$STUDY_ID"
```

若返回里有 **`confirmation_token`**，确认上线（**整段 token 原样粘贴**，不要用 `<TOKEN>` 占位）：

```bash
# export CONFIRMATION_TOKEN='mcp_rcf_……'
# $CLI recruit start --study-id "$STUDY_ID" --confirmation-token "$CONFIRMATION_TOKEN"
```

---

## Report

```bash
$CLI report status --study-id "$STUDY_ID"
$CLI report share-link --study-id "$STUDY_ID"
```

---

## Quant

```bash
$CLI quant list
$CLI quant create --query '5 分钟 Pulse：示例需求（可改）'
$CLI quant detail --survey-id "$SURVEY_ID"
$CLI quant report --survey-id "$SURVEY_ID"
$CLI quant results --survey-id "$SURVEY_ID"
$CLI quant stats --survey-id "$SURVEY_ID"
```

```bash
# $CLI quant patch --survey-id "$SURVEY_ID" --json '{ ... }'
```

---

## Billing

```bash
$CLI billing balance
$CLI billing checkout --amount-usd-cents 1000
```

---

## 逃生与调试

```bash
$CLI tool call cookiy_study_get --json "{\"study_id\":\"$STUDY_ID\"}"
```

环境与远端不一致时（仅排查用）：

```bash
$CLI --mcp-url 'https://dev3-api.cookiy.ai/mcp' doctor
$CLI --credentials "$HOME/.mcp/cookiy/credentials.json" doctor
```

---

## 常见问题

| 现象 | 处理 |
|------|------|
| 缺凭据文件 | 按 [`commands.md`](commands.md) 准备 `credentials.json` |
| `study get` 403 / 无该 study | 换你自己的 `STUDY_ID`（`study list`） |
| `interview playback` 报参数错 | 先 `interview list`，填有效 `INTERVIEW_ID` |
| `quant detail` 报参数错 | 确认 `SURVEY_ID` 为 **数字 sid**，且已 `export` |
| `recruit` token 无效 | 必须用**当前**预览返回的 `confirmation_token`，勿手写占位符 |

---

## 更多说明

- 全量子命令与 flag：[`commands.md`](commands.md)  
- 响应字段与约定：`../references/tool-contract.md`
