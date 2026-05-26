# 告警源接入指南

本项目支持多种告警源。只要告警能发到 SNS Topic，就能触发完整链路。

## 方式一：Grafana 内置 Alerting（推荐）

适用于 Grafana 8+ 的统一告警系统，通过 UI 配置，无需改文件。

### 配置步骤

1. 打开 Grafana → Alerting → Contact Points
2. 点击 "New contact point"
3. 配置：
   - **Name**: `DevOps Agent SNS`
   - **Integration**: Amazon SNS
   - **SNS Topic ARN**: `<terraform output: sns_topic_arn>`
   - **AWS Region**: 你的 region
   - **Authentication**: 选择 AWS SDK Default（使用 Grafana 所在环境的 IAM 角色）
4. 保存

### 配置 Notification Policy

1. Alerting → Notification policies
2. 编辑默认策略或创建新策略
3. 将 Contact Point 设为 `DevOps Agent SNS`
4. 可按 severity label 路由：只把 `severity=critical` 的告警发到 SNS

### IAM 权限

Grafana 运行环境（EC2/EKS/ECS）的 IAM Role 需要：

```json
{
  "Effect": "Allow",
  "Action": "sns:Publish",
  "Resource": "<sns_topic_arn>"
}
```

---

## 方式二：Prometheus Alertmanager

适用于独立部署的 Prometheus Alertmanager（如 kube-prometheus-stack）。

### 配置步骤

在 `alertmanager.yml`（或 Helm values）中添加 SNS receiver：

```yaml
receivers:
  - name: devops-agent-sns
    sns_configs:
      - topic_arn: "<terraform output: sns_topic_arn>"
        sigv4:
          region: "<your-region>"
        subject: "Alert"
        # 可选：只发 firing 状态
        send_resolved: false

route:
  receiver: default
  routes:
    # severity=critical 的告警发到 SNS 触发调查
    - match:
        severity: critical
      receiver: devops-agent-sns
      repeat_interval: 4h
```

### IAM 权限（EKS 环境）

Alertmanager Pod 需要通过 IRSA 获得 SNS Publish 权限：

```yaml
# ServiceAccount annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: alertmanager
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account>:role/<alertmanager-role>
```

IAM Policy：
```json
{
  "Effect": "Allow",
  "Action": "sns:Publish",
  "Resource": "<sns_topic_arn>"
}
```

---

## 方式三：CloudWatch Alarm

适用于 AWS 原生监控，无需 Grafana。

### 配置步骤

给 Alarm 添加 SNS Action：

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "your-alarm-name" \
  --alarm-actions "<terraform output: sns_topic_arn>" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold
```

或者在 AWS Console：
1. CloudWatch → Alarms → 选择 Alarm → Edit
2. Notification → In alarm → 选择 SNS Topic

### 批量添加（已有 Alarm）

```bash
# 列出所有没有 action 的 alarm
aws cloudwatch describe-alarms \
  --query "MetricAlarms[?AlarmActions==\`[]\`].AlarmName" \
  --output text

# 给指定 alarm 添加 action（不影响已有 action）
aws cloudwatch put-metric-alarm \
  --alarm-name "existing-alarm" \
  --alarm-actions "<sns_topic_arn>" "<existing_action_arn>"
```

---

## 方式四：任何系统（通用 SNS 发布）

任何能发 HTTP 请求的系统都可以直接 Publish 到 SNS：

```bash
aws sns publish \
  --topic-arn "<sns_topic_arn>" \
  --subject "ALARM: Your Alert Title" \
  --message '{
    "AlarmName": "custom-alert",
    "NewStateValue": "ALARM",
    "NewStateReason": "Describe what happened",
    "StateChangeTime": "2026-01-01T00:00:00.000Z",
    "Region": "us-east-1",
    "AlarmArn": "arn:aws:cloudwatch:us-east-1:123456789012:alarm:custom-alert",
    "Trigger": {
      "MetricName": "CustomMetric",
      "Namespace": "Custom/App"
    }
  }'
```

Lambda 会识别 `AlarmName` 字段并按 CloudWatch Alarm 格式处理。

---

## 触发调查的条件

不是所有告警都会触发 DevOps Agent 调查。只有满足以下条件的告警才会创建 GitHub Issue → 触发调查：

| 告警源 | 触发条件 |
|--------|---------|
| Grafana / Alertmanager | `severity` = critical, high, 或 error，且 `status` = firing |
| CloudWatch Alarm | `NewStateValue` = ALARM |

其他告警（warning、resolved）只会发飞书通知，不触发调查。
