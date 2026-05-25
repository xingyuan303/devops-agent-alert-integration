# GitHub 工单仓库配置指南

## Step 1: 创建工单仓库

在 GitHub 创建一个新仓库（如 `your-org/devops-agent-tickets`），用于存放告警工单。

- 可以是空仓库，不需要任何代码
- 建议设为 Private（工单可能包含基础设施信息）

## Step 2: 添加 Workflow 文件

将本项目 `github-workflow/trigger-investigation.yml` 复制到工单仓库：

```
your-org/devops-agent-tickets/
└── .github/
    └── workflows/
        └── trigger-investigation.yml
```

可以直接在 GitHub 网页上操作：
1. 进入仓库 → Add file → Create new file
2. 文件名输入：`.github/workflows/trigger-investigation.yml`
3. 粘贴 `trigger-investigation.yml` 的内容
4. Commit

## Step 3: 配置 Repository Secrets

进入仓库 → Settings → Secrets and variables → Actions → New repository secret

添加以下 2 个 secret：

| Secret Name | 值 | 获取方式 |
|-------------|---|---------|
| `DEVOPS_AGENT_WEBHOOK_URL` | Agent Space Webhook URL | AWS Console → DevOps Agent → Agent Space → Webhook 配置 |
| `DEVOPS_AGENT_WEBHOOK_SECRET` | Webhook HMAC 签名密钥 | 创建 Webhook 时设置的 secret |

## Step 4: 启用 Actions

1. 进入仓库 → Actions 页面
2. 如果看到 "Workflows aren't being run on this repository"，点击 "I understand my workflows, go ahead and enable them"

## Step 5: 配置 Workflow 权限

进入仓库 → Settings → Actions → General → Workflow permissions：
- 选择 "Read and write permissions"（workflow 需要写 Issue 评论）

## 验证

手动创建一个 Issue 测试：
1. 进入仓库 → Issues → New Issue
2. Title: `[CRITICAL] Test alert`
3. Body: `Testing DevOps Agent integration`
4. 创建后检查 Actions 页面是否触发了 workflow

如果 workflow 成功执行（绿色 ✓），说明配置正确。

## Webhook URL 和 Secret 获取方式

1. 打开 AWS Console → DevOps Agent
2. 选择你的 Agent Space
3. 进入 Capabilities → Webhook
4. 如果还没创建 Webhook：
   - 点击 "Create webhook"
   - 设置一个 secret（记下来，填到 GitHub Secret）
   - 保存后复制 Webhook URL
5. 如果已有 Webhook：
   - 复制 Webhook URL
   - Secret 是创建时设置的（如果忘了需要重新创建）

## 工作原理

```
Issue 创建 (issues.opened)
    ↓
GitHub Actions workflow 触发
    ↓
构建 incident payload:
  - incidentId: "org/repo#issue_number"
  - priority: 从 Issue label 映射 (critical → CRITICAL)
  - title: Issue 标题
  - description: Issue 正文
    ↓
HMAC-SHA256 签名
    ↓
POST → DevOps Agent Webhook URL
    ↓
DevOps Agent 创建调查
```
