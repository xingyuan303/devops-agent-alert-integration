# DevOps Agent 告警 → 自动调查 → 飞书通知 集成方案

一键部署 AWS DevOps Agent 与飞书的集成，实现：告警自动触发调查、调查结果自动推送飞书群。

## 架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  告警源 (Grafana Alerting / Prometheus Alertmanager / CloudWatch Alarm)       │
│       ↓                                                                     │
│  SNS Topic                                                                  │
│       ↓                                                                     │
│  Lambda: feishu-notifier                                                    │
│       ├→ 飞书群：告警卡片（含"查看监控"+"查看工单"按钮）                         │
│       └→ GitHub Issue（severity=critical/high 时自动创建）                    │
│              ↓                                                              │
│  GitHub Actions → Webhook → DevOps Agent 自动调查                            │
│              ↓                                                              │
│  EventBridge (source: aws.aidevops)                                         │
│       ↓                                                                     │
│  Lambda: investigation-notifier                                             │
│       ├→ 飞书群：调查结果卡片（Action + Reasoning + Next Step）               │
│       └→ GitHub Issue 评论（完整根因摘要）                                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 前置条件

- [x] AWS DevOps Agent Space 已创建并配置数据源（CloudWatch/Grafana/GitHub）
- [x] 飞书自建应用（需 `im:message:send_as_bot` 权限，已加入目标群）
- [x] GitHub 仓库（用于工单管理 + Actions 触发调查）
- [x] Terraform >= 1.5.0

## 快速部署

### Step 1: 填写配置

复制 `terraform/terraform.tfvars.example` 为 `terraform/terraform.tfvars`，填入你的值：

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# 编辑 terraform.tfvars 填入你的配置
```

### Step 2: 部署基础设施

```bash
cd terraform
terraform init
terraform apply
```

这会创建：
- SNS Topic
- 2 个 Lambda（feishu-notifier + investigation-notifier）
- EventBridge Rule（监听 DevOps Agent 调查事件）
- IAM Roles
- Secrets Manager secrets

### Step 3: 配置 GitHub 仓库

#### 3a. 创建工单仓库

创建一个 GitHub 仓库用于存放告警工单（如 `your-org/devops-agent-tickets`）：
- 可以是空仓库
- 建议设为 Private（工单可能包含基础设施信息）
- 仓库名填入 `terraform.tfvars` 的 `github_tickets_repo`（格式：`org/repo-name`）

#### 3b. 创建 GitHub Personal Access Token (PAT)

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. 勾选权限：`repo`（Full control of private repositories）
4. 生成后复制 token，填入 `terraform.tfvars` 的 `github_token`

> ⚠️ Token 会存入 AWS Secrets Manager，Lambda 通过 Secrets Manager 读取，不会明文暴露。

#### 3c. 添加 Workflow 文件

将本项目 `github-workflow/trigger-investigation.yml` 复制到工单仓库：

```
your-org/devops-agent-tickets/
└── .github/
    └── workflows/
        └── trigger-investigation.yml
```

#### 3d. 配置 Repository Secrets

进入工单仓库 → Settings → Secrets and variables → Actions → New repository secret：

| Secret Name | 值 | 获取方式 |
|-------------|---|---------|
| `DEVOPS_AGENT_WEBHOOK_URL` | Agent Space Webhook URL | AWS Console → DevOps Agent → Agent Space → Webhook |
| `DEVOPS_AGENT_WEBHOOK_SECRET` | Webhook HMAC 签名密钥 | 创建 Webhook 时设置的 secret |

#### 3e. 启用 Workflow 权限

进入工单仓库 → Settings → Actions → General → Workflow permissions：
- 选择 "Read and write permissions"

### Step 4: 接入告警源

#### Prometheus Alertmanager → SNS

在 Alertmanager 配置中添加 SNS receiver：

```yaml
receivers:
  - name: devops-agent-sns
    sns_configs:
      - topic_arn: <terraform output: sns_topic_arn>
        sigv4:
          region: <your-region>
        subject: "Alert"
```

#### CloudWatch Alarm → SNS

给需要触发调查的 Alarm 添加 action：

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "your-alarm" \
  --alarm-actions "<terraform output: sns_topic_arn>" \
  ...
```

### Step 5: 验证

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "your-alarm" \
  --state-value ALARM \
  --state-reason "Integration test" \
  --region <your-region>
```

检查：
1. ✅ 飞书群收到告警卡片
2. ✅ GitHub 仓库创建了 Issue
3. ✅ DevOps Agent 开始调查（1-2 分钟）
4. ✅ 飞书群收到调查结果卡片

## 支持的告警源

| 告警源 | 接入方式 | 自动触发调查 |
|--------|---------|-------------|
| Grafana Alerting | Contact Point → SNS | ✅ severity=critical/high |
| Prometheus Alertmanager | SNS receiver | ✅ severity=critical/high |
| CloudWatch Alarm | Alarm Action → SNS | ✅ state=ALARM |
| 任何系统 | 发送 JSON 到 SNS | ✅ 需包含 AlarmName 或 alerts 字段 |

## 飞书卡片效果

### 告警通知
- 颜色按 severity 区分（红/橙/黄/蓝）
- 按钮：查看监控（跳转 CloudWatch/Grafana）、查看工单（GitHub Issue）

### 调查结果
- 根本原因摘要（Agent 报告最终结论）
- 如需修复建议，提供一键复制的 @Bot 消息
- 按钮：查看调查详情（Agent Space）、查看工单

## 文件结构

```
├── README.md                    本文件
├── lambda/
│   ├── feishu_notifier.py       告警通知 Lambda
│   └── investigation_notifier.py 调查结果通知 Lambda
├── github-workflow/
│   └── trigger-investigation.yml GitHub Actions → DevOps Agent Webhook
├── terraform/
│   ├── main.tf                  基础设施定义
│   ├── variables.tf             变量定义
│   ├── outputs.tf               输出值
│   └── terraform.tfvars.example 配置模板
└── docs/
    └── troubleshooting.md       常见问题排查
```

## 注意事项

- Lambda 打包包含自定义 boto3（含 DevOps Agent service model），因为该服务 SDK 尚未合并到 Lambda runtime 自带版本
- `investigation-notifier` 的 zip 约 16MB，部署时通过 S3 中转
- 飞书 Bot 必须已加入目标群，否则发送会报 `230002` 错误
- GitHub Actions workflow 使用 HMAC-SHA256 签名，确保 webhook secret 一致
