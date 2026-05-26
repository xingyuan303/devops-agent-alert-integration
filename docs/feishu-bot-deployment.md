# 飞书 Bot — SRE 对话部署指南（双向通信）

飞书 Bot 以长连接 WebSocket Pod 形式运行在 EKS 中，通过 IRSA 将消息转发到 DevOps Agent Chat API。无需 API Gateway 或公网回调 URL。

> 此组件为**可选**。如果只需要告警通知（单向），不需要部署此 Bot。Lambda 已能完成告警→飞书→调查→结果推送的完整链路。此 Bot 提供的是在飞书群里 @Bot 直接与 DevOps Agent 对话的能力。

## 前置条件

- EKS 集群已部署
- External Secrets Operator 已安装（用于同步 Secrets Manager → K8s Secret）
- IRSA 已配置（Bot Pod 需要 `aidevops:*` 权限）

## Step 1: 创建飞书应用

1. 前往 [飞书开放平台](https://open.feishu.cn/app) → 创建企业自建应用
2. 添加能力：应用能力 → 机器人
3. 启用 WebSocket 模式：事件与回调 → 选择"使用长连接接收事件"
4. 订阅事件：事件与回调 → 添加事件 → `im.message.receive_v1`（接收消息）

### 开通权限

进入权限管理 → 开通以下权限：

| 权限 | Scope | 用途 |
|------|-------|------|
| 获取群组中其他机器人和用户@当前机器人的消息 | — | 事件投递必需 |
| 读取聊天中的消息 | `im:message` | 读取消息内容 |
| 以机器人身份发送消息 | `im:message:send_as_bot` | 发送回复 |
| 获取群组信息 | `im:chat:readonly` | 读取群聊元数据 |

> ⚠️ **关键提示**：「获取群组中其他机器人和用户@当前机器人的消息」与 `im:message` 是**独立的两个权限**。即使已开通 `im:message`，如果未授予此事件级权限，Bot 将通过 WebSocket 连接成功但**静默地收不到任何消息事件**。请在事件页面检查"所需权限"列——必须显示"已开通"。

### 发布应用

1. 版本管理 → 创建版本 → 提交审核
2. 对于测试租户（"测试应用"），更改会立即生效，无需审核

### 将机器人添加到群组

打开目标飞书群 → 设置 → 机器人 → 添加该机器人

### 记录凭证

在凭证与基本信息页面记录 **App ID** 和 **App Secret**。

## Step 2: 创建 Secrets Manager 密钥

```bash
aws secretsmanager create-secret \
  --name outline/feishu-bot \
  --region us-east-1 \
  --secret-string '{
    "FEISHU_APP_ID": "<your-app-id>",
    "FEISHU_APP_SECRET": "<your-app-secret>",
    "DEVOPS_AGENT_SPACE_ID": "<your-agent-space-id>"
  }'
```

`k8s/feishu-bot-deployment.yaml` 中的 ExternalSecret 会自动将其同步为 K8s Secret。

## Step 3: 构建并推送 Bot 镜像

```bash
cd k8s/feishu-bot

# Create ECR repo (first time only)
aws ecr create-repository --repository-name feishu-bot --region us-east-1

# Build and push (must be linux/amd64 for EKS)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

docker build --platform linux/amd64 \
  -t <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/feishu-bot:latest .
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/feishu-bot:latest
```

## Step 4: 部署

```bash
kubectl apply -f k8s/feishu-bot-deployment.yaml
```

验证：

```bash
# Pod should be Running
kubectl get pods -n outline -l app=feishu-bot

# Logs should show WebSocket connected
kubectl logs -n outline -l app=feishu-bot
# Expected: "connected to wss://msg-frontier.feishu.cn/ws/v2?..."
```

## 故障排查

| 症状 | 原因 | 修复方法 |
|------|------|---------|
| `CreateContainerConfigError` | Dockerfile 使用了非数字 USER 但配置了 `runAsNonRoot` | 在 Dockerfile 中使用 `USER 1000`（数字 UID） |
| WebSocket 已连接但收不到消息 | 事件权限未授予 | 在权限管理中开通"获取群组中其他机器人和用户@当前机器人的消息"，然后重启 Pod |
| `AttributeError: 'EventDispatcherHandlerBuilder' object has no attribute 'register'` | lark-oapi >= 1.4 更改了 API | 使用 `register_p2_im_message_receive_v1()` 替代 `.register()` |
| `Could not connect to endpoint aidevops.us-east-1.amazonaws.com` | DevOps Agent API 仅在 VPC 内可解析 | Bot 必须在 EKS 内运行（不能在本地）；确保 Agent Space 已创建 |
